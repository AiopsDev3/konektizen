@echo off
echo ========================================
echo   KILLING ALL BACKEND PROCESSES
echo ========================================
echo.

REM Kill all python.exe processes
echo Stopping all Python processes...
taskkill /F /IM python.exe >nul 2>&1

echo Waiting 3 seconds...
timeout /t 3 /nobreak >nul

echo.
echo ========================================
echo   STARTING FRESH BACKEND
echo ========================================
echo.

cd /d C:\Users\EliteBook\Desktop\konektizen\backend_sos
start "KONEKTIZEN Backend (Port 5000)" cmd /k "python app.py"

echo.
echo Backend started in new window!
echo Configuration: http://192.168.1.5:8000
echo.
echo Press any key to close this window...
pause >nul
