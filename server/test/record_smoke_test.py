import time
from picamera2 import Picamera2
from picamera2.encoders import H264Encoder
from picamera2.outputs import CircularOutput

# 1. Initialize the camera and set the resolution
picam2 = Picamera2()
config = picam2.create_video_configuration(main={"size": (1280, 720)})
picam2.configure(config)

# 2. Set up the encoder and circular buffer (150 frames = 5 seconds)
encoder = H264Encoder(bitrate=2000000)
circ_output = CircularOutput(buffersize=150)

# MANUALLY link the circular buffer to the encoder
encoder.output = circ_output

# 3. Start the camera and start feeding frames into the ring buffer
picam2.start()

# ONLY start the encoder (this fills the buffer but doesn't write to a file yet)
picam2.start_encoder(encoder)

print("Camera is active. Buffering frames in memory...")
print("-> Press 'Enter' to trigger an event capture.")
print("-> Press 'Ctrl+C' to exit the program completely.")

event_counter = 1

try:
    # 4. The Infinite Loop
    while True:
        input()  # The script pauses here and waits for you to press Enter

        print(f"\n--- Event {event_counter} Triggered! ---")
        print("Flushing pre-roll to file and recording the aftermath...")

        # Assign a unique file name for each event
        filename = f"{event_counter}.h264"
        circ_output.fileoutput = filename

        # Dump history and keep recording live
        circ_output.start()

        # Record 5 seconds AFTER the event occurred
        time.sleep(5)

        # Stop saving to the file, but keep the camera buffering!
        circ_output.stop()
        print(f"Saved {filename} (Total video length: ~10 seconds)")
        print("\nResuming background buffering. Press 'Enter' to trigger again.")

        event_counter += 1

except KeyboardInterrupt:
    # 5. Catch the Ctrl+C exit command
    print("\nProgram interrupted by user. Stopping...")

finally:
    # 6. Shut down the camera safely no matter how the script exits
    print("Cleaning up camera resources...")
    # Stop the encoder instead of stop_recording
    picam2.stop_encoder()
    picam2.stop()
    print("Done!")
