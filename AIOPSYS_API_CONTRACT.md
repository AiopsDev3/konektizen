# AIOPSYS Integration Contract

This document defines the API contract between **Konektizen** (Citizen App Backend) and **AIOPSYS** (Command Center).

## 1. Authentication

All requests between the two systems must include the following header:
`X-API-KEY: <shared-secret-key>`
_(Default for development: `konektizen-aiopsys-secret-key`)_

## 2. Konektizen -> AIOPSYS (Outbound Webhooks)

Konektizen will send these events to AIOPSYS.

### 2.1 New Incident Report

**Endpoint**: `POST /api/citizen/reports`
**Payload**:

```json
{
  "reportId": "uuid-1234",
  "category": "FIRE",
  "description": "Fire near the market...",
  "latitude": 14.5,
  "longitude": 121.0,
  "address": "123 Main St",
  "status": "submitted",
  "timestamp": "2026-01-27T10:30:00Z",
  "mediaUrls": ["http://172.16.0.101:3000/uploads/fire1.jpg"],
  "reporterInfo": {
    "name": "Juan Dela Cruz",
    "phone": "+639123456789",
    "id": "user-uuid"
  }
}
```

### 2.2 SOS Emergency Alert (Priority)

**Endpoint**: `POST /api/citizen/sos`
**Payload**:

```json
{
  "event": "SOS_ALERT",
  "alertId": "sos-uuid-5678",
  "latitude": 14.5,
  "longitude": 121.0,
  "timestamp": "2026-01-27T10:35:00Z",
  "reporterInfo": { ... },
  "action_link": "http://172.16.0.101:5000/responder?room=sos-uuid-5678&auto_join=true"
}
```

> **Action Required**: When the operator receives this, they should open the `action_link` in a browser to join the video call immediately.

## 3. AIOPSYS -> Konektizen (Inbound Updates)

AIOPSYS should call this endpoint to update the status of a report.

### 3.1 Status Update

**Endpoint**: `POST /api/integrations/aiopsys/status-update`
**Headers**: `X-API-KEY: ...`
**Payload**:

```json
{
  "reportId": "uuid-1234",
  "status": "DISPATCHED",
  "responderEta": "10 minutes",
  "note": "Unit 5 is en route."
}
```

**Supported Statuses**: `SUBMITTED`, `DISPATCHED`, `RESOLVED`, `REJECTED`.
