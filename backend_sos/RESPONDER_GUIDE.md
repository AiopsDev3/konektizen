# How to Test the Video Call (Responder Side)

## Quick Start

1. **Open the responder web page:**

   - Navigate to: `c:\Users\EliteBook\Desktop\konektizen\backend_sos\responder.html`
   - Double-click to open it in your browser (Chrome, Edge, or Firefox)

2. **Trigger SOS on your phone:**

   - Open the Konektizen app
   - Press the Emergency SOS button
   - Confirm the SOS

3. **Get the Call ID:**

   - Look at the Flask backend terminal (the one running on port 5000)
   - You'll see a log like: `User joined abc123xyz as citizen`
   - The Call ID is `abc123xyz`

4. **Join the call from browser:**

   - Enter the Call ID in the web page
   - Click "Join Call"
   - Allow camera and microphone permissions when prompted

5. **You should now see:**
   - The citizen's video (from the phone) in full screen
   - Your video (from the laptop camera) in the small corner
   - Both sides can see each other! 🎉

## Alternative: Automatic Call ID Detection

If you want to make it easier, I can modify the responder page to automatically detect new calls. Let me know!

## Troubleshooting

**Problem:** "Call not found" error

- Make sure the Flask backend is running
- Make sure you entered the correct Call ID
- The call expires after 10 minutes

**Problem:** No video showing

- Check browser console for errors (F12)
- Make sure both sides granted camera/microphone permissions
- Try refreshing the page and rejoining

**Problem:** Can't hear audio

- Check if microphone is muted (🎤 button)
- Check browser audio permissions
- Check system audio settings
