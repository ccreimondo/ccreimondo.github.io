#!/bin/bash

# Slowdown/speedup the video/audio in your video file (.mp4) by 1/N times
ffmpeg -i $FIN -filter_complex "[0:v]setpts=$N*PTS[v];[0:a]atempo=$((1/N))[a]" -map "[v]" -map "[a]" $FOUT
