#!/bin/bash

CONFIG_FILE="camera.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: $CONFIG_FILE not found! Please create it first."
    exit 1
fi

# ==========================================
# BACKGROUND RECORDING DAEMON
# ==========================================
record_daemon() {
    # Ensure the recording directory exists
    mkdir -p "$REC_PATH"
    
    while true; do
        if [ "$REC_TOGGLE" = "true" ]; then
            # 1. CLEANUP: Find and delete mp4 files older than REC_DAYS
            find "$REC_PATH" -name "*.mp4" -type f -mtime +"$REC_DAYS" -exec rm {} \; 2>/dev/null
            
            # 2. RECORD: Generate filename and grab UDP stream
            FILE_NAME="${REC_PATH}/rec_$(date +'%Y-%m-%d_%H-%M-%S').mp4"
            
            # Grabs the UDP stream, copies it without CPU overhead, for REC_DURATION seconds
            ffmpeg -hide_banner -loglevel error -y -i "udp://239.0.0.1:5000" -t "$REC_DURATION" -c copy "$FILE_NAME" 2>/dev/null
            
            # 3. SLEEP: Wait for the next cycle
            # (e.g., if frequency is 30s and duration is 5s, sleep for 25s)
            SLEEP_TIME=$((REC_FREQ - REC_DURATION))
            if [ "$SLEEP_TIME" -gt 0 ]; then
                sleep "$SLEEP_TIME"
            fi
        else
            # If toggled off, sleep for 5 seconds before checking the config again
            sleep 5
        fi
    done
}

# ==========================================
# MAIN CAMERA LOOP
# ==========================================
while true; do
    source "$CONFIG_FILE"

    echo "========================================="
    echo "Starting camera with current config:"
    echo "Resolution: ${WIDTH}x${HEIGHT} @ ${FRAMERATE}fps"
    echo "Recording:  Toggle=$REC_TOGGLE | ${REC_DURATION}s every ${REC_FREQ}s"
    echo "========================================="
    
    # START RECORDING DAEMON IN BACKGROUND
    record_daemon &
    REC_PID=$!
    
    # START THE CAMERA (Changed to UDP Multicast)
    rpicam-vid -t 0 --camera 0 --width "$WIDTH" --height "$HEIGHT" --framerate "$FRAMERATE" \
    --ev "$EV" --saturation "$SATURATION" --gain "$GAIN" \
    --codec yuv420 -o - 2> >(grep --line-buffered -v "^#" >&2) | \
    ffmpeg -hide_banner -loglevel error -y \
    -f rawvideo -framerate "$FRAMERATE" -video_size "${WIDTH}x${HEIGHT}" -pixel_format yuv420p -i - \
    -f alsa -ac 1 -i "plughw:2,0" \
    -vf "eq=contrast=${CONTRAST}:brightness=${BRIGHTNESS},drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='%{localtime}':fontcolor=white:fontsize=36:box=1:boxcolor=black@0.5:x=10:y=10" \
    -c:v libx264 -preset ultrafast -tune zerolatency -profile:v baseline -g 15 -c:a aac -b:a 128k \
    -flush_packets 1 \
    -f mpegts "udp://239.0.0.1:5000?pkt_size=1316" > /dev/null 2>&1 &

    CAM_PID=$! 
    
    echo "Camera LIVE (PID: $CAM_PID) | Recorder LIVE (PID: $REC_PID)"
    echo "[q] = Quit completely | [r] = Reload config"

    # INNER LOOP: Monitor inputs
    while true; do
        read -t 0.5 -n 1 USER_INPUT
        
        if [[ "$USER_INPUT" == "q" ]]; then
            echo -e "\nShutting down..."
            kill -9 $REC_PID 2>/dev/null
            kill -SIGINT $CAM_PID 2>/dev/null
            killall rpicam-vid ffmpeg 2>/dev/null 
            exit 0
        fi

        if [[ "$USER_INPUT" == "r" ]]; then
            echo -e "\nReloading config..."
            kill -9 $REC_PID 2>/dev/null
            kill -SIGINT $CAM_PID 2>/dev/null
            killall rpicam-vid ffmpeg 2>/dev/null 
            break 
        fi

        if ! kill -0 $CAM_PID 2>/dev/null; then
            echo -e "\nCamera crashed. Restarting..."
            kill -9 $REC_PID 2>/dev/null
            killall rpicam-vid ffmpeg 2>/dev/null 
            break 
        fi
    done
    
    sleep 1 
done