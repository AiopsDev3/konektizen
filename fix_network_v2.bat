@echo off
echo ==================================================
echo      KONEKTIZEN NETWORK FIX V2 (Admin Required)
echo ==================================================
echo.
echo 1. Requesting Admin Privileges...
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Success: Running as Administrator.
) else (
    echo Error: Please Right-Click this file and 'Run as Administrator'.
    pause
    exit
)

echo.
echo 2. Opening Windows Firewall (Port 8000)...
netsh advfirewall firewall delete rule name="Jitsi Port 8000"
netsh advfirewall firewall add rule name="Jitsi Port 8000" dir=in action=allow protocol=TCP localport=8000
echo    Firewall Rule Added.

echo.
echo 3. Refreshing Port Bridge (Windows -> WSL2)...
netsh interface portproxy delete v4tov4 listenport=8000 listenaddress=0.0.0.0
netsh interface portproxy add v4tov4 listenport=8000 listenaddress=0.0.0.0 connectport=8000 connectaddress=172.30.189.152

echo.
echo 4. Verifying Configuration...
netsh interface portproxy show v4tov4 | findstr "8000"
netsh advfirewall firewall show rule name="Jitsi Port 8000" | findstr "Enabled"

echo.
echo ==================================================
echo    FIX APPLIED. 
echo    Please Retry the Mobile App SOS Call now.
echo ==================================================
pause
