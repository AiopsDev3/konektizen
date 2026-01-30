# Integration Questionnaire for AIOPSYS (Command Center)

**Purpose**: We are integrating the **KONEKTIZEN SOS App** with your **Command Center**. We use a **WebRTC** architecture for real-time video. To ensure a seamless reliable connection without our custom responder web interface, we need to define the technical handshake.

Please answer the following questions to help us provide the exact API/SDK you need.

---

### 1. The Trigger (Notification)

When a citizen presses "SOS", our backend needs to notify your system instantly.

- **Q1.1**: Should we send a **HTTP Webhook (POST)** to your API?
  - _If yes, please provide the Endpoint URL format and required Auth Headers._
- **Q1.2**: Or do you prefer to maintain a persistent **Socket Connection (WebSocket/Socket.io)** to our server to listen for events?

### 2. Video Signaling (WebRTC Handshake)

WebRTC requires an exchange of SDP (Session Description Protocol) and ICE Candidates to establish a peer-to-peer connection.

- **Q2.1**: Does your Command Center application already have a built-in **SIP/WebRTC Client**?
  - _If yes, does it support standard browser-based WebRTC signaling, or SIP?_
- **Q2.2**: Do you want to implement the signaling logic (Socket.io listeners for `offer`, `answer`, `ice-candidate`) directly in your backend/frontend code?
  - _We can provide a standard "Socket Event Contract" for this._
- **Q2.3**: OR, would you prefer we provide a **JavaScript SDK / Client Library** that you simply import into your frontend to handle the connection complexity?

### 3. Visual Integration (Frontend)

How will the video actually appear to your operators?

- **Q3.1**: Is your Command Center a **Web-based Application** (React, Angular, Plain HTML)?
  - _If yes, we can provide a React Component or JS snippet._
- **Q3.2**: Is it a **Desktop Application** (.NET, Java, Electron)?
  - _If native, do you have a WebView container, or do you need a raw media stream URL?_
- **Q3.3**: Do you prefer to Embed our video player via an **IFrame** (hosting a minimal "headless" player on our side), or do you want full control over the `<video>` rendering elements?

### 4. Network & Security

- **Q4.1**: Are there firewall restrictions that would block **UDP High Ports** (standard for WebRTC)?
- **Q4.2**: Do you require a **TURN Server** for relaying traffic, or is direct P2P (or STUN) sufficient within the deployment network?
- **Q4.3**: Do you require specific **Authentication Tokens** (JWT) to be passed in the signaling handshake?

---

**Summary for the AI Agent:**

> "Please review the current AIOPSYS architecture and tell us the preferred method to consume an external WebRTC stream. Do you want a **Low-Level Signaling API** (Socket Events) to build your own client, or a **High-Level Widget/IFrame** to embed? This determines the Integration Guide we will write."
