@echo off
echo Setting up ADB reverse for wireless debugging...
echo.

C:\Users\EliteBook\AppData\Local\Android\sdk\platform-tools\adb.exe reverse tcp:3000 tcp:3000
if %errorlevel% neq 0 (
    echo ERROR: Failed to set up port 3000
    pause
    exit /b 1
)
echo Port 3000 forwarded successfully

C:\Users\EliteBook\AppData\Local\Android\sdk\platform-tools\adb.exe reverse tcp:5000 tcp:5000
if %errorlevel% neq 0 (
    echo ERROR: Failed to set up port 5000
    pause
    exit /b 1
)
echo Port 5000 forwarded successfully

echo.
echo ADB reverse setup complete!
echo Your app can now connect to localhost services.
echo.
pause
