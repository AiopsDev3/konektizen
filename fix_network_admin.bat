@echo off
echo ==================================================
echo      KONEKTIZEN NETWORK FIX (Admin Required)
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
echo 2. Setting up Port Bridge (Windows -> WSL2)...
echo    Mapping 0.0.0.0:8000 to 172.30.189.152:8000...
netsh interface portproxy delete v4tov4 listenport=8000 listenaddress=0.0.0.0
netsh interface portproxy add v4tov4 listenport=8000 listenaddress=0.0.0.0 connectport=8000 connectaddress=172.30.189.152

echo.
echo 3. Verifying Bridge...
netsh interface portproxy show v4tov4 | findstr "8000"

echo.
echo ==================================================
echo    NETWORK FIX APPLIED. 
echo    Please Retry the Mobile App SOS Call now.
echo ==================================================
pause
