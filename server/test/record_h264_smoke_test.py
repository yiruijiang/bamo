import socket
import time
from picamera2 import Picamera2
from picamera2.encoders import H264Encoder
from picamera2.outputs import FileOutput

# 1. Initialize the camera
picam2 = Picamera2()
# Using 720p for a good balance of quality and performance
config = picam2.create_video_configuration(main={"size": (640, 360)})
picam2.configure(config)
picam2.start()

# 2. Set up a TCP server socket to listen for ffplay
server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server_socket.bind(('0.0.0.0', 5001))
server_socket.listen(1)

print("---------------------------------------------------------")
print("H.264 TCP Stream Server Active")
print("Listening on port 5001...")
print("")
print("Run this command on your computer to view the stream:")
print("ffplay -f h264 -fflags nobuffer -flags low_delay tcp://localhost:5001")
print("---------------------------------------------------------")

try:
    while True:
        # Wait for a connection from ffplay
        connection, address = server_socket.accept()
        print(f"Connection received from {address}")
        
        # Create a file-like object from the socket for the encoder to write to
        stream = connection.makefile('wb')
        
        try:
            # 3. Start recording H.264 directly to the network stream
            # Using a 5Mbps bitrate for high quality
            print("Starting H.264 stream...")
            picam2.start_recording(H264Encoder(bitrate=5000000), FileOutput(stream))
            
            # Keep streaming until the client disconnects or user interrupts
            while True:
                time.sleep(1)
                
        except (ConnectionResetError, BrokenPipeError):
            print("Client disconnected.")
        finally:
            print("Stopping recording...")
            picam2.stop_recording()
            connection.close()
            print("Waiting for new connection...")

except KeyboardInterrupt:
    print("User interrupted. Shutting down...")

finally:
    # 4. Clean up
    picam2.stop()
    server_socket.close()
    print("Camera and socket closed. Done.")
