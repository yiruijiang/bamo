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
    mkdir -p "$REC_PATH"
    
    while true; do
        if [ "$REC_TOGGLE" = "true" ]; then
            # 1. CLEANUP: Delete older files
            find "$REC_PATH" -name "*.mp4" -type f -mtime +"$REC_DAYS" -exec rm {} \; 2>/dev/null
            
            # 2. RECORD: Grab RTSP stream (Direct copy, low CPU)
            FILE_NAME="${REC_PATH}/rec_$(date +'%Y-%m-%d_%H-%M-%S').mp4"
            ffmpeg -hide_banner -loglevel error -y -rtsp_transport tcp -i "rtsp://localhost:8554/stream" -t "$REC_DURATION" -c copy "$FILE_NAME" 2>/dev/null
            
            # 3. SLEEP: Calculate remaining time in the frequency cycle
            SLEEP_TIME=$((REC_FREQ - REC_DURATION))
            if [ "$SLEEP_TIME" -gt 0 ]; then
                sleep "$SLEEP_TIME"
            fi
        else
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
    echo "Starting highly-optimized hardware camera:"
    echo "Resolution: ${WIDTH}x${HEIGHT} @ ${FRAMERATE}fps"
    echo "Recording:  Toggle=$REC_TOGGLE | ${REC_DURATION}s every ${REC_FREQ}s"
    echo "========================================="
    
    # START RECORDING DAEMON
    record_daemon &
    REC_PID=$!
    
    # START THE CAMERA (Native ISP & Hardware Encoding)
    rpicam-vid -t 0 --camera 0 \
    --width "$WIDTH" --height "$HEIGHT" --framerate "$FRAMERATE" \
    --ev "$EV" --saturation "$SATURATION" --gain "$GAIN" \
    --contrast "$CONTRAST" --brightness "$BRIGHTNESS" \
    --info-text "%Y-%m-%d %H:%M:%S" \
    --codec libav --libav-audio --audio-codec aac --audio-bitrate 128000 \
    --libav-format rtsp \
    -o "rtsp://localhost:8554/stream" > /dev/null 2>&1 &

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