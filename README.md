# Hybrid Hardware/Software Live ABR Transcoding

## Overview

An architecture that combines hardware and software transcoding in ABR ladders to maximize cost efficiency. 
It runs on AWS' specialized [VT1 (Video Transcode) EC2 instances](https://xilinx.github.io/video-sdk/v1.5/getting_started_on_vt1.html) equipped with Alveo U30 cards and Xilinx devices.

## Transcode Capacity/Cost
1. __10__ streams `from 1080p to 1080p, 720p, 480p, 240p, 160p` for __$0.65__*/hour (vt1.3xlarge)
2. __16__ streams `from 1080p to 720p, 480p, 360p, 240p, 160p` for __$0.65__*/hour (vt1.3xlarge)
3. __20__ streams `from 7200p to 720p, 480p, 360p, 240p, 160p` for __$0.65__*/hour (vt1.3xlarge)
4. ...
5. ...
6. proportionally __twice__ the capacity of 1, 2, 3 for __twice__ the price (vt1.6xlarge)
7. ...
8. ...
9. proportionally __8 times__ the capacity of 1, 2, 3 for __8 times__ the price  (vt1.24xlarge)

For reference, following is the hardware-only capacity (as opposed to hybrid hardware/software above)
1. __8__ streams `from 1080p to 1080p, 720p, 480p, 240p` for __$0.65__*/hour (vt1.3xlarge)
2. __16__ streams `from 1080p to 720p, 480p, 360p` for __$0.65__*/hour (vt1.3xlarge)
3. __18__ streams `from 7200p to 720p, 480p, 360p` for __$0.65__*/hour (vt1.3xlarge)

\*the price is for on demand capacity, with reservations you can get some 40% off for a year and 60% off for 3 years

## Setup

### Deploying the trascoder

1. Sign in to the [AWS Management Console](https://aws.amazon.com/console), then click the button below to launch the CloudFormation template. Alternatively you can [download](template.yaml) the template and adjust it to your needs.

[![Launch Stack](https://cdn.rawgit.com/buildkite/cloudformation-launch-stack-button-svg/master/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home#/stacks/create/review?stackName=hybrid-abr-live-transcoding&templateURL=https://s3.amazonaws.com/lostshadow/augmented-hardware-transcoding/template.yaml)

2. Adjust the parameters to fit your needs. Defaults are properly suited to transcode 10 1080p streams in `us-east-1` (N.Virginia AWS region); see below for advanced usage scenarios or if you need to deploy to another region.  
3. Choose a name for your stack
4. Check the `I acknowledge that AWS CloudFormation might create IAM resources` box. This confirms you agree to have some required IAM roles and policies created by CloudFormation.
5. Hit the `Create` button. 
6. Wait for the `Status` of your CloudFormation template to become `CREATE_COMPLETE`. Note that this may take **2-3 minutes** or more.
7. Under `Outputs`, click the link under `DemoPlayerUrl`; keep waiting/refreshing until the page loads. This may take an additional **3-4 minutes** or more. It is normal at this stage for it to display a `The media could not be loaded...` error. 
8. Publish your stream to the `IngressEndpoint` RTMP address. You can use [OBS](https://obsproject.com/) or an alternative.
9. Refresh the player in step 7, it should now play the ABR stream. Give it just **one more minute** if it doesn't yet. For convenience, the player has a quality selector.
10. Publish and play more streams by replacing `stream1` with anything else on both the `IngressEndpoint` and `DemoPlayerUrl`. When capacity is reached, further RTMP broadcasts are rejected.

### Integration
While this very demo is put together to get one to quickly assess the solution and judge its cost-effectiveness, what's truly required to run it in your project is to
1. Launch an Amazon EC2 VT1 Instance; alternatively get yourself a server with an Alveo U30 accelerator installed
2. [Install](https://xilinx.github.io/video-sdk/v1.5/getting_started_on_vt1.html#id4) the Xilinx Video SDK; alternatively just start a `Xilinx Video SDK` AMI on EC2
3. Compile ffmpeg with `x264` (the binary included in the SDK only includes the `mpsoc_vcu_h264` [i.e. hardware] transcoder); a [script](util/compile_ffmpeg_ubuntu.sh) to compile it as such is included for convenience
4. run a ffmpeg command similar to [this](util/ffmpeg-samples/transcode_1080p.sh); notice that some ABR renditions are transcoded on the FPGA (encoder `mpsoc_vcu_h264`)while others on the CPU (encoder `libx264`)


### Notes:
* The solution uses VT1 instances, which are only available in specific AWS Regions and availability zones. If you need to run this in a region other than `us-east-1`, first run a search for `AMD Xilinx Video SDK` AMIs in your region, note the AMI ID, and use it as a parameter for the stack instead of the default
* Audio is not dealt with as part of this demo; feel free to transcode or pass it through as you see fit
* This demo only deals with AVC feeds; Xilinx itself also supports HEVC encoding and decoding
* All inputs and outputs in this demo are 30fps; consider half the capacity for 60 fps
* Samples in this demo deal with video up to 1080p; Xilinx itself supports up to 2160p
* This demo only deals with 8bit color depth; Xilinx encoders themselves (AVC, HEVC) support up to 10 bit 
* The recompiled ffmpeg is nonfree (i.e. the x264 encoder is [GPL](https://www.codeproject.com/Articles/25240/GNU-GPL-for-Dummies)), be sure to adhere to the licensing terms
* Comprehensive docs [here](https://xilinx.github.io/video-sdk/v1.5/index.html)
