# Huananzhi X99-TF — Modded BIOS Pack v2.1.2 (GHX99015, 2020-05-25)

[🇷🇺 Русский](README.md) | **🇬🇧 English**

Ready-to-flash **v2.1.2** firmware pack (all 12 BIOS binaries are byte-for-byte identical to `v2.1` / `v2.1.1`; hardened flash/ReBAR scripts and updated documentation) for **HUANANZHI X99-TF** based on [Koshak1013](https://github.com/Koshak1013/HuananzhiX99_BIOS_mods) (`GHX99015`, 2020-05-25): Xeon E5 v3 Turbo Boost Unlock, **live undervolting and Ring/Uncore frequency lock directly in BIOS Setup with real `F10` NVRAM persistence**, 25 unlocked submenus, unlocked power limits, Resizable BAR, clean **2011 + 2023 Secure Boot free of `PKfail` + 443 `dbx` revocations**, TPM 2.0, working `Intel VT-x`, and fixed SmartFan V3 (with S3 sleep support).

Instead of the 4 hardcoded undervolt tiers from v1.1, this pack uses a clean **2 profiles × 3 boot modes = 6 builds** matrix — you can tune voltages, Ring lock, cores, C-States, and RAM timings live inside BIOS Setup, and Clear CMOS always rolls back safely to `Safe Stock`.

> [!TIP]
> **Download everything as one archive:** [Releases page](../../releases/latest) → `X99TF_GHX99015_BIOS_Pack_v2.1.2.zip`. Or grab individual files directly from the folders below.

> [!CAUTION]
> **For HUANANZHI X99-TF (`GHX99014` / `GHX99015`) ONLY.** Do not flash onto any other X99 motherboard (Machinist, Kllisre, Qiyida, Jingsha, other Huananzhi models, etc.): their Flash Descriptor, memory routing, Super I/O, GPIO, and PCIe lanes differ — high risk of bricking requiring an external SPI programmer.
>
> **Power limits are unlocked: `PL1 = 200 W`, `PL2 = 250 W`, `Tau = 56 s`.** On 10–18-core Xeons under sustained load this heats up the board VRM significantly. Ensure active VRM airflow or lower the limits directly in BIOS (see [BIOS Overclocking & Tuning Guide](#bios-overclocking--tuning-guide)).

---

## What's New in v2.0 / v2.1 / v2.1.1 / v2.1.2

> [!IMPORTANT]
> **Maintenance release v2.1.2 (all 12 BIOS `.bin` images are byte-for-byte identical to `v2.1` and `v2.1.1` — no reflashing needed from `v2.1`/`v2.1.1`):**
> * **`Enable_ReBAR_Windows.bat` (security):** eliminates command/quote injection from `set "_ARG1=%~1"` and raw `%*` forwarding; safely reads CLI arguments and forwards only strictly allowlisted `-Action Enable|Disable|Status` flags to PowerShell, exiting cleanly without `pause` on any CLI arguments.
> * **`Enable_ReBAR_Windows.ps1`:** immediately aborts (`exit 1`) on unexpected `ReBarState` UEFI variable read errors (any Win32 code other than `122`/`203`) without attempting NVRAM writes.
> * **`flash.bat`:** replaces `^`/`$` with `\A...\z` inside `call` SHA-256 verification regex, tightens SMBIOS board matching, and aligns post-flash instructions with the 10-second cold shutdown.
> * **Documentation (`README.md` + `README.en.md`):** corrects the `UFS` path (`IntelRCSetup → Advanced Power Management Configuration`), clarifies `MC0/MC1 PKGC CLK GATE DISABLE` (`value 1 = Disable in BIOS`) and `SATA/sSATA AHCI ALPM` + `LPM`, uses exact IFR menu/prompt titles (`CPU - Advanced PM Tuning`, `CPU VCCin Voltage Level`, `VccIo Voltage Control`, `VCCU Voltage Offset`), notes that `MokManager` applies to `shim`-based loaders, and splits the full English manual into [`README.en.md`](README.en.md).
>
> **Maintenance release v2.1.1 (all 12 BIOS `.bin` images are byte-for-byte identical to `v2.1`):**
> * **`Enable_ReBAR_Windows.ps1` / `.bat`:** enforces `ReBarDxe`'s exact 1-byte `DataSize = 1` contract (`>1 B` values flagged `[WARN]` as inactive), gates post-write BIOS hints to `-Action Enable`, documents the mandatory 2-reboot Legacy → UEFI transition, handles `FirmwareType = Unknown` and `EnablePrivilege()` failures cleanly, and adds `DisableDelayedExpansion` + CLI forwarding in `.bat`.
> * **`flash.bat`:** hardens `chcp.com 65001 <nul >nul`, trims double slashes (`Z:\\`) on drive roots, distinguishes SHA-256 `BAD`/`MISSING`/`ERR` failures, and removes inaccurate CSM recovery text on Secure Boot builds.
> * **`README.md`:** clarifies that `CsmDxe` unconditionally blocks CSM while Secure Boot is active, documents the 2-reboot Legacy → UEFI+ReBAR transition, lists all 10 pre-filled Micron timings, and adds platform NO-OP notes.
>
> **Critical v2.1 fixes (recommended upgrade from v2.0):**
> * Fixed `GUID_STD_DEFAULTS` (`4599D26F-...`) in the NVRAM GUID table: in `v2.0`, first boot of `02_Performance_OC` triggered a Bank Swap resetting 23 settings to `01_Safe_Stock` — **`02_Performance_OC` (`−50/−40 mV`, Ring lock, C-States OFF, IMC tweaks) now reliably applies on cold boot #1**!
> * Restored `MSR Lock Control = Enable` (`0x0075 = 1`): fixes **hardware `Intel VT-x`** (which was disabled in Task Manager on `v2.0`) and restores `MSR 0xE2` CFG Lock.
> * `flash.bat` uses short relative paths for Intel FPT — eliminates `Error 200` on paths >127 chars or folders containing spaces/non-ASCII characters.

| Area | What Was Built and Live-Verified on Hardware |
| :--- | :--- |
| **Real `F10` NVRAM persistence** | Fixed critical `NvramDxe` / `NvramSmm` bug (`0x70 → 0x72`, 114-byte `Setup` size check). Previously every reboot triggered `ResetToDefaults + BankSwap`, wiping BIOS edits. All Setup changes now persist permanently. |
| **Live undervolt & Ring lock (`NalexOverclock V4.2`)** | Replaces baked `ser8989_S3TurboHack` with patched `NalexOverclock` (DXE + PEI): Turbo Boost Unlock + live Core/CLR/SA offsets and **hardware Ring/Uncore lock (`MSR 0x620` written strictly after `MSR 0x150`, plus S3 BootScript persistence)** with zero drops to 1200 MHz even after S3 wake. On Xeon v3, `CLR Max OC Ratio = 30` auto-clamps to each CPU's fused max; safely skipped on Xeon v4. |
| **Clean Secure Boot without `PKfail` (CVE-2024-8105) + 2026 `dbx`** | Compromised `DO NOT TRUST - AMI Test PK` completely purged from `PK`, `PKDefault`, and `dbtDefault`. Replaced with a clean 2048-bit RSA **`HUANANZHI X99-TF Community Platform Key`** (`2026–2056`, **ephemeral private key shredded immediately after signing**), current Microsoft **2011 + 2023** CAs (`KEK`/`db`), official March 2026 Microsoft **`dbx` (443 SHA-256 revocations)**, and native 43-byte AMI ExtHeaders. |
| **SmartFan V3 + S3 Fix (`F217C2E9`)** | Eliminates the hidden **100% fan speed at 70°C** bug: patch `F217C2E9` writes `T5` (`78°C`) to `CRITICAL_TEMP` (`0x35`) instead of `0x3A` and preserves the fan curve (`60→20%`, `66→40%`, `72→60%`, `75→80%`, `78→100%`) across S3 sleep. |
| **25 unlocked menus & platform fixes** | `Power Technology = Custom` enabled by default (un-grays `CPU P/C/T State` and `C1E`, removes `PwrMgtCustConfig` reset trap); `Pkg Clmp Lim1/2 = Between P1/P0` (no 1200 MHz RAPL drops); fixed `_FIT_` microcode pointers (`306F1`/`406F1 rev B000040`/`406F0`, no `306F2`); C612 `PCH Thermal` sensor enabled; `Timeout = 3s`; `XHCI Idle L1 = Disabled`; `PCIe Relaxed Ordering / Extended Tag = Enabled`; `DMI/PCIe ASPM = Disabled`; `ACPI T-States = Disabled`. |
| **Guaranteed Clear CMOS rollback** | In **both** branches (`01_Safe_Stock` and `02_Performance_OC`), factory `StdDefaults` are 100% identical to ultra-stable `01_Safe_Stock` (`0/0 mV`, dynamic Ring, C-States ON, RAM Auto, all cores). Any unstable OC recovers via the `JCMOS` jumper without a programmer. |

---

## Choosing a Build

Folder layout: **`<profile>/<mode>/`**, each containing two binaries:
* `*_8MB_FPT.bin` — for flashing from Windows via `flash.bat`;
* `*_16MB_CH341A.bin` — full SPI image for external programmers (clean stock Flash Descriptor + Intel ME `9.1.37.1002` + BIOS).

### 1. Starting Profile

| Folder | Active Right After Flashing | Best For |
| :--- | :--- | :--- |
| **`01_Safe_Stock`** | Turbo Boost Unlock, `0 / 0 mV`, dynamic Ring (`CLR = 0`), **`C1E / C2 / C3 = ON, C6 = OFF`**, IMC and RAM on `Auto`, all cores enabled | Maximum out-of-the-box stability, **best choice for Xeon E5 v4** or tuning everything manually from scratch |
| **`02_Performance_OC`** | Turbo Boost Unlock, universal safe undervolt **`−50 mV Core / −40 mV Ring`**, **auto-clamped max Ring lock** (`CLR = 30` on v3), C-States OFF (`C0/C1`, `C1E/C3/C6` disabled), safe IMC tuning (`Early Snoop`, `Open Page`, `Turnaround Opt`, `CKE/OppSR/MDLL Off/Set Throttling Mode/Scrub/SATA+sSATA AHCI ALPM/LPM` off, `MC0/MC1 PKGC CLK GATE DISABLE`), **RAM & `tREFI` on `Auto`**, all cores enabled | **Recommended for most Xeon E5 v3 CPUs.** Immediate responsiveness and lower latency on any DDR4 kit; Clear CMOS always reverts to `Safe Stock` |

> [!NOTE]
> Both profiles share **byte-for-byte identical** BIOS code (`FV0` / `FV1` / `StdDefaults`). You can change undervolt, Ring lock, cores, C-States, or RAM timings anytime inside BIOS Setup without reflashing.

### 2. Boot Mode

| Subfolder | Boot Mode | Above 4G / ReBAR | Secure Boot (2011+2023) | TPM 2.0 | Use Case |
| :--- | :---: | :---: | :---: | :---: | :--- |
| `1_Legacy` | CSM ON | OFF | OFF | OFF | MBR Windows installs, older GPUs without UEFI GOP |
| `2_UEFI_SB` | Pure UEFI | ON | ON | OFF | GPT Windows 10/11 without a TPM module |
| `3_UEFI_SB_TPM` | Pure UEFI | ON | ON | ON | Windows 11 with hardware TPM 2.0, anti-cheats (Vanguard, FACEIT) |

> [!IMPORTANT]
> Secure Boot and TPM menus are **hidden** in this BIOS — pick the desired mode when flashing.

---

## How to Flash

### From Windows — `flash.bat` (Recommended)
1. Run **`flash.bat`** as Administrator, choose your profile (`1–2`) and boot mode (`1–3`).
2. The script creates a backup first: tries a full 16 MB dump, or falls back to the 8 MB BIOS region (`backup_*.bin` next to the script).
3. **Copy the backup to cloud storage / USB drive / another PC**, then type `YES`.
4. The script flashes **only the 8 MB BIOS region** (leaving your board's Flash Descriptor and Intel ME untouched) and runs full verification.
5. Perform a **complete power-off for 10 seconds → power-on** (cold boot). First memory training takes ~15–30 seconds.

### External CH341A Programmer
Flash `*_16MB_CH341A.bin` to the entire SPI chip (`W25Q128` / `MX25L128`) after dumping and backing up your original 16 MB chip contents. **Never flash a 16 MB file from Windows.**

---

## Post-Flash Steps

### 1. Xeon E5 v3 Turbo Boost Unlock (Disable Windows Microcode Loader)
If left in place, Windows loads microcode `306F2` and disables Turbo Boost Unlock. Run as Administrator:

**PowerShell (Administrator):**
```powershell
takeown /f "C:\Windows\System32\mcupdate_GenuineIntel.dll"
icacls "C:\Windows\System32\mcupdate_GenuineIntel.dll" /grant "*S-1-5-32-544:F"
Rename-Item "C:\Windows\System32\mcupdate_GenuineIntel.dll" "mcupdate_GenuineIntel.dll.bak"
```

**Or `cmd` (Administrator):**
```bat
takeown /f C:\Windows\System32\mcupdate_GenuineIntel.dll
icacls C:\Windows\System32\mcupdate_GenuineIntel.dll /grant *S-1-5-32-544:F
ren C:\Windows\System32\mcupdate_GenuineIntel.dll mcupdate_GenuineIntel.dll.bak
```

Reboot. Major Windows feature updates may restore this file — repeat if needed. On Linux, do not load `intel-ucode` (or add `dis_ucode_ldr` to kernel parameters).
* **Verify unlock:** open **HWiNFO64** or **CPU-Z** (*Bench → Stress CPU*) — all-core load clocks should reach full all-core Turbo Boost (up to `PL1`/`PL2`), and on `02_Performance_OC` `Memory → LLC/Ring` should stay locked at max Ring frequency without dipping to `1200 MHz`.
* **Note on WSL2 / anti-cheats with microcode `0x00`:** `VT-x`, `VT-d`, and `DMAR` are enabled in BIOS. When running microcode `0x00`, keep Windows Memory Integrity (VBS / HVCI) off; if you need both FACEIT/Vanguard and WSL2/Docker, create two boot entries via `bcdedit` (`hypervisorlaunchtype off` / `auto`).

### 2. Converting MBR to GPT (For UEFI Modes)
`2_UEFI_SB` and `3_UEFI_SB_TPM` cannot boot an MBR disk. Check your OS disk number `N` and partition style (`MBR` or `GPT`) in PowerShell:
```powershell
Get-Partition -DriveLetter C | Get-Disk
```
Back up important data and convert from an elevated `cmd` / PowerShell (replace `0` with your disk number):
```bat
mbr2gpt /validate /disk:0 /allowFullOS
mbr2gpt /convert /disk:0 /allowFullOS
```
If you prefer not to convert, flash `1_Legacy`.

### 3. Resizable BAR (ReBAR)
`2_UEFI_SB` and `3_UEFI_SB_TPM` ship with ReBAR enabled (`ReBarState = 0x20`). On GPUs without ReBAR support (GTX 10/16, RTX 20), `ReBarDxe` safely skips the card. If you flashed `1_Legacy` and later migrated to GPT/UEFI, follow this **mandatory 2-reboot BIOS sequence** (disabling `CSM Support` hides `Video`):
1. In BIOS go to `Advanced → CSM Configuration → Video = UEFI` → press `F10` and **reboot**.
2. Re-enter BIOS: set `Advanced → CSM Configuration → CSM Support = Disabled` and `Advanced → PCI Subsystem Settings → Above 4G Decoding = Enabled` → press `F10` and boot UEFI Windows.
3. Run **`Enable_ReBAR_Windows.bat`** as Administrator and reboot (CLI arguments are also supported, e.g., `Enable_ReBAR_Windows.bat -Action Status`).
* **Verify:** **GPU-Z** → `Resizable BAR: Enabled` (or *NVIDIA Control Panel → System Information → Resizable BAR: Yes*).

### 4. Verify Secure Boot (2011 + 2023, Zero `PKfail`, 443 `dbx` Revocations)
Run in PowerShell **as Administrator** (on `2_UEFI_SB` and `3_UEFI_SB_TPM`):
```powershell
Confirm-SecureBootUEFI
$pk  = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI -Name PK).Bytes)
$kek = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI -Name KEK).Bytes)
$db  = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI -Name db).Bytes)
[PSCustomObject]@{
  Community_PK   = ($pk -match 'HUANANZHI X99-TF Community Platform Key')
  AMI_Test_PK    = ($pk -match 'DO NOT TRUST|AMI Test PK')   # must be False!
  KEK_2023       = ($kek -match 'KEK 2K CA 2023')
  Win_UEFI_2023  = ($db -match 'Windows UEFI CA 2023')
  MS_UEFI_2023   = ($db -match 'Microsoft UEFI CA 2023')
  OptROM_2023    = ($db -match 'Option ROM UEFI CA 2023')
  DBX_Bytes      = (Get-SecureBootUEFI -Name dbx).Bytes.Length  # 21292 (443 SHA-256)
}
```
Expected result: `Confirm-SecureBootUEFI = True`, `AMI_Test_PK = False`, all `*_2023 = True`, `Community_PK = True`, `DBX_Bytes = 21292`.

---

## BIOS Overclocking & Tuning Guide

In **v2.1+**, all key menus are unlocked, `Power Technology = Custom` is safely active by default, and edits persist via `F10`. Press **`Del`** at startup (`Timeout = 3s`).

### Key Performance Settings Map

| Setting | BIOS Menu Path | Safe Tuning / Recommendation |
| :--- | :--- | :--- |
| **CPU Core Undervolt** *(v3)* | `IntelRCSetup → OverClocking Feature → Processor` | `Offset Prefix = -`, start at `Core Voltage Offset = 50` (`−50 mV`). Good silicon reaches `60–75 mV` (step by `5–10 mV` + test in OCCT/Prime95/games). Reduces VRM heat and sustains higher Turbo clocks. |
| **Ring / Uncore Lock & Undervolt** *(v3)* | `IntelRCSetup → OverClocking Feature → CLR/Ring` | **`CLR Max OC Ratio`**: `30` = hardware Ring lock to your CPU's fused max (pre-set in `02_Performance_OC`; auto-clamps per CPU model, e.g., `27x` on 2678 v3, `30x` on 2696 v3), `0` = dynamic `12x..Max`. **`Offset Prefix = -`**, **`CLR Voltage Offset = 40`** (`−40 mV`; good samples hold `−45..−55 mV`). Dramatically cuts L3/RAM latency! |
| **Core Count Limit** *(optional)* | `IntelRCSetup → Processor Configuration → Per-Socket Configuration → CPU Socket 0 Configuration → Cores Enabled` | `0` = all cores. On 14–18-core Xeons for gaming, setting `10–12` cores lowers CPU/VRM heat and sustains higher Turbo Boost clocks (all-core render throughput scales down proportionally). |
| **Power Limits PL1 / PL2 / Tau** | `IntelRCSetup → Advanced Power Management Configuration → SOCKET RAPL Config` | Default `200 W / 250 W / 56 s`, `Pkg Clmp Lim1/2 = Between P1/P0`. If VRM runs hot, lower `Long Dur Pwr Limit` (`PL1`) to `130–160 W`. `Turbo Pwr Limit Lock = Disable` (adjustable in Windows via ThrottleStop). |
| **C-States / Wakeup Latency** | `IntelRCSetup → Advanced Power Management Configuration → CPU C State Control` | For lowest latency and undervolt stability: `Package C State limit = C0/C1`, `C3 = Disable`, `C6 = Disable`, **`Enhanced Halt State (C1E) = Disable`** (pre-set in `02_Performance_OC`). `Package C State limit` options: `C0/C1`, `C2`, `C6(non Retention)`, `C6(Retention)` (no `Auto`; `01_Safe_Stock` uses `C2`, `C1E/C3 = Enable`, `C6 = Disable`). |
| **Snoop Mode (L3 / IMC)** | `IntelRCSetup → QPI Configuration → QPI General Configuration` | `COD Enable = Disable`, **`Early Snoop = Enable`** (cuts memory latency on multi-core single-socket Xeons; pre-set in `02_Performance_OC`). |
| **RAM Frequency, Timings & `tREFI`** | `IntelRCSetup → Memory Configuration → Memory Frequency` and `Memory Timings & Voltage Override` | Haswell-EP (Xeon E5 v3) DDR4 hardware cap is **2133 MHz** (`2133` or `Auto`; Xeon E5 v4 supports up to **2400 MHz**). Set `DIMM profile = MANUAL` to unlock timings, `Command Timing` (`1N`/`2N`), `Memory Voltage` *(NO-OP on X99-TF, see below)*, and **`Refresh Rate`** (`tREFI`). Raising `Refresh Rate` to **`32760`** (with decent airflow) noticeably cuts RAM latency. **Caution:** `MANUAL` pre-fills all 10 tight **Micron** timings (`tCL=12, tRP=12, tRCD=12, tRAS=28, tWR=12, tRFC=200, tRRD=4, tRTP=6, tFAW=16, tCWL=11`) — on Hynix / regular DDR4 kits, reset unwanted fields to `0` (`Auto`) or loosen them before pressing `F10`, and validate with TestMem5! |
| **Memory Controller (IMC) Tuning** | `IntelRCSetup → Memory Configuration` | `Page Policy → Page Policy = Open`; `Memory Training → Turnaround Time Optimization = Enable`; `Memory Thermal` → **`Set Throttling Mode = Disabled`**, **`MDLL Off = Disabled`**, `Memory Power Savings Mode = User Defined` → **`Memory Power Savings Advanced Options`** (`CKE Throttling = Off`, `Opportunistic SR = Disabled`); `Memory RAS Configuration` → `Patrol/Demand Scrub = Disable`. `02_Performance_OC` also disables **`SATA/sSATA AHCI ALPM`** and **`LPM`**, and sets **`MC0/MC1 PKGC CLK GATE DISABLE`** (`value 1 = Disable in BIOS`, path `CPU - Advanced PM Tuning → Program CSR_SAPMCTL`). |
| **PCIe / Above 4G** | `Advanced → PCI Subsystem Settings` | `Above 4G Decoding` (`Enabled` for UEFI/ReBAR), `PCI Express Settings`: `Relaxed Ordering = Enabled`, `Extended Tag = Enabled`. |
| **Thermal Protection (PROCHOT#)** | `IntelRCSetup → Advanced Power Management Configuration → CPU Thermal Management` | Keep `Bi-directional PROCHOT# = Bidirectional (normal input response)` (protects VRM). |
| **CPU Fan Curve** | `Advanced → Hardware Monitor` | Points `T1–T5`, `PWM1–PWM4`. In v2.1+, `T5` (`78°C`) properly sets the 100% threshold and survives S3 sleep. |

> [!TIP]
> **Step-by-step tuning workflow after flashing `02_Performance_OC`:**
> 1. Boot and verify baseline `−50 / −40 mV` + Ring lock stability (10–15 min OCCT / gaming).
> 2. Optionally push undervolt slightly deeper (e.g., `−60 / −45 mV` or `−65 / −45 mV`) — if you hit a BSOD or WHEA-19, back off by `5–10 mV`.
> 3. Tune RAM: optionally set `Memory Frequency = 2133`, then switch `DIMM profile = MANUAL` — **immediately review all 10 pre-filled tight Micron timings (`tCL=12, tRP=12, tRCD=12, tRAS=28, tWR=12, tRFC=200, tRRD=4, tRTP=6, tFAW=16, tCWL=11`) and on Hynix / regular DDR4 reset unwanted entries to `0` (`Auto`) or loosen them (e.g., `14-14-14-32`, `tRFC=260`) BEFORE saving `F10`!** Inside `MANUAL`, set **`Refresh Rate`** (`tREFI`) = `32760`, tune timings, and verify with **TestMem5 (Anta777)**.
> 4. If the PC fails to POST after aggressive timings/voltages — **don't panic**: unplug power and short `JCMOS` for 10 seconds to cleanly revert to `01_Safe_Stock`!

> [!WARNING]
> **Settings NOT recommended to change blindly:**
> * **`UFS`** (`IntelRCSetup → Advanced Power Management Configuration`, options: `0 = Enabled`, `1 = Disabled`) — keep **`Enabled`** (`0`). Disabling it on Haswell-EP breaks `MSR 0x620` and drops memory bandwidth significantly.
> * **`Energy Efficient Turbo`** (`CPU - Advanced PM Tuning → Program PowerCTL_MSR`, `Enable [0]`) and **`Energy Performance BIAS setting.`** (`CPU - Advanced PM Tuning → Energy Perf BIAS`, `Balanced Performance [7]`; grayed out while `Energy Performance Tuning = Enable [0]` because the OS controls EPB via `MSR 0x1B0`) — optimal for preventing 1200 MHz clock stalls.
> * **`Fast Boot = Disabled`** — ensures reliable USB/PCIe/ReBAR initialization.
> * **`Current Config = Disable`** (`0`, path `CPU - Advanced PM Tuning → Program PP0_CURT_CFG_CTRL_MSR`) — do not throttle stock CPU current limits.
> * **`MSR Lock Control`** (`Processor Configuration`) — keep **`Enable`** (`1`), otherwise hardware virtualization `Intel VT-x` (`MSR 0x3A`) stops working.
> * **`Power Technology`** — broken in v1.1; **fully fixed in v2.0+**, set to `Custom` by default.

> [!NOTE]
> **Known platform / firmware quirks:**
> * **`CLR Min Ratio`** (`IntelSetup[0x17A7]`) is ignored when `CLR Max OC Ratio > 0`: `NalexOverclock` locks Ring as `MIN = MAX` via `MSR 0x620`.
> * **`Energy efficient P-state`**, **`CPU VCCin Voltage Level`**, **`VccIo Voltage Control`**, **`VCCU Voltage Offset`**, and **`AVX2 Negative Offset`** are firmware NO-OPs on this board (zero binary consumers).
> * **`Memory Voltage`** requires an SVID-capable DRAM VR — on HUANANZHI X99-TF, DDR4 voltage is hardware-fixed at `1.20 V` and cannot be changed from BIOS.
> * **`ReBarDxe`** configures PCIe BARs on cold boot and relies on the OS GPU driver to restore ReBAR after S3 sleep.

### Live Hardware Benchmark Reference (v2.1 / V4.4)
Test rig: **Xeon E5-2696 v3 (`12C/24T`, `−65 / −45 mV`, Ring `3000 MHz` lock)** + **4×8 GB ECC DDR4-2133 (`12-12-12-28-200-1T`, `tREFI=32760`)** + **RTX 5070 Ti (16 GB ReBAR)**:
* **AIDA64 Cache & Memory:** `Read 65,977 MB/s` | `Write 47,503 MB/s` | `Copy 57,373 MB/s` | `Memory Latency 75.9 ns` | `L3 Latency 27.1 ns` | `North Bridge / Ring 3000.0 MHz` (zero drops).
* **256 MB pointer-chase RAM latency:** reduced from `110.4 ns` (stock) to **`95.2 ns` (`−15.2 ns`)**.

**Not exposed in BIOS menus** (chosen at flash time or from Windows): Secure Boot, TPM 2.0, ReBAR (`Enable_ReBAR_Windows.bat`), `CFAN1` header control.

---

## TPM 2.0 Module

* Verified module: **TPM-LPC-X2, 10-pin (Infineon SLB9665)** — works with `3_UEFI_SB_TPM` builds.
* Motherboard header is labeled **`JLPC1`** or **`DEBUG1`** depending on PCB revision (same 10-pin LPC header).
* **Always install/remove with power completely disconnected** (shutdown, PSU switch `0`, hold power button a few seconds).
* **Verify the missing key pin and Pin 1 alignment** — never force the module.
* **Verify in Windows:** `Win + R` → `tpm.msc` (*"The TPM is ready for use"*, spec `2.0`, `IFX`), or in elevated PowerShell:
  ```powershell
  Get-Tpm | Select-Object TpmPresent, TpmReady, TpmEnabled, TpmActivated, TpmOwned
  Confirm-SecureBootUEFI
  ```

---

## Troubleshooting

| Issue | Cause | Fix |
| :--- | :--- | :--- |
| After `2_UEFI_SB`/`3_UEFI_SB_TPM`, BIOS doesn't see the boot drive | Windows is installed on MBR (`CsmDxe` **unconditionally blocks CSM** while Secure Boot is active, and there is no Secure Boot menu toggle) | Boot a Windows / WinPE USB in UEFI mode and run `mbr2gpt /convert /disk:N` to convert to GPT — or flash **`1_Legacy`** (from UEFI WinPE / another UEFI disk or CH341A programmer) |
| Black screen after manual BIOS undervolt / RAM timing edits | Unstable CPU or RAM overclock | Unplug power and short `JCMOS` (or pull CMOS battery for 1–2 min) — BIOS cleanly resets to `01_Safe_Stock` (`0/0 mV`, RAM `Auto`) while preserving your UEFI/SB/TPM boot mode! |
| BSODs / freezes on `02_Performance_OC` (Xeon E5 v3) | CPU silicon cannot hold `−50 / −40 mV` or max Ring lock | Enter `IntelRCSetup → OverClocking Feature` and relax offsets (e.g., `−30 / −20 mV` or `0 / 0`) or set `CLR Max OC Ratio = 0` → `F10`. No reflashing required! |
| Black screen on an older GPU in UEFI mode | GPU lacks UEFI GOP (`CsmDxe` unconditionally blocks CSM under Secure Boot, so CSM cannot be toggled in `2_UEFI_SB`/`3_UEFI_SB_TPM`) | Flash **`1_Legacy`** (temporarily using a GOP-capable GPU from Windows, or via CH341A programmer) |
| Bootable USB (Ventoy, Linux, WinPE) shows `Security Violation` | Third-party `.efi` is not signed by Microsoft keys | For `shim`-based loaders (e.g., Ventoy with Secure Boot Support or Linux), choose `Enroll hash from disk` / `Enroll key from disk` in `MokManager`; for unsigned standalone `.efi` tools without `shim`, use `1_Legacy` |

---

## Checksums & Secure Boot Key Transparency

* SHA-256 checksums for all **12 images** are in [`SHA256SUMS.txt`](SHA256SUMS.txt). Verify in PowerShell:
  ```powershell
  Get-FileHash .\02_Performance_OC\3_UEFI_SB_TPM\*.bin -Algorithm SHA256
  ```
* Public certificate fingerprint for **`HUANANZHI X99-TF Community Platform Key`** (`PK`, `2026–2056`):
  * SHA-256 (DER): `6b61f6bcc8a80e71098442fab01c1ec598ccc45393ab64eb0a7637363f7b8522`
  * The private key was generated ephemerally during release build and **permanently zero-overwritten and shredded** immediately after signing `PKDefault` — it is not stored in this repository or by the author (complete protection against `PKfail`).

---

## License

Built by **pavelcanton**. Scripts and documentation are **MIT**-licensed (see [`LICENSE`](LICENSE)). Firmware modules, Intel ME, microcodes, and Intel FPT (`tools/`) belong to their respective copyright holders. Provided as is; flash at your own risk.
