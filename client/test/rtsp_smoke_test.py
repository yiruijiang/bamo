import cv2

# Replace with your Raspberry Pi's actual IP address
RTSP_URL = "rtsp://192.168.178.35:8554/stream"

def main():
    print(f"Connecting to {RTSP_URL}...")
    
    # Open the RTSP stream
    cap = cv2.VideoCapture(RTSP_URL)

    # Lower the buffer size to reduce latency for real-time ML processing
    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

    if not cap.isOpened():
        print("Error: Could not open the RTSP stream. Is MediaMTX running on the Pi?")
        return

    print("Stream connected! Press 'q' to quit.")

    while True:
        # Read the latest frame
        ret, frame = cap.read()

        if not ret:
            print("Warning: Dropped frame or stream disconnected.")
            break

        # =======================================================
        # 🧠 INSERT YOUR HEAVY ML MODELS (LIKE SAM) HERE!
        #
        # IMPORTANT: OpenCV loads images in BGR color format.
        # Most ML models (like SAM) expect RGB format. 
        # Convert it like this before passing it to your model:
        # 
        # rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        # results = sam_model.predict(rgb_frame)
        # =======================================================

        # For now, just display the raw video feed in a window
        cv2.imshow("MacBook CV Inference Stream", frame)

        # Press 'q' to close the window and exit
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    # Clean up
    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()