@echo off
REM Regenerate the C source from rulemak.klc.
REM
REM Only needed if you EDIT the layout. The generated files are committed,
REM so building does not require MSKLC at all.
REM
REM MSKLC's kbdutool is used ONLY to translate .klc -> .C/.H/.DEF/.RC.
REM Its bundled compiler is NOT used - that is what produces the broken DLL.
setlocal

set "KBDUTOOL=%APPDATA%\Microsoft Keyboard Layout Creator 1.4\bin\i386\kbdutool.exe"
if not exist "%KBDUTOOL%" (
  echo ERROR: kbdutool not found at:
  echo   %KBDUTOOL%
  echo Install Microsoft Keyboard Layout Creator 1.4, or edit this path.
  exit /b 1
)

cd /d "%~dp0..\source"
echo === generating C source from rulemak.klc ===
"%KBDUTOOL%" -u -s -w rulemak.klc
if errorlevel 1 (echo KBDUTOOL FAILED & exit /b 1)

echo.
echo Done. Now run build.bat and build32.bat.
echo Note: "Warning 1015 - character defined on both X and Y" is benign;
echo it just means two keys emit the same character.
