@echo off
REM Double-clickable installer. Resolves its own location and self-elevates, so
REM it works from Explorer or any shell regardless of the current directory.
REM Output is echoed and also written to install-log.txt next to this file.
setlocal
set "HERE=%~dp0"

net session >nul 2>&1
if %errorlevel% equ 0 goto :elevated

echo Requesting administrator rights...
powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
exit /b 0

:elevated
echo Installing from %HERE%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%install.ps1" > "%HERE%install-log.txt" 2>&1
set "RC=%errorlevel%"
type "%HERE%install-log.txt"
echo.
if "%RC%"=="0" (
    echo === done - REBOOT before the layout appears ===
) else (
    echo === FAILED with exit code %RC% - see %HERE%install-log.txt ===
)
echo.
pause
