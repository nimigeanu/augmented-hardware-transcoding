const express = require('express');
const bodyParser = require('body-parser');
const { spawn } = require('child_process');

const app = express();
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

const processesByStream = {};

app.post('/publish', async (req, res) => {
  console.log('Stream started:', req.body);
  const streamKey = req.body.name;
  const input = `rtmp://localhost:1935/live/${streamKey}`;
  const outputPath = `rtmp://localhost:1935/hls/${streamKey}`;

  const hardwareDevice = await getAvailableDevice();
  console.log("hardwareDevice: ", hardwareDevice);
  if (hardwareDevice !== null){
    const ffmpegCommand = `
      -re -c:v mpsoc_vcu_h264
      -xlnx_hwdev ${hardwareDevice}
      -i ${input}
      -filter_complex "
        multiscale_xma=outputs=5:
        out_1_width=1920: out_1_height=1080:
        out_2_width=1280: out_2_height=720:
        out_3_width=848:  out_3_height=480:
        out_4_width=424:  out_4_height=240:
        out_5_width=288:  out_5_height=160
        [a][b][c][d][e]; 
        [c]xvbm_convert[cc]; [d]xvbm_convert[dd]; [e]xvbm_convert[ee]
      "
      -map "[a]"  -b:v 8M    -c:v mpsoc_vcu_h264 -f flv -y ${outputPath}_1080p
      -map "[b]"  -b:v 5M    -c:v mpsoc_vcu_h264 -f flv -y ${outputPath}_720p
      -map "[cc]"  -b:v 2500K -c:v libx264        -f flv -y ${outputPath}_480p
      -map "[dd]" -b:v 1000K -c:v libx264        -f flv -y ${outputPath}_240p
      -map "[ee]" -b:v 500K  -c:v libx264        -f flv -y ${outputPath}_160p
    `;

    const splitArgs = (cmd) => {
      const regex = /(?:[^\s"]+|"[^"]*")+/g;
      return cmd.match(regex).map(arg => arg.replace(/(^"|"$)/g, ''));
    };

    const ffmpegArgs = splitArgs(ffmpegCommand);
    // console.log("ffmpeg args: ", ffmpegArgs)

    const ffmpegProcess = spawn('ffmpeg', ffmpegArgs);
    processesByStream[streamKey] = ffmpegProcess;

    ffmpegProcess.stderr.on('data', (data) => {
      const timePattern = /time=\d{2}:\d{2}:\d{2}\.\d{2}/;  // Matches any timestamp
      const zeroSecondsPattern = /time=\d{2}:\d{2}:00\.\d{2}/;  // Matches timestamp with zero seconds

      if (!timePattern.test(data)) {
          // No timestamp present
          console.error(`ffmpeg: ${data}`);
      } else if (zeroSecondsPattern.test(data)) {
          // Timestamp present with zero seconds
          console.error(`ffmpeg: ${data}`);
      }
      // console.error(`ffmpeg: ${data}`);
    });

    ffmpegProcess.on('close', (code) => {
      console.log(`FFmpeg process exited with code ${code}`);
    });

    res.sendStatus(200);
  }
  else {
    res.sendStatus(429);
  }
});

app.post('/unpublish', (req, res) => {
  console.log('Stream ended:', req.body);
  const streamKey = req.body.name;
  const process = processesByStream[streamKey];
  if (process){
    terminateProcess(process);
    delete processesByStream[streamKey];
  }
  res.sendStatus(200);
});

app.listen(8000, () => {
  console.log('Server is listening on port 8000');
});

async function getAvailableDevice() {
    const command = '/opt/xilinx/xrm/bin/xrmadm';
    const args = ['/opt/xilinx/xrm/test/list_cmd.json'];

    return new Promise((resolve, reject) => {
        const child = spawn(command, args);

        let stdout = '';
        let stderr = '';

        child.stdout.on('data', (data) => {
            stdout += data;
        });

        child.stderr.on('data', (data) => {
            stderr += data;
        });

        child.on('close', (code) => {
            if (code !== 0) {
                reject(new Error(`Command failed with exit code ${code}: ${stderr}`));
                return;
            }

            try {
                const jsonOutput = JSON.parse(stdout);
                resolve(findDeviceWithCapacity(jsonOutput));
            } catch (parseError) {
                reject(new Error(`Error parsing JSON: ${parseError.message}`));
            }
        });

        child.on('error', (error) => {
            reject(new Error(`Error executing command: ${error.message}`));
        });
    });
}

const jsonData = {
    // The provided JSON data should be assigned here
};

function findDeviceWithCapacity(data) {
    if (data.response && data.response.data) {
        const deviceCount = parseInt(data.response.data.deviceNumber, 10);
        for (let i = 0; i < deviceCount; i++) {
            console.log("   device: ", i);
            const deviceKey = `device_${i}`;
            const device = data.response.data[deviceKey];
            if (device) {
                let hasScaler = false;
                let hasEncoder = false;
                let hasDecoder = false;

                for (let j = 0; j < parseInt(device["cuNumber   "], 10); j++) {
                    const cuKey = `cu_${j}`;
                    const cu = device[cuKey];
                    if (cu) {
                        const cuType = cu["kernelName   "].trim();
                        console.log("     cuType: ", cuType);
                        const usedLoadStr = cu["usedLoad     "].trim();
                        console.log("     usedLoadStr: ", usedLoadStr);
                        const usedLoad = parseInt(usedLoadStr.split(' ')[0], 10);
                        console.log("     usedLoad: ", usedLoad);
                        const loadRatio = usedLoad / 1000000;
                        console.log("     loadRatio: ", loadRatio);

                        if (cuType === 'scaler' && loadRatio <= 0.8) {
                            hasScaler = true;
                        } else if (cuType === 'encoder' && loadRatio <= 0.8) {
                            hasEncoder = true;
                        } else if (cuType === 'decoder' && loadRatio <= 0.8) {
                            hasDecoder = true;
                        }
                    }
                }

                if (hasScaler && hasEncoder && hasDecoder) {
                    return i;
                }
            }
        }

        return null;
    } else {
        console.error('Invalid response format');
        return null;
    }
}

function terminateProcess(child) {
    console.log(`Sending SIGTERM to process with PID ${child.pid}...`);
    child.kill('SIGTERM');

    // Set a timeout to forcefully kill the process if it doesn't terminate
    setTimeout(() => {
        if (child.exitCode === null) { // process is still running
            console.log(`Sending SIGKILL to process with PID ${child.pid}...`);
            child.kill('SIGKILL');
        }
    }, 10000); // 10 seconds timeout
}