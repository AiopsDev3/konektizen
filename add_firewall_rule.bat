@echo off
echo Adding Windows Firewall rule for Node.js backend on port 3000...
netsh advfirewall firewall add rule name="Allow Node Backend" dir=in action=allow protocol=TCP localport=3000
if %errorlevel% == 0 (
    echo SUCCESS: Firewall rule added!
) else (
    echo FAILED: Could not add firewall rule. Make sure you run this as Administrator.
)
pause
