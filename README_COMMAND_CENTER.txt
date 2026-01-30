
*** SIMPLE SETUP GUIDE FOR COMMAND CENTER ***

Hello Command Center Team! 👋

Here is how to connect your system to receive SOS Alerts from the Konektizen App.
When an SOS comes in, this script will automatically open the Video Call on your screen.

=== STEP 1: PREPARE ===
1. Make sure your computer is connected to the SAME WIFI as the Konektizen Laptop.
2. Download/Install "Node.js" if you don't have it (https://nodejs.org/).

=== STEP 2: SETUP THE FOLDER ===
1. Create a new folder on your Desktop called "AIOPSYS_CONNECT".
2. Copy the file "aiopsys_connector.js" into that folder. (Ask the Konektizen dev for this file).

=== STEP 3: RUN THE CONNECTOR ===
1. Open your Terminal (Command Prompt).
2. Type endpoints to go into your folder:
   cd Desktop\AIOPSYS_CONNECT

3. Install the required tools (copy-paste this line and hit Enter):
   npm install express cors open body-parser

4. Start the listener:
   node aiopsys_connector.js

=== STEP 4: SUCCESS! ===
You should see a message:
"✅ AIOPSYS Connector running on Port 5001"

Now, wait. When the Citizen presses the Red SOS Button, your browser will POP UP automatically with the video call! 🚨

***************************************************
