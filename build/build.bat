@echo off
REM Build Rulemak.dll (x64). Requires Visual Studio with the C++ workload.
REM Output: ..\binaries\amd64\Rulemak.dll
setlocal

set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" (echo ERROR: vswhere not found - is Visual Studio installed? & exit /b 1)

for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -products * ^
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSPATH=%%i"
if not defined VSPATH (echo ERROR: no VS install with C++ tools & exit /b 1)

call "%VSPATH%\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
if errorlevel 1 (echo ERROR: vcvars64 failed & exit /b 1)

set "ROOT=%~dp0.."
set "OUT=%ROOT%\binaries\amd64"
if not exist "%OUT%" mkdir "%OUT%"
cd /d "%ROOT%\source"

echo === compiling (x64) ===
cl /nologo /c /O1 /GS- /W3 /Fo"%TEMP%\Rulemak64.obj" Rulemak.C || exit /b 1

echo === resources ===
rc /nologo /r /fo "%TEMP%\Rulemak64.res" Rulemak.RC || exit /b 1

echo === linking ===
REM See README "Why the link flags matter" - a default link produces a DLL
REM that Windows silently refuses to load as a keyboard layout.
link /nologo /DLL /NOENTRY /NODEFAULTLIB /MACHINE:X64 /SUBSYSTEM:NATIVE ^
     /DYNAMICBASE:NO /NXCOMPAT:NO /HIGHENTROPYVA:NO ^
     /MERGE:.text=.data /MERGE:.rdata=.data /SECTION:.data,RE ^
     /DEF:Rulemak.DEF /OUT:"%OUT%\Rulemak.dll" ^
     "%TEMP%\Rulemak64.obj" "%TEMP%\Rulemak64.res" || exit /b 1

del "%OUT%\Rulemak.lib" "%OUT%\Rulemak.exp" 2>nul
echo === done: %OUT%\Rulemak.dll ===
