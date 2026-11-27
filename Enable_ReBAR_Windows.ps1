#Requires -RunAsAdministrator
param(
    [ValidateSet("Enable", "Disable", "Status")]
    [string]$Action = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not ('UefiVarReBar' -as [type])) {
    $code = @"
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;

public class UefiVarReBar {
    private const string ReBarGuid = "{a3c5b77a-c88f-4a93-bf1c-4a92a32c65ce}";

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool GetFirmwareType(out uint FirmwareType);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CloseHandle(IntPtr hObject);

    [DllImport("advapi32.dll", SetLastError=true)]
    public static extern bool OpenProcessToken(IntPtr ProcessHandle, uint DesiredAccess, out IntPtr TokenHandle);

    [DllImport("advapi32.dll", SetLastError=true, CharSet=CharSet.Auto)]
    public static extern bool LookupPrivilegeValue(string lpSystemName, string lpName, out long lpLuid);

    [StructLayout(LayoutKind.Sequential, Pack=4)]
    public struct TOKEN_PRIVILEGES { public int PrivilegeCount; public long Luid; public int Attributes; }

    [DllImport("advapi32.dll", SetLastError=true)]
    public static extern bool AdjustTokenPrivileges(IntPtr TokenHandle, bool DisableAllPrivileges, ref TOKEN_PRIVILEGES NewState, int BufferLength, IntPtr PreviousState, IntPtr ReturnLength);

    [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    public static extern bool SetFirmwareEnvironmentVariable(string lpName, string lpGuid, byte[] pValue, uint nSize);

    [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    public static extern uint GetFirmwareEnvironmentVariable(string lpName, string lpGuid, byte[] pBuffer, uint nSize);

    public static void EnablePrivilege() {
        IntPtr hToken;
        if (!OpenProcessToken(Process.GetCurrentProcess().Handle, 0x28, out hToken)) {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }
        try {
            TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES { PrivilegeCount = 1, Attributes = 2 };
            if (!LookupPrivilegeValue(null, "SeSystemEnvironmentPrivilege", out tp.Luid)) {
                throw new Win32Exception(Marshal.GetLastWin32Error());
            }
            bool ok = AdjustTokenPrivileges(hToken, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
            int err = Marshal.GetLastWin32Error();
            if (!ok || err != 0) {
                throw new Win32Exception(err != 0 ? err : 1300);
            }
        } finally {
            CloseHandle(hToken);
        }
    }

    public static uint ReadReBar(out byte val, out int lastErr) {
        byte[] buf = new byte[64];
        uint len = GetFirmwareEnvironmentVariable("ReBarState", ReBarGuid, buf, (uint)buf.Length);
        lastErr = Marshal.GetLastWin32Error();
        if (len > 0) {
            val = buf[0];
            lastErr = 0;
        } else {
            val = 0;
        }
        return len;
    }

    public static bool WriteReBar(byte val, out int lastErr) {
        byte[] buf = new byte[] { val };
        bool ok = SetFirmwareEnvironmentVariable("ReBarState", ReBarGuid, buf, 1);
        lastErr = Marshal.GetLastWin32Error();
        if (ok) {
            lastErr = 0;
        }
        return ok;
    }
}
"@
    Add-Type -TypeDefinition $code
}

function Format-ReBarStatus([byte]$Value) {
    if ($Value -eq 0) {
        return "Disabled"
    }
    if ($Value -lt 0x20) {
        $capMb = ([uint64]1) -shl [int]$Value
        $capStr = if ($capMb -ge 1024) {
            "{0:0.##} GB" -f ($capMb / 1024.0)
        } else {
            "$capMb MB"
        }
        return "Enabled (capped at 2^$Value MB = $capStr)"
    }
    return "Enabled / Unlimited"
}

# Verify UEFI boot mode accurately on Windows 10/11 (kernel32!GetFirmwareType + $env:firmware_type + SecureBoot\State fallback)
$fwMode = "Unknown"
try {
    [uint32]$fwNum = 0
    if ([UefiVarReBar]::GetFirmwareType([ref]$fwNum)) {
        if ($fwNum -eq 2) { $fwMode = "UEFI" }
        elseif ($fwNum -eq 1) { $fwMode = "Legacy" }
    }
} catch {
    # Fallback for older Windows builds without kernel32!GetFirmwareType
    $null = $_.Exception.Message
}
if ($fwMode -eq "Unknown" -and $env:firmware_type) {
    if ($env:firmware_type -eq "UEFI") { $fwMode = "UEFI" }
    elseif ($env:firmware_type -eq "Legacy") { $fwMode = "Legacy" }
}
if ($fwMode -eq "Unknown" -and (Test-Path -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State")) {
    $fwMode = "UEFI"
}

if ($fwMode -ne "UEFI") {
    if ($fwMode -eq "Unknown") {
        Write-Host "[ERROR] Could not verify UEFI firmware mode (FirmwareType=Unknown)." -ForegroundColor Red
        Write-Host "        Ensure Windows is booted in UEFI mode (not Legacy CSM/MBR) and run as Administrator." -ForegroundColor Yellow
    } else {
        Write-Host "[ERROR] Windows is currently booted in Legacy BIOS (CSM/MBR) mode (FirmwareType=$fwMode)." -ForegroundColor Red
    }
    Write-Host "        To use ReBAR without reflashing (2-reboot Legacy -> UEFI sequence):" -ForegroundColor Yellow
    Write-Host "        1. Convert your OS drive to GPT (e.g. mbr2gpt) and prepare to boot in UEFI mode." -ForegroundColor Yellow
    Write-Host "        2. Reboot #1 in BIOS: Advanced -> CSM Configuration -> Video = UEFI -> F10 & Reboot." -ForegroundColor Yellow
    Write-Host "        3. Reboot #2 in BIOS: Advanced -> CSM Configuration -> CSM Support = Disabled (hides Video)" -ForegroundColor Yellow
    Write-Host "           & Advanced -> PCI Subsystem Settings -> Above 4G Decoding = Enabled -> F10." -ForegroundColor Yellow
    Write-Host "        4. Run this script again from UEFI Windows." -ForegroundColor Yellow
    exit 1
}

try {
    [UefiVarReBar]::EnablePrivilege()
} catch {
    Write-Host "[ERROR] Failed to acquire SeSystemEnvironmentPrivilege: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

[byte]$curVal = 0
[int]$readErr = 0
$hadReadError = $false
$readLen = [UefiVarReBar]::ReadReBar([ref]$curVal, [ref]$readErr)
if ($readLen -eq 1) {
    Write-Host ("Current NVRAM ReBarState = 0x{0:X2} ({1})" -f $curVal, (Format-ReBarStatus $curVal))
} elseif ($readLen -gt 1) {
    Write-Host ("[WARN] Current NVRAM ReBarState has unexpected size {0} bytes (first byte = 0x{1:X2})." -f $readLen, $curVal) -ForegroundColor Yellow
    Write-Host "       ReBarDxe requires an exact 1-byte variable and treats >1B values as Disabled." -ForegroundColor Yellow
    Write-Host "       Run with -Action Enable (or -Action Disable) to rewrite ReBarState cleanly as 1 byte." -ForegroundColor Yellow
} elseif ($readErr -eq 122) {
    Write-Host "[WARN] Current NVRAM ReBarState exceeds 64 bytes (Win32 error 122)." -ForegroundColor Yellow
    Write-Host "       ReBarDxe requires an exact 1-byte variable and treats >1B values as Disabled." -ForegroundColor Yellow
    Write-Host "       Run with -Action Enable (or -Action Disable) to rewrite ReBarState cleanly as 1 byte." -ForegroundColor Yellow
} elseif ($readErr -eq 203) {
    Write-Host "Current NVRAM ReBarState is not set (variable does not exist yet)."
} else {
    $hadReadError = $true
    Write-Host "[ERROR] Could not read ReBarState (Win32 error $readErr)." -ForegroundColor Red
}

if ($hadReadError) {
    Write-Host "        Aborting without modifying UEFI NVRAM." -ForegroundColor Red
    exit 1
}

if (-not $Action) {
    Write-Host ""
    Write-Host "Select action:"
    Write-Host "  [1] Enable ReBAR (ReBarState = 0x20 / Unlimited)"
    Write-Host "  [2] Disable ReBAR (ReBarState = 0x00)"
    Write-Host "  [3] Exit (Status only)"
    $choice = Read-Host "Enter 1, 2 or 3"
    $trimmed = if ($null -ne $choice) { $choice.Trim() } else { "" }
    switch ($trimmed) {
        "1" { $Action = "Enable" }
        "2" { $Action = "Disable" }
        "3" { $Action = "Status" }
        default {
            Write-Host "[ERROR] Invalid selection '$choice'. Please enter 1, 2, or 3." -ForegroundColor Red
            exit 1
        }
    }
}

if ($Action -eq "Status") {
    exit 0
}

$target = if ($Action -eq "Enable") { [byte]0x20 } else { [byte]0x00 }
[int]$writeErr = 0
$ok = [UefiVarReBar]::WriteReBar($target, [ref]$writeErr)
if (-not $ok) {
    Write-Host "[ERROR] Failed to write ReBarState (Win32 error $writeErr)." -ForegroundColor Red
    exit 1
}

[byte]$verVal = 0
[int]$verErr = 0
$vLen = [UefiVarReBar]::ReadReBar([ref]$verVal, [ref]$verErr)
if ($vLen -eq 1 -and $verVal -eq $target) {
    Write-Host ("[OK] ReBarState successfully set to 0x{0:X2} ({1})!" -f $verVal, (Format-ReBarStatus $verVal)) -ForegroundColor Green
    if ($Action -eq "Enable") {
        Write-Host "     Reboot your PC and ensure BIOS is configured (2-reboot sequence if switching from Legacy CSM):" -ForegroundColor Cyan
        Write-Host "     1. Advanced -> CSM Configuration -> Video = UEFI -> F10 & Reboot;" -ForegroundColor Cyan
        Write-Host "     2. Advanced -> CSM Configuration -> CSM Support = Disabled (hides Video)" -ForegroundColor Cyan
        Write-Host "        & Advanced -> PCI Subsystem Settings -> Above 4G Decoding = Enabled -> F10." -ForegroundColor Cyan
    } else {
        Write-Host "     Reboot your PC for the disabled ReBAR state to take effect." -ForegroundColor Cyan
    }
} else {
    Write-Host ("[ERROR] Verification mismatch after write (len={0}, val=0x{1:X2}, Win32 error {2})." -f $vLen, $verVal, $verErr) -ForegroundColor Red
    exit 1
}
