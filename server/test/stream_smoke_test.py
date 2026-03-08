import io
import time
from threading import Condition
# Notice we imported render_template and request
from flask import Flask, Response, render_template, request
from picamera2 import Picamera2
from picamera2.encoders import JpegEncoder
from picamera2.outputs import FileOutput

app = Flask(__name__)

class StreamingOutput(io.BufferedIOBase):
    def __init__(self):
        self.frame = None
        self.condition = Condition()

    def write(self, buf):
        with self.condition:
            self.frame = buf
            self.condition.notify_all()

output = StreamingOutput()
picam2 = Picamera2()
config = picam2.create_video_configuration(main={"size": (640, 480)})
picam2.configure(config)

picam2.start()
picam2.start_recording(JpegEncoder(), FileOutput(output))

def generate_frames():
    while True:
        with output.condition:
            output.condition.wait()
            frame = output.frame
        
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')

# Route 1: Load the HTML webpage
@app.route('/')
def index():
    return render_template('index.html')

# Route 2: Serve the raw video feed to the HTML page
@app.route('/video_feed')
def video_feed():
    return Response(generate_frames(), mimetype='multipart/x-mixed-replace; boundary=frame')

# Route 3: Handle the "Take Photo" button press
@app.route('/capture', methods=['POST'])
def capture():
    # Grab the absolute latest frame from the live buffer
    with output.condition:
        output.condition.wait()
        current_frame = output.frame
    
    # Generate a unique filename using the current timestamp
    filename = f"photo_{int(time.time())}.jpg"
    
    # Save the raw JPEG data to the disk
    with open(filename, 'wb') as f:
        f.write(current_frame)
        
    print(f"Saved: {filename}")
    
    # Reload the webpage and show a success message
    return render_template('index.html', message=f"Success! Saved as {filename}")

if __name__ == '__main__':
    print("Starting server. Press Ctrl+C to stop.")
    app.run(host='0.0.0.0', port=5000)
