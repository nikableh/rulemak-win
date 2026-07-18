<#
.SYNOPSIS
    Install the Rulemak keyboard layout (Russian Colemak).

.DESCRIPTION
    Copies the layout DLLs into System32 / SysWOW64 and registers them, then
    adds the layout to the current user's Russian input methods.

    Must be run elevated. Reboot (or sign out and back in) afterwards -
    win32k caches layout DLLs, so the layout will not appear until you do.

.EXAMPLE
    Start-Process powershell -Verb RunAs -ArgumentList '-ExecutionPolicy','Bypass','-File','.\install.ps1'
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
      ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'This script must be run elevated (Run as Administrator).'
}

$root  = Split-Path $PSScriptRoot -Parent
$src64 = Join-Path $root 'binaries\amd64\Rulemak.dll'
$src32 = Join-Path $root 'binaries\x86\Rulemak.dll'

foreach ($f in $src64, $src32) {
    if (-not (Test-Path $f)) { throw "missing binary: $f  (run build\build.bat and build\build32.bat)" }
}

# ---------------------------------------------------------------- DLLs -----
Copy-Item $src64 'C:\Windows\System32\Rulemak.dll' -Force
Write-Host 'installed x64 -> C:\Windows\System32\Rulemak.dll'
if (Test-Path 'C:\Windows\SysWOW64') {
    Copy-Item $src32 'C:\Windows\SysWOW64\Rulemak.dll' -Force
    Write-Host 'installed x86 -> C:\Windows\SysWOW64\Rulemak.dll'
}

# ------------------------------------------------------------ registry -----
$layouts = 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts'

# a000 = custom layout, 0419 = ru-RU. If a0000419 is taken by a DIFFERENT
# layout, step up to a0010419, a0020419, ... so we never clobber someone else's.
$klid = $null
foreach ($i in 0..15) {
    $cand = 'a00{0:x1}0419' -f $i              # a0000419, a0010419, ...
    $key  = Join-Path $layouts $cand
    if (-not (Test-Path $key)) { $klid = $cand; break }
    if ((Get-ItemProperty $key).'Layout File' -eq 'Rulemak.dll') { $klid = $cand; break }  # ours, reuse
}
if (-not $klid) { throw 'no free custom KLID slot for ru-RU' }

# Layout Id must be unique across ALL installed layouts.
$key = Join-Path $layouts $klid
$existingId = if (Test-Path $key) { (Get-ItemProperty $key).'Layout Id' } else { $null }
if ($existingId) {
    $idHex = $existingId
} else {
    $used = Get-ChildItem $layouts | ForEach-Object { (Get-ItemProperty $_.PSPath).'Layout Id' } |
            Where-Object { $_ } | ForEach-Object { [Convert]::ToInt32($_, 16) }
    $free = 1..0xfff | Where-Object { $_ -notin $used } | Select-Object -First 1
    if (-not $free) { throw 'no free Layout Id' }
    $idHex = '{0:x4}' -f $free
}

New-Item -Path $key -Force | Out-Null
$values = @{
    'Layout File'                  = 'Rulemak.dll'
    'Layout Text'                  = 'Rulemak'
    'Layout Id'                    = $idHex
    'Layout Display Name'          = '@%SystemRoot%\system32\Rulemak.dll,-1000'
    'Custom Language Name'         = 'Russian (Russia)'
    'Custom Language Display Name' = '@%SystemRoot%\system32\Rulemak.dll,-1100'
    'Layout Product Code'          = '{' + [guid]::NewGuid().ToString().ToUpper() + '}'
}
foreach ($k in $values.Keys) {
    New-ItemProperty -Path $key -Name $k -Value $values[$k] -PropertyType String -Force | Out-Null
}
Write-Host "registered KLID $klid (Layout Id = $idHex)"

# --------------------------------------------------- user's input list -----
# HKCU, so this applies to the account running the script.
$tip = '0419:{0}' -f $klid.ToUpper()
try {
    $list = Get-WinUserLanguageList
    if (-not ($list | Where-Object LanguageTag -match '^ru')) {
        $list.Add('ru')
        Write-Host 'added Russian to the language list'
    }
    $ru = $list | Where-Object LanguageTag -match '^ru' | Select-Object -First 1
    if ($ru.InputMethodTips -notcontains $tip) {
        $ru.InputMethodTips.Add($tip)
        Set-WinUserLanguageList $list -Force
        Write-Host "added $tip to Russian input methods"
    } else {
        Write-Host "$tip already present"
    }
} catch {
    Write-Warning "could not update the user language list: $_"
    Write-Warning 'Add it manually: Settings > Time & language > Language & region > Russian > Language options > Add a keyboard'
}

Write-Host ''
Write-Host 'Installed. REBOOT (or sign out and back in) before the layout appears.' -ForegroundColor Yellow
