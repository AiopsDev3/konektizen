import socketio
import time

# Create a Socket.IO client
sio = socketio.Client()

@sio.event
def connect():
    print('[TEST] Connected to server')
    sio.emit('join-c3', {}) 

@sio.event
def disconnect():
    print('[TEST] Disconnected from server')

@sio.on('konektizen_sos')
def on_sos(data):
    print('\n[TEST] 🚨 RECEIVED SOS ALERT 🚨')
    print(data)
    print('[TEST] Test Successful!\n')

if __name__ == '__main__':
    try:
        # Connect to local python server
        sio.connect('http://localhost:5000')
        print('[TEST] Listening for SOS events (Press CTRL+C to stop)...')
        sio.wait()
    except Exception as e:
        print(f"[TEST] Connection failed: {e}")
