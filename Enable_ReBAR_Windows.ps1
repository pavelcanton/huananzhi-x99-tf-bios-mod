#Requires -RunAsAdministrator
param(
    [ValidateSet("Enable", "Disable", "Status")]
    [string]$Action = ""
)

$ErrorActionPreference = "Stop"

# Verify UEFI boot mode (EFI variables cannot be modified when booted in Legacy BIOS/CSM MBR mode)
$fwType = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "PEFirmwareType" -ErrorAction SilentlyContinue).PEFirmwareType
if ($fwType -ne 2) {
    Write-Host "[ERROR] Windows is currently booted in Legacy BIOS (CSM/MBR) mode (PEFirmwareType=$fwType)." -ForegroundColor Red
    Write-Host "        To use ReBAR without reflashing:" -ForegroundColor Yellow
    Write-Host "        1. Convert your OS drive to GPT (e.g. mbr2gpt) and boot in UEFI mode." -ForegroundColor Yellow
    Write-Host "        2. In BIOS: Boot -> CSM Support = Disabled, Video = UEFI, Above 4G Decoding = Enabled." -ForegroundColor Yellow
    Write-Host "        3. Run this script again from UEFI Windows." -ForegroundColor Yellow
    exit 1
}

$code = @"
using System;
using System.Runtime.InteropServices;
public class UefiVarReBar {
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
        if (!OpenProcessToken(System.Diagnostics.Process.GetCurrentProcess().Handle, 0x28, out hToken))
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES { PrivilegeCount = 1, Attributes = 2 };
        if (!LookupPrivilegeValue(null, "SeSystemEnvironmentPrivilege", out tp.Luid))
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        if (!AdjustTokenPrivileges(hToken, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero))
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
    }
}
"@
Add-Type -TypeDefinition $code
[UefiVarReBar]::EnablePrivilege()

$guid = "{a3c5b77a-c88f-4a93-bf1c-4a92a32c65ce}"
$buf = New-Object byte[] 4
$readLen = [UefiVarReBar]::GetFirmwareEnvironmentVariable("ReBarState", $guid, $buf, 4)
$readErr = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
if ($readLen -gt 0) {
    Write-Host ("Current NVRAM ReBarState = 0x{0:X2} ({1})" -f $buf[0], $(if ($buf[0] -eq 0) { "Disabled" } else { "Enabled / Unlimited" }))
} elseif ($readErr -eq 203) {
    Write-Host "Current NVRAM ReBarState is not set (variable does not exist yet)."
} else {
    Write-Host "[WARN] Could not read ReBarState (Win32 error $readErr)." -ForegroundColor Yellow
}

if (-not $Action) {
    Write-Host ""
    Write-Host "Select action:"
    Write-Host "  [1] Enable ReBAR (ReBarState = 0x20 / Unlimited)"
    Write-Host "  [2] Disable ReBAR (ReBarState = 0x00)"
    Write-Host "  [3] Exit (Status only)"
    $choice = Read-Host "Enter 1, 2 or 3"
    switch ($choice) {
        "1" { $Action = "Enable" }
        "2" { $Action = "Disable" }
        default { $Action = "Status" }
    }
}

if ($Action -eq "Status") { exit 0 }

$target = if ($Action -eq "Enable") { [byte]0x20 } else { [byte]0x00 }
$ok = [UefiVarReBar]::SetFirmwareEnvironmentVariable("ReBarState", $guid, [byte[]]@($target), 1)
$err = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
if (-not $ok) {
    Write-Host "[ERROR] Failed to write ReBarState (Win32 error $err)." -ForegroundColor Red
    exit 1
}

$verify = New-Object byte[] 4
$vLen = [UefiVarReBar]::GetFirmwareEnvironmentVariable("ReBarState", $guid, $verify, 4)
if ($vLen -eq 1 -and $verify[0] -eq $target) {
    Write-Host ("[OK] ReBarState successfully set to 0x{0:X2}!" -f $verify[0]) -ForegroundColor Green
    Write-Host "     Reboot your PC (and make sure Above 4G Decoding = Enabled and CSM = Disabled in BIOS)." -ForegroundColor Cyan
} else {
    Write-Host "[ERROR] Verification mismatch after write." -ForegroundColor Red
    exit 1
}
