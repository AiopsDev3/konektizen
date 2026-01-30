
*** SIMPLE SETUP GUIDE FOR KONEKTIZEN (YOUR PC) ***

Hello! 👋
Here is your checklist to get the Konektizen System running perfectly for the integration.

You need to run 4 things in 4 separate terminals.

=== STEP 1: CHECK YOUR IP ===
1. Ensure you are connected to the WiFi.
2. Your IP MUST be: 172.16.0.101
   (If it changed, you must update `backend/.env` and `lib/core/config/environment.dart`)

=== STEP 2: START BACKEND (Terminal 1) ===
cd Desktop\konektizen\backend
npm run dev
> Wait for: "Server running on..."

=== STEP 3: START SOS SERVICE (Terminal 2) ===
cd Desktop\konektizen\backend_sos
python app.py
> Wait for: "Debugger is active"

=== STEP 4: CONNECT PHONE (Terminal 3) ===
cd Desktop\konektizen
adb reverse tcp:3000 tcp:3000
adb reverse tcp:5000 tcp:5000
> This allows your phone to talk to your laptop.

=== STEP 5: RUN APP (Terminal 4) ===
cd Desktop\konektizen
flutter run

*** DONE! ***
The system is now live.
- App talks to Backend (Port 3000).
- App talks to SOS (Port 5000).
- Backend talks to Command Center (via the Connector Script).
