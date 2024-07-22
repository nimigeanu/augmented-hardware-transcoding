#!/bin/bash

# Variables (replace these with actual values)
hardwareDevice=0
input="path/to/your/input/file"
outputPath="path/to/your/output/file"

# ffmpeg command
ffmpeg -re -c:v mpsoc_vcu_h264 \
-xlnx_hwdev $hardwareDevice \
-i $input \
-filter_complex " \
  multiscale_xma=outputs=5: \
  out_1_width=1920: out_1_height=1080: \
  out_2_width=1280: out_2_height=720: \
  out_3_width=848:  out_3_height=480: \
  out_4_width=424:  out_4_height=240: \
  out_5_width=288:  out_5_height=160 \
  [a][b][c][d][e]; \
  [c]xvbm_convert[cc]; [d]xvbm_convert[dd]; [e]xvbm_convert[ee] \
" \
-map "[a]"  -b:v 8M    -c:v mpsoc_vcu_h264 -f flv -y ${outputPath}_1080p.flv \
-map "[b]"  -b:v 5M    -c:v mpsoc_vcu_h264 -f flv -y ${outputPath}_720p.flv \
-map "[cc]" -b:v 2500K -c:v libx264        -f flv -y ${outputPath}_480p.flv \
-map "[dd]" -b:v 1000K -c:v libx264        -f flv -y ${outputPath}_240p.flv \
-map "[ee]" -b:v 500K  -c:v libx264        -f flv -y ${outputPath}_160p.flv
