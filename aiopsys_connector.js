
/**
 * AIOPSYS CONNECTOR SCRIPT
 * ------------------------
 * Run this on the Command Center Machine to receive SOS Alerts from Konektizen.
 * 
 * Usage:
 * 1. Install Node.js
 * 2. Run: npm init -y
 * 3. Run: npm install express open body-parser cors
 * 4. Run: node aiopsys_connector.js
 */

const express = require('express');
const bodyParser = require('body-parser');
const open = require('open'); // Cross-platform open
const cors = require('cors');

const app = express();
const PORT = 5001; // Must match Konektizen .env

app.use(cors());
app.use(bodyParser.json());

// 1. Receive New Report
app.post('/api/citizen/reports', (req, res) => {
    console.log('\n[NEW REPORT RECEIVED]');
    console.log('Category:', req.body.category);
    console.log('Description:', req.body.description);
    console.log('Media:', req.body.mediaUrls);
    
    // In a real system, save this to DB.
    res.json({ status: 'queued', message: 'Report received by AIOPSYS' });
});

// 2. Receive SOS Alert (High Priority)
app.post('/api/citizen/sos', async (req, res) => {
    console.log('\n🚨 [SOS ALERT RECEIVED] 🚨');
    const { alertId, latitude, longitude, action_link, reporterInfo } = req.body;
    
    console.log(`Reporter: ${reporterInfo?.name} (${reporterInfo?.phone})`);
    console.log(`Location: ${latitude}, ${longitude}`);
    console.log(`Link: ${action_link}`);

    // AUTOMATICALLY OPEN THE BROWSER (The "Popup" Effect)
    if (action_link) {
        console.log('Opening Responder Dashboard...');
        try {
            await open(action_link);
        } catch (e) {
            console.error('Failed to open browser:', e.message);
        }
    }

    res.json({ status: 'ACK', message: 'SOS Alert Dispatched' });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`\n✅ AIOPSYS Connector running on Port ${PORT}`);
    console.log(`Waiting for alerts...`);
});
