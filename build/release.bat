@echo off
REM Build both DLLs and stage a release zip for GitHub.
REM Usage: build\release.bat 1.0
REM Output: ..\dist\rulemak-<version>.zip  and  ..\dist\SHA256SUMS.txt
setlocal

set "VER=%~1"
if "%VER%"=="" (echo ERROR: version required, e.g. build\release.bat 1.0 & exit /b 1)

set "ROOT=%~dp0.."
set "DIST=%ROOT%\dist"
set "STAGE=%DIST%\rulemak-%VER%"

echo === building both architectures ===
call "%~dp0build.bat"   || (echo ERROR: x64 build failed & exit /b 1)
call "%~dp0build32.bat" || (echo ERROR: x86 build failed & exit /b 1)

echo.
echo === staging %STAGE% ===
REM Clear the whole dist tree, not just this version's staging folder, so old
REM zips cannot linger uncovered by the regenerated SHA256SUMS.txt.
if exist "%DIST%" rmdir /s /q "%DIST%"
mkdir "%STAGE%\binaries\amd64" || exit /b 1
mkdir "%STAGE%\binaries\x86"   || exit /b 1
mkdir "%STAGE%\install"        || exit /b 1

copy /y "%ROOT%\binaries\amd64\Rulemak.dll" "%STAGE%\binaries\amd64\" >nul || exit /b 1
copy /y "%ROOT%\binaries\x86\Rulemak.dll"   "%STAGE%\binaries\x86\"   >nul || exit /b 1
copy /y "%ROOT%\install\install.cmd"        "%STAGE%\install\"        >nul || exit /b 1
copy /y "%ROOT%\install\install.ps1"        "%STAGE%\install\"        >nul || exit /b 1
copy /y "%ROOT%\install\uninstall.cmd"      "%STAGE%\install\"        >nul || exit /b 1
copy /y "%ROOT%\install\uninstall.ps1"      "%STAGE%\install\"        >nul || exit /b 1
copy /y "%ROOT%\README.md"                  "%STAGE%\"               >nul || exit /b 1
copy /y "%ROOT%\LICENSE"                    "%STAGE%\"               >nul || exit /b 1

echo === zipping ===
REM Zip the staging folder itself, not its contents, so unpacking creates a
REM rulemak-<version>\ directory instead of scattering files into the cwd.
powershell -NoProfile -Command ^
  "Compress-Archive -Path '%STAGE%' -DestinationPath '%DIST%\rulemak-%VER%.zip' -Force" || exit /b 1

REM certutil, not Get-FileHash - it is a native binary and does not depend on
REM PowerShell module autoloading, which breaks if PSModulePath is unusual.
echo === checksums ===
if exist "%DIST%\SHA256SUMS.txt" del "%DIST%\SHA256SUMS.txt"
REM Label the DLLs by their path inside the zip, which is what a downloader
REM actually has on disk.
call :sha "%DIST%\rulemak-%VER%.zip"          "rulemak-%VER%.zip"                       || exit /b 1
call :sha "%ROOT%\binaries\amd64\Rulemak.dll" "rulemak-%VER%/binaries/amd64/Rulemak.dll" || exit /b 1
call :sha "%ROOT%\binaries\x86\Rulemak.dll"   "rulemak-%VER%/binaries/x86/Rulemak.dll"   || exit /b 1
type "%DIST%\SHA256SUMS.txt"

REM The staging tree is redundant once zipped; leaving it invites attaching
REM loose files to the release by mistake.
if exist "%STAGE%" rmdir /s /q "%STAGE%"

echo.
echo === done ===
echo   %DIST%\rulemak-%VER%.zip
echo   %DIST%\SHA256SUMS.txt
echo.
echo Attach both to the GitHub release, then tag:
echo   git tag -a v%VER% -m "Rulemak %VER%" ^&^& git push origin v%VER%
goto :eof

:sha
REM certutil prints a header line, the bare hash, then a trailing status line.
REM On failure it prints its errors to stdout too, so the captured token can be
REM "CertUtil:" rather than nothing. Validate that it really is a hex digest
REM instead of assuming an empty _H means failure.
set "_H="
for /f "usebackq skip=1 tokens=1" %%h in (`certutil -hashfile "%~1" SHA256`) do (
    if not defined _H set "_H=%%h"
)
if not defined _H (echo ERROR: could not hash %~1 & exit /b 1)
echo %_H%| findstr /r /i "^[0-9a-f][0-9a-f]*$" >nul || (
    echo ERROR: certutil did not return a digest for %~1
    echo        got: %_H%
    exit /b 1
)
set "_NAME=%~2"
if not defined _NAME set "_NAME=%~nx1"
>>"%DIST%\SHA256SUMS.txt" echo %_H%  %_NAME%
set "_H="
set "_NAME="
exit /b 0
