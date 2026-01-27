@echo off
echo Attempting to configure USB connection...

:: Try using adb directly if in PATH
call adb reverse tcp:3000 tcp:3000 >nul 2>&1
if %ERRORLEVEL% EQU 0 goto success

:: If failed, try finding adb in default Android SDK location
if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
    echo Found ADB in common path. Running...
    "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" reverse tcp:3000 tcp:3000
    if %ERRORLEVEL% EQU 0 goto success
)

echo.
echo [ERROR] Could not run ADB command. 
echo Please ensure Android SDK Platform Tools are installed.
echo.
pause
exit /b 1

:success
echo.
echo [SUCCESS] Device connection configured!
echo Your phone can now access the backend via USB cable.
echo.
pause
