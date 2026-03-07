#!/bin/bash

CONFIG_FILE="camera.conf"

# Ensure the config file exists before starting
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: $CONFIG_FILE not found! Please create it first."
    exit 1
fi

while true; do
    # 1. READ THE CONFIG FILE
    # 'source' pulls the variables from the config file into this script
    source "$CONFIG_FILE"

    echo "========================================="
    echo "Starting camera with current config:"
    echo "Resolution: ${WIDTH}x${HEIGHT} @ ${FRAMERATE}fps"
    echo "Hardware -> EV: $EV | Sat: $SATURATION | Gain: $GAIN"
    echo "Filter   -> Contrast: $CONTRAST | Brightness: $BRIGHTNESS"
    echo "========================================="
    
    # 2. START THE CAMERA WITH CONFIG VARIABLES
    rpicam-vid -t 0 --camera 0 --width "$WIDTH" --height "$HEIGHT" --framerate "$FRAMERATE" \
    --ev "$EV" --saturation "$SATURATION" --gain "$GAIN" \
    --codec yuv420 -o - 2> >(grep --line-buffered -v "^#" >&2) | \
    ffmpeg -hide_banner -loglevel error -y \
    -f rawvideo -framerate "$FRAMERATE" -video_size "${WIDTH}x${HEIGHT}" -pixel_format yuv420p -i - \
    -f alsa -ac 1 -i "plughw:2,0" \
    -vf "eq=contrast=${CONTRAST}:brightness=${BRIGHTNESS},drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='%{localtime}':fontcolor=white:fontsize=36:box=1:boxcolor=black@0.5:x=10:y=10" \
    -c:v libx264 -preset ultrafast -tune zerolatency -profile:v baseline -c:a aac -b:a 128k \
    -flush_packets 1 \
    -f mpegts "tcp://0.0.0.0:5000?listen=1" > /dev/null 2>&1 &

    CAM_PID=$! 
    
    echo "Camera is LIVE (FFmpeg PID: $CAM_PID)."
    echo "[q] = Quit completely | [r] = Reload config"

    # Inner loop: actively monitor both the user and the process
    while true; do
        read -t 0.5 -n 1 USER_INPUT
        
        # ACTION: QUIT
        if [[ "$USER_INPUT" == "q" ]]; then
            echo -e "\nQuit command received. Shutting down..."
            kill -SIGINT $CAM_PID 2>/dev/null
            killall rpicam-vid 2>/dev/null 
            wait $CAM_PID 2>/dev/null 
            exit 0
        fi

        # ACTION: RELOAD CONFIG
        if [[ "$USER_INPUT" == "r" ]]; then
            echo -e "\nReloading config..."
            kill -SIGINT $CAM_PID 2>/dev/null
            killall rpicam-vid 2>/dev/null 
            wait $CAM_PID 2>/dev/null 
            break # This breaks the inner loop, jumping back to the top to re-source the config
        fi

        # ACTION: CRASH RECOVERY
        if ! kill -0 $CAM_PID 2>/dev/null; then
            echo -e "\nClient disconnected or crashed. Restarting camera..."
            killall rpicam-vid 2>/dev/null 
            break # Break inner loop to restart
        fi
    done
    
    sleep 1 
done