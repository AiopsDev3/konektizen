@echo off
echo Stopping all Python backend processes...
taskkill /F /IM python.exe /FI "WINDOWTITLE eq *backend_sos*" 2>nul

timeout /t 2 /nobreak >nul

echo Starting fresh backend...
cd /d C:\Users\EliteBook\Desktop\konektizen\backend_sos
start "Backend SOS (Fresh)" python app.py

echo.
echo Backend restarted with fresh configuration!
echo Server URL: http://192.168.1.5:8000
pause
