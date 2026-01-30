# KONEKTIZEN <-> AIOPSYS API GUIDE

**Role**: This document instructs the Command Center on how to native support SOS Alerts.

## The Concept

The "Responder" is now **YOU (The Command Center)**.
We do not use a separate responder app anymore. All SOS calls go directly to your system API.

## Your Responsibility

You must expose a **POST Endpoint** (Webhook) that listens for incoming alerts.
When our User hits "SOS", we will call this endpoint immediately.

---

## 1. Create the Endpoint

Please implement the following route on your server:

> `POST /api/citizen/sos`

## 2. The Payload (JSON)

We will send this data to you. You should parse it and trigger your **Emergency Notification System**.

```json
{
  "event": "SOS_ALERT",
  "alertId": "uuid-1234-5678",
  "timestamp": "2026-01-27T10:00:00Z",
  "priority": "HIGH",
  "reporterInfo": {
    "name": "Juan Dela Cruz",
    "phone": "+63 912 345 6789",
    "id": "user-uuid-123"
  },
  "location": {
    "latitude": 14.5,
    "longitude": 121.0,
    "address": "123 Rizal St, Manila"
  },
  "action_link": "http://172.16.0.101:5000/responder?room=uuid"
}
```

## 3. Recommended Workflow (Logic)

When your server receives this JSON:

1.  **Play Alarm**: Trigger an audible alert on the dashboard.
2.  **Display Map**: Plot the `lat/long` on your map.
3.  **Show Info**: Display the Reporter Name and Phone.
4.  **VIDEO CALL**:
    - The `action_link` is a direct link to the Video Room.
    - **Action**: Automatically open this link in a modal/popup for the operator.
    - **Result**: The operator is instantly connected to the citizen via video.

## 4. Response

Please reply with a standard `200 OK` JSON to confirm receipt:

```json
{
  "status": "acknowledged",
  "message": "Alert received, unit dispatched."
}
```
