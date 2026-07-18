<#
.SYNOPSIS
    Remove the Rulemak keyboard layout.

.DESCRIPTION
    Removes the layout from the current user's input methods, deletes the
    registry registration, and removes the DLLs from System32 / SysWOW64.

    Must be run elevated. Reboot afterwards.

.EXAMPLE
    Start-Process powershell -Verb RunAs -ArgumentList '-ExecutionPolicy','Bypass','-File','.\uninstall.ps1'
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
      ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'This script must be run elevated (Run as Administrator).'
}

$layouts = 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts'

# Find every KLID pointing at Rulemak.dll (normally just one).
$ours = Get-ChildItem $layouts | Where-Object {
    (Get-ItemProperty $_.PSPath -EA SilentlyContinue).'Layout File' -eq 'Rulemak.dll'
}

if (-not $ours) {
    Write-Host 'no Rulemak registration found'
} else {
    # Drop it from the user's input methods first, while the KLID still resolves.
    foreach ($k in $ours) {
        $tip = '0419:{0}' -f $k.PSChildName.ToUpper()
        try {
            $list = Get-WinUserLanguageList
            $changed = $false
            foreach ($lang in $list) {
                if ($lang.InputMethodTips -contains $tip) {
                    [void]$lang.InputMethodTips.Remove($tip); $changed = $true
                }
            }
            if ($changed) { Set-WinUserLanguageList $list -Force; Write-Host "removed $tip from input methods" }
        } catch {
            Write-Warning "could not update the user language list: $_"
        }
    }

    foreach ($k in $ours) {
        Remove-Item $k.PSPath -Recurse -Force
        Write-Host "removed registration $($k.PSChildName)"
    }
}

foreach ($dll in 'C:\Windows\System32\Rulemak.dll', 'C:\Windows\SysWOW64\Rulemak.dll') {
    if (Test-Path $dll) {
        try { Remove-Item $dll -Force; Write-Host "deleted $dll" }
        catch { Write-Warning "could not delete $dll (in use?) - it will go on reboot: $_" }
    }
}

Write-Host ''
Write-Host 'Uninstalled. Reboot to fully unload the layout.' -ForegroundColor Yellow
