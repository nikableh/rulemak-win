# Rulemak: Russian Colemak layout for Windows

A Russian (ЙЦУКЕН → Colemak) keyboard layout for Windows 10/11, distributed as a
prebuilt keyboard layout DLL plus the source to rebuild it.

**TL;DR:** if you build a custom layout with Microsoft Keyboard
Layout Creator 1.4 on Windows 11, selecting it crashes `explorer.exe`. MSKLC's
bundled 2007 compiler is the problem, not your layout. This repo recompiles the
same layout with a modern toolchain, which works.

---

## Install

Download or clone, then from an **elevated** PowerShell:

```powershell
Start-Process powershell -Verb RunAs -ArgumentList '-ExecutionPolicy','Bypass','-File','.\install\install.ps1'
```

Then **reboot** (or sign out and back in). `win32k` caches layout DLLs, so the
layout will not appear in the switcher until you do.

The layout then shows up as **Rulemak** under Russian, switchable
with `Win`+`Space`.

To remove it:

```powershell
Start-Process powershell -Verb RunAs -ArgumentList '-ExecutionPolicy','Bypass','-File','.\install\uninstall.ps1'
```

### What the installer does

- copies `binaries\amd64\Rulemak.dll` → `C:\Windows\System32\`
- copies `binaries\x86\Rulemak.dll` → `C:\Windows\SysWOW64\` (for 32-bit apps)
- registers it under `HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\a0000419`
- adds `0419:A0000419` to the current user's Russian input methods

It picks a free `Layout Id` and steps to `a0010419`, `a0020419`, … if another
custom Russian layout already occupies the slot, so it will not clobber one.

---

## The layout

Cyrillic letters arranged on a Colemak base. Shift states used: normal, Shift,
Ctrl, Ctrl+Alt (AltGr), Shift+Ctrl+Alt.

| Key | AltGr |
|---|---|
| `[` (OEM_4) | « |
| `]` (OEM_6) | » |
| `'` (OEM_7) | ъ / Ъ |

`ъ` is also on `OEM_102` (the extra key on 102-key boards) for keyboards that
have it. `OEM_7` carries `Cap=5` (`CAPLOK|CAPLOKALTGR`) so Caps Lock also
applies to its AltGr column.

Edit `source/rulemak.klc` to change any of this. It is a normal MSKLC file.

---

## Rebuilding

Prebuilt DLLs are committed, so you only need this if you change the layout.

**Requirements:** Visual Studio with the C++ workload (any recent version).
MSKLC is needed *only* to regenerate C source after editing the `.klc`, and its
compiler is never used.

```bat
build\gen-source.bat    :: only if you edited rulemak.klc  (needs MSKLC)
build\build.bat         :: x64  -> binaries\amd64\Rulemak.dll
build\build32.bat       :: x86  -> binaries\x86\Rulemak.dll
```

Then re-run `install\install.ps1` and reboot.

