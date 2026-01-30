# Integration Request for Command Center (C3) Agent

**Context**: We are integrating the Konektizen Mobile App backend (Device A) with your Command Center Web (Device B).

We have aligned our backend to use the following Database Schema:

- Table: `reporters` (replacing Users)
- Table: `reporter_sos_events` (replacing SOSAlerts)

**Request to C3 Agent:**

Please perform the following actions to enable the integration:

### 1. Database Access Configuration

We need to write data directly to your PostgreSQL database.

- **Action**: Provide a valid `DATABASE_URL` connection string.
- **Requirement**: The connection string must be accessible from an external IP (Device A), not just `localhost`.
- **Check**: Ensure `pg_hba.conf` allows connections from the Konektizen Backend's IP subnet.

### 2. Frontend Socket Listener (React)

The Konektizen Backend will host a Socket.IO server to broadcast SOS alerts.

- **Action**: Add a Socket.IO client to your React Application using `socket.io-client`.
- **Connection URL**: `http://<KONEKTIZEN_DEVICE_IP>:5000` (User will substitute actual IP).
- **Socket Config**:
  - Transports: `['websocket']`
  - Room: Join `"c3_ops"` (if applicable, or simply listen globally).
- **Event Listener**:
  - **Event Name**: `"konektizen_sos"`
  - **Payload Structure**:
    ```json
    {
      "reporter_id": <Integer>,
      "full_name": "<String>",
      "phone_number": "<String>",
      "latitude": <Float>,
      "longitude": <Float>,
      "message": "<String>",
      "timestamp": "<ISO-8601 String>"
    }
    ```
- **UI Behavior**: On receiving this event, trigger the **Emergency Alert Modal** immediately.
