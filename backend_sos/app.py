from flask import Flask, request, jsonify, send_file
from flask_socketio import SocketIO, emit, join_room, leave_room
import secrets
import time
import config

app = Flask(__name__)
app.config['SECRET_KEY'] = 'secret!'
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading', logger=True, engineio_logger=True)

# In-memory storage for calls (MVP)
# call_id -> { "citizenToken": "", "responderToken": "", "expiresAt": timestamp, "active": bool }
calls = {}

CALL_EXPIRATION_SECONDS = config.CALL_EXPIRATION_SECONDS

@app.route('/api/sos/video/start', methods=['POST'])
def start_video_call():
    call_id = secrets.token_urlsafe(8)
    citizen_token = secrets.token_urlsafe(16)
    responder_token = secrets.token_urlsafe(16)
    
    expires_at = time.time() + CALL_EXPIRATION_SECONDS
    
    calls[call_id] = {
        "citizenToken": citizen_token,
        "responderToken": responder_token,
        "expiresAt": expires_at,
        "active": True
    }
    
    print(f"[Flask] New WebRTC call created: {call_id}")
    print(f"[Flask] Broadcasting 'new-call' event to all connected clients...")
    
    response = {
        "callId": call_id,
        "citizenToken": citizen_token,
        "responderUrl": f"/responder-call?callId={call_id}&role=responder",
        "expiresAt": expires_at
    }
    
    # Broadcast to ALL connected clients (emit without 'to' or 'room' broadcasts to everyone)
    socketio.emit('new-call', {
        'callId': call_id,
        'expiresAt': expires_at
    })
    print(f"[Flask] 'new-call' event broadcasted for call {call_id}")
    
    return jsonify(response)

@app.route('/api/sos/video/end', methods=['POST'])
def end_call_http():
    data = request.json
    call_id = data.get('callId')
    
    if call_id in calls:
        calls[call_id]['active'] = False
        socketio.emit('end-call', to=call_id)
        return jsonify({"status": "ended"})
    return jsonify({"error": "Call not found"}), 404

@app.route('/api/sos/video/latest', methods=['GET'])
def get_latest_call():
    """Get the most recent active call for automatic responder connection"""
    active_calls = {cid: call for cid, call in calls.items() 
                    if call['active'] and time.time() < call['expiresAt']}
    
    if not active_calls:
        return jsonify({"error": "No active calls"}), 404
    
    # Get the most recent call (highest expiresAt means most recent)
    latest_call_id = max(active_calls.keys(), key=lambda cid: active_calls[cid]['expiresAt'])
    
    return jsonify({
        "callId": latest_call_id,
        "expiresAt": active_calls[latest_call_id]['expiresAt']
    })

@app.route('/responder')
def responder_page():
    """Serve the responder HTML page"""
    return send_file('responder.html')

# --- Socket.IO Events ---

@socketio.on('join-call')
def on_join(data):
    call_id = data.get('callId')
    token = data.get('token')
    role = data.get('role')
    
    print(f"[Flask] join-call request - CallID: {call_id}, Role: {role}, SID: {request.sid}")
    
    call = calls.get(call_id)
    
    if not call:
        print(f"[Flask] ERROR: Call {call_id} not found in memory")
        emit('error', {'message': 'Call not found'})
        return

    if not call['active']:
        print(f"[Flask] ERROR: Call {call_id} is not active")
        emit('error', {'message': 'Call ended'})
        return
        
    if time.time() > call['expiresAt']:
        call['active'] = False
        print(f"[Flask] ERROR: Call {call_id} has expired")
        emit('call-expired')
        return
    
    # Simple Token Check (MVP)
    # If role is citizen, token must match
    if role == 'citizen':
        if token != call['citizenToken']:
            print(f"[Flask] ERROR: Invalid citizen token for call {call_id}")
            emit('error', {'message': 'Invalid token'})
            return
            
    # If role is responder, currently we allow open access or check responderToken if passed
    # For MVP as per req, "allow join only if call exists" (plus minimal auth)
    
    join_room(call_id)
    emit('user-joined', {'role': role}, to=call_id)
    print(f"[Flask] SUCCESS: {role} joined room {call_id}")

@socketio.on('offer')
def on_offer(data):
    room = data.get('room')
    emit('offer', data.get('sdp'), to=room, include_self=False)

@socketio.on('answer')
def on_answer(data):
    room = data.get('room')
    emit('answer', data.get('sdp'), to=room, include_self=False)

@socketio.on('ice-candidate')
def on_ice(data):
    room = data.get('room')
    emit('ice-candidate', data.get('candidate'), to=room, include_self=False)

@socketio.on('end-call')
def on_end_call(data):
    room = data.get('room')
    if room in calls:
        calls[room]['active'] = False
    emit('end-call', to=room)

@socketio.on('connect')
def on_connect():
    print(f"[Flask] Client connected - SID: {request.sid}")

@socketio.on('disconnect')
def on_disconnect():
    print(f"[Flask] Client disconnected - SID: {request.sid}")

if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=5000, debug=True, allow_unsafe_werkzeug=True)
