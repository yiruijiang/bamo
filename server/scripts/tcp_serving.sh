#!/bin/bash

while true; do
    echo "Starting camera..."
    
    # Start camera in the background and hide its messy output
    rpicam-vid -t 0 --codec libav --libav-format mpegts -o "tcp://0.0.0.0:5000?listen=1" > /dev/null 2>&1 &
    CAM_PID=$!
    
    echo "Camera is LIVE (PID: $CAM_PID)."
    echo "Press 'q' at any time to quit completely."

    # Inner loop: actively monitor both the user and the process
    while true; do
        # 1. Check for keyboard input. 
        # -t 0.5 waits only half a second. -n 1 reads exactly one character.
        read -t 0.5 -n 1 USER_INPUT
        if [[ "$USER_INPUT" == "q" ]]; then
            echo -e "\nQuit command received. Shutting down..."
            kill $CAM_PID 2>/dev/null
            exit 0
        fi

        # 2. Check the "pulse" of the camera process
        # kill -0 doesn't actually kill it; it just checks if the process still exists
        if ! kill -0 $CAM_PID 2>/dev/null; then
            echo -e "\nClient disconnected (pipe broken). Restarting camera..."
            # Break this inner loop so the outer loop restarts the camera
            break 
        fi
    done
done