`gen-source.bat` invokes `kbdutool -u -s`, which translates `.klc` into
`Rulemak.C/.H/.DEF/.RC`. Those generated files are committed, so building this
repo does not require MSKLC at all. Warning `1015` ("character defined on both
X and Y") from `kbdutool` is benign: it means two keys emit the same character.

### Why the link flags matter

This is the part that took the longest to work out. A **default** MSVC link produces a DLL that
Windows silently refuses as a keyboard layout: it loads fine in user mode, shows
up in Settings under "Installed keyboards", and never appears in the `Win`+`Space`
switcher. No error, anywhere.

The DLL must be structurally equivalent to a layout Windows already accepts:

```
/NOENTRY /NODEFAULTLIB     no DllMain, no CRT - the DLL is pure data + one export
/SUBSYSTEM:NATIVE          layout DLLs are mapped by win32k, not a user subsystem
/DYNAMICBASE:NO            no ASLR
/NXCOMPAT:NO
/HIGHENTROPYVA:NO          x64 only; otherwise DllCharacteristics = 0x0020
/SAFESEH:NO                x86 only
/MERGE:.text=.data         collapse to 3 sections
/MERGE:.rdata=.data
/SECTION:.data,RE          .data must be READ+EXECUTE, never writable
```

Target PE shape, matching a known-good layout DLL:

```
DllCharacteristics = 0x0000
sections           = .data(0x60000020)  .rsrc(0x42000040)  .reloc(0x42000040)
exports            = KbdLayerDescriptor @1   (and nothing else)
```

A default build instead yields five sections with `.data` = `0xc0000040`
(READ+**WRITE**). A writable data section is the one difference with a clear
mechanism: `win32k` maps layout DLLs into session space and will not accept a
writable shared data section.

**Honest caveat:** the working configuration was found by eliminating *all*
structural differences at once against a DLL known to work. Which flag was
decisive was never isolated. Read-only `.data` alone was tested and verified
**insufficient**, so at least one of the DYNAMICBASE / NXCOMPAT / HIGHENTROPYVA /
section-merge changes also matters. If you are minimising this list, test each
change on its own, and expect a reboot per test.

### Verifying a build before installing

Load the DLL, call `KbdLayerDescriptor`, and compare against
`C:\Windows\System32\KBDRU.DLL`. A good build reports:

- `bMaxVSCtoVK = 127`
- non-null `pCharModifiers`, `pVkToWcharTable`, `pKeyNames`, `pusVSCtoVK`
- `dwType` / `dwSubType` = `0`
- `fLocaleFlags = 0x10001` (the `0x1` is `KLLF_ALTGR`; `0x10000` means no AltGr)

MSKLC-built DLLs return **garbage** for `dwType`/`dwSubType`, because MSKLC's
bundled 2007 `kbd.h` has a shorter `KBDTABLES` struct and those reads fall off
the end of it.

---

## Background: why MSKLC's own output crashes

Symptom on Windows 11: the layout installs, appears in the switcher, and
selecting it kills Explorer.

```
Faulting application: Explorer.EXE
Faulting module:      InputSwitch.dll        <- the Win11 input-switcher flyout
Exception code:       0xc0000409             <- STACK_BUFFER_OVERRUN fail-fast
```

This is a known Windows 11 regression with MSKLC layouts; Microsoft has not
published a root cause. Related reports:

- [Custom Keyboard Layouts in Windows 11 No Longer Works](https://learn.microsoft.com/en-us/answers/questions/5490707/custom-keyboard-layouts-in-windows-11-no-longer-wo)
- [Created Keyboard Layout makes Windows critically bugging](https://learn.microsoft.com/en-us/answers/questions/5638493/created-keyboard-layout-makes-windows-critically-b)

### What was ruled out

Before blaming the toolchain, each of these was changed in isolation, rebuilt,
installed, and tested. **All of them still crashed**, so none is the cause:

| Hypothesis | Test | Result |
|---|---|---|
| Locale `0419` vs `0409` | rebuilt as `en-US` | crashed |
| `Cap=5` (`CAPLOK\|CAPLOKALTGR`) | changed to `Cap=1` | crashed |
| AltGr shift states 6/7 | removed entirely | crashed |
| Cyrillic character content | all chars replaced with ASCII | crashed |
| Scancode coverage / ordering | compared against a working layout | identical |
| `.klc` metadata / registry values | minimal vs full registration | no effect |

The decisive test was compiling a **known-working layout's own `.klc`** with the
local MSKLC. It crashed too, while that layout's author-supplied prebuilt DLL
worked fine on the same machine. Same input, different compiler, different
outcome. That is what pointed at the toolchain rather than the layout.

If you are debugging a custom layout that crashes, run that control **first**:
build someone else's known-good `.klc` with your MSKLC. It takes one cycle and
tells you immediately whether your file is even implicated.

### Two red herrings, recorded so you don't chase them

- **PE security flags.** The MSKLC DLL has `DllCharacteristics = 0x0000` (no
  ASLR, no NX) and looks obviously deficient next to a modern build. This is
  *not* the cause: a known-working layout DLL has `0x0000` too.
- **`.klc` language tags.** A file can have `LOCALEID "00000419"` while its
  `DESCRIPTIONS`/`LANGUAGENAMES` sections are tagged `0409`. That inconsistency
  is real and worth fixing (this repo's `.klc` has it fixed), but it does not
  cause the crash.

---

## Layout of this repo

```
binaries/amd64/Rulemak.dll   prebuilt x64 layout DLL  -> System32
binaries/x86/Rulemak.dll     prebuilt x86 layout DLL  -> SysWOW64
source/rulemak.klc           the layout definition - edit this
source/Rulemak.C/.H/.DEF/.RC generated by kbdutool; committed so MSKLC isn't needed
build/gen-source.bat         .klc -> C source (needs MSKLC)
build/build.bat              build x64
build/build32.bat            build x86
install/install.ps1          install + register + add to input methods
install/uninstall.ps1        full removal
```

## Credits

The "recompile it yourself" approach and a known-good reference binary came from
[urob/colemak-win](https://github.com/urob/colemak-win). That binary is what I
used as a control during debugging.

## License

[MIT](LICENSE) © 2026 Nika Krasnova
