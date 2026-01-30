# Command Center Integration Guide (AIOPSYS)

This guide explains how to integrate your **Command Center** with the **Konektizen SOS System**.

The integration allows your Command Center to:

1.  **Receive Real-time Alerts** containing Incident Data (JSON).
2.  **Instant Video Connection** (Popup) when an SOS is triggered.

---

## 1. Architecture Overview

- **Mobile App**: Citizen presses SOS.
- **Konektizen Backend**: Receives SOS -> Forwards to Command Center.
- **Command Center (Connector)**: Listens for Alert -> Opens Video Popup.

---

## 2. Setup (On Command Center Machine)

You only need **Node.js** and one script file.

### Step 2.1: Create Integration Folder

Create a folder named `Konektizen_Connector` on your desktop (or server).

### Step 2.2: Add the Connector Script

Copy the file `aiopsys_connector.js` (provided below) into this folder.

<details>
<summary><b>Click to view aiopsys_connector.js</b></summary>

```javascript
/**
 * AIOPSYS CONNECTOR SCRIPT
 * Run this on the Command Center Machine/PC to receive SOS Alerts.
 */
const express = require("express");
const bodyParser = require("body-parser");
const open = require("open"); // npm install open
const cors = require("cors");

const app = express();
const PORT = 5001; // Port to listen on

app.use(cors());
app.use(bodyParser.json());

// 1. Receive New Report
app.post("/api/citizen/reports", (req, res) => {
  console.log("\n[NEW REPORT RECEIVED]");
  console.log("Category:", req.body.category);
  // Add your DB insert logic here
  res.json({ status: "queued", message: "Report received" });
});

// 2. Receive SOS Alert (High Priority)
app.post("/api/citizen/sos", async (req, res) => {
  console.log("\n🚨 [SOS ALERT RECEIVED] 🚨");
  let { action_link } = req.body;

  // Ensure link works locally if needed
  // If backend sends internal IP, ensure Command Center can access it.

  // AUTOMATICALLY OPEN THE BROWSER (The "Popup" Effect)
  if (action_link) {
    console.log("Opening Responder Video Link...");
    try {
      // Opens the default browser to the Video Room
      await open(action_link);
    } catch (e) {
      console.error("Failed to open browser:", e.message);
    }
  }
  res.json({ status: "ACK", message: "SOS Alert Dispatched" });
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`\n✅ Command Center Connector running on Port ${PORT}`);
  console.log(`Waiting for alerts...`);
});
```

</details>

### Step 2.3: Install Dependencies

Open a terminal in that folder and run:

```bash
npm init -y
npm install express open body-parser cors
```

### Step 2.4: Run the Connector

```bash
node aiopsys_connector.js
```

**Keep this terminal running.** It acts as your "listener".

---

## 3. How It Works

1.  **Citizen** presses **SOS** in the generic Konektizen App.
2.  **Konektizen Backend** sends a POST request to your Command Center (running `aiopsys_connector.js`).
3.  **Your Connector** receives the alert and **Auto-Launches** a browser window.
4.  **The Browser Window** loads the secure WebRTC Video Room.
5.  **Video connects automatically**. The operator can see/hear the citizen immediately.

---

## 4. Configuration (Important)

Ensure the **Konektizen Backend** is configured to point to your Command Center's IP.

In `backend/.env` (or environment variables):

```env
AIOPSYS_API_URL=http://<COMMAND_CENTER_IP>:5001
```

_Replace `<COMMAND_CENTER_IP>` with the actual IP address of the machine running the connector script._

---

## 5. Troubleshooting

- **No Popup?** Ensure the Command Center machine allows the terminal to open browsers. Check if a popup blocker is active.
- **Video Connection Failed?** Ensure both the Citizen App and the Command Center machine can reach the **Signaling Server** (usually `http://<SERVER_IP>:5000`).
