# ============================================================
#  USB-Guard v2.0
#  Win11 Home/Pro Edition
# ============================================================

$Script:Config = @{
    HashFile = "$env:USERPROFILE\.usb-guard-hash"
    PolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\{53f56307-b6bf-11d0-94f2-00a0c91efb8b}"
    DriverPath = "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR"
    MaxTries = 5
    LockDurationMinutes = 5
}

# ============================================================
#  Password Management
# ============================================================
function Set-Password {
    Write-Host ""
    Write-Host "======== Set Password ========" -ForegroundColor Cyan

    if (Test-Path $Script:Config.HashFile) {
        Write-Host "[!] Password already set. Verify old password first." -ForegroundColor Yellow
        Write-Host ""

        $storedHash = (Get-Content $Script:Config.HashFile -Raw).Trim()
        $oldPwd = Read-Host -AsSecureString "Enter old password"
        $plainOld = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($oldPwd))

        $oldBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash(
            [System.Text.Encoding]::UTF8.GetBytes($plainOld))
        $oldHash = [BitConverter]::ToString($oldBytes).Replace('-', '')

        if ($oldHash -ne $storedHash) {
            Write-Host "[X] Old password incorrect." -ForegroundColor Red
            return
        }

        Write-Host "[OK] Old password verified." -ForegroundColor Green
        Write-Host ""
    }

    $pwd1 = Read-Host -AsSecureString "Enter new password"
    $pwd2 = Read-Host -AsSecureString "Confirm new password"

    $plain1 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pwd1))
    $plain2 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pwd2))

    if ($plain1 -ne $plain2) {
        Write-Host "[X] Passwords do not match." -ForegroundColor Red
        return
    }
    if ($plain1.Length -lt 4) {
        Write-Host "[X] Password must be at least 4 characters." -ForegroundColor Red
        return
    }

    $hashBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash(
        [System.Text.Encoding]::UTF8.GetBytes($plain1))
    $hashHex = [BitConverter]::ToString($hashBytes).Replace('-', '')

    $hashHex | Out-File -FilePath $Script:Config.HashFile -Encoding ascii -Force
    try { icacls $Script:Config.HashFile /inheritance:r /grant ("$env:USERNAME`:F") /c > $null 2>&1 } catch {}

    Write-Host "[OK] Password set." -ForegroundColor Green
}

function Verify-Password {
    if (-not (Test-Path $Script:Config.HashFile)) {
        Write-Host "[X] No password set. Run option [1] first." -ForegroundColor Red
        return $false
    }

    $storedHash = (Get-Content $Script:Config.HashFile -Raw).Trim()
    $userPwd = Read-Host -AsSecureString "Enter password"
    $plainPwd = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($userPwd))

    $inputBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash(
        [System.Text.Encoding]::UTF8.GetBytes($plainPwd))
    $inputHash = [BitConverter]::ToString($inputBytes).Replace('-', '')

    return ($inputHash -eq $storedHash)
}

# ============================================================
#  Failure Tracking
# ============================================================
$Script:FailFile = "$env:USERPROFILE\.usb-guard-fail"

function Check-Lockout {
    if (-not (Test-Path $Script:FailFile)) { return $false }
    $data = Get-Content $Script:FailFile -Raw -ErrorAction SilentlyContinue
    if (-not $data) { return $false }
    $parts = $data.Trim().Split('|')
    if ($parts.Length -lt 2) { return $false }
    $failCount = [int]$parts[0]
    $lastFail = [datetime]$parts[1]
    if ($failCount -ge $Script:Config.MaxTries) {
        $elapsed = [datetime]::Now - $lastFail
        $remaining = [math]::Max(0, $Script:Config.LockDurationMinutes - $elapsed.TotalMinutes)
        if ($remaining -gt 0) {
            Write-Host "[X] Locked out. Failed $failCount times. Wait $([math]::Ceiling($remaining)) min." -ForegroundColor Red
            return $true
        } else {
            Remove-Item $Script:FailFile -Force -ErrorAction SilentlyContinue
            return $false
        }
    }
    return $false
}

function Record-Failure {
    $count = 1
    if (Test-Path $Script:FailFile) {
        $old = Get-Content $Script:FailFile -Raw -ErrorAction SilentlyContinue
        if ($old) {
            $parts = $old.Trim().Split('|')
            if ($parts.Length -ge 1) { $count = [int]$parts[0] + 1 }
        }
    }
    $data = "$count|$([datetime]::Now.ToString('O'))"
    $data | Out-File $Script:FailFile -Encoding ascii -Force
    $remaining = $Script:Config.MaxTries - $count
    if ($remaining -gt 0) {
        Write-Host "[X] Wrong password. $remaining tries left." -ForegroundColor Red
    } else {
        Write-Host "[X] Max failed attempts reached. Locked for $($Script:Config.LockDurationMinutes) min." -ForegroundColor Red
    }
}

function Reset-Failures {
    Remove-Item $Script:FailFile -Force -ErrorAction SilentlyContinue
}

# ============================================================
#  Lock Methods
# ============================================================

function Lock-USB-Policy {
    Write-Host ""
    Write-Host "======== Method 1: Policy Lock ========" -ForegroundColor Cyan

    try {
        if (-not (Test-Path $Script:Config.PolicyPath)) {
            $null = New-Item -Path $Script:Config.PolicyPath -Force -ErrorAction Stop
        }
        Set-ItemProperty -Path $Script:Config.PolicyPath -Name Deny_Read -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $Script:Config.PolicyPath -Name Deny_Write -Value 1 -Type DWord -Force
        Write-Host "[OK] Policy lock enabled." -ForegroundColor Green
        Write-Host "    Note: May not fully work on Win11 Home." -ForegroundColor Yellow
    } catch {
        Write-Host "[X] Policy lock failed: $_" -ForegroundColor Red
    }
}

function Lock-USB-Driver {
    Write-Host ""
    Write-Host "======== Method 2: Driver Lock (Recommended) ========" -ForegroundColor Cyan

    try {
        if (-not (Test-Path $Script:Config.DriverPath)) {
            Write-Host "[!] USBSTOR not found. Insert a USB drive first." -ForegroundColor Yellow
            return
        }

        Set-ItemProperty -Path $Script:Config.DriverPath -Name Start -Value 4 -Type DWord -Force

        Write-Host "[OK] Driver lock enabled." -ForegroundColor Green
        Write-Host "    USBSTOR driver disabled. New USB drives will not be recognized." -ForegroundColor Yellow
        Write-Host "    Already-inserted drives may still work. Reboot recommended." -ForegroundColor Yellow
    } catch {
        Write-Host "[X] Driver lock failed: $_" -ForegroundColor Red
        Write-Host "    Run as Administrator." -ForegroundColor Red
    }
}

function Lock-USB-Double {
    Write-Host ""
    Write-Host "======== Method 3: Double Lock ========" -ForegroundColor Cyan
    Lock-USB-Policy
    Lock-USB-Driver
    Write-Host ""
    Write-Host "[OK] Double lock complete. Reboot recommended." -ForegroundColor Green
}

function Unlock-USB-Policy {
    try {
        if (Test-Path $Script:Config.PolicyPath) {
            Set-ItemProperty -Path $Script:Config.PolicyPath -Name Deny_Read -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $Script:Config.PolicyPath -Name Deny_Write -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        }
    } catch {}
}

function Unlock-USB-Driver {
    try {
        if (Test-Path $Script:Config.DriverPath) {
            Set-ItemProperty -Path $Script:Config.DriverPath -Name Start -Value 3 -Type DWord -Force
        }
        Write-Host "[OK] Driver restored." -ForegroundColor Green
    } catch {
        Write-Host "[X] Driver unlock failed: $_" -ForegroundColor Red
    }
}

function Unlock-USB {
    Write-Host ""
    Write-Host "======== Unlock USB ========" -ForegroundColor Cyan

    if (Check-Lockout) { return }

    if (-not (Verify-Password)) {
        Record-Failure
        return
    }

    try {
        Unlock-USB-Policy
        Unlock-USB-Driver
        Reset-Failures
        Write-Host "[OK] USB unlocked." -ForegroundColor Green
        Write-Host "    Re-insert USB drive to take effect." -ForegroundColor Yellow
    } catch {
        Write-Host "[X] Unlock failed: $_" -ForegroundColor Red
    }
}

# ============================================================
#  Status Check
# ============================================================
function Get-USBStatus {
    Write-Host ""
    Write-Host "======== USB Status ========" -ForegroundColor Cyan

    $policyLocked = $false
    if (Test-Path $Script:Config.PolicyPath) {
        $denyRead = (Get-ItemProperty -Path $Script:Config.PolicyPath -Name Deny_Read -ErrorAction SilentlyContinue).Deny_Read
        $denyWrite = (Get-ItemProperty -Path $Script:Config.PolicyPath -Name Deny_Write -ErrorAction SilentlyContinue).Deny_Write
        if ($denyRead -eq 1 -or $denyWrite -eq 1) { $policyLocked = $true }
    }

    $driverLocked = $false
    if (Test-Path $Script:Config.DriverPath) {
        $start = (Get-ItemProperty -Path $Script:Config.DriverPath -Name Start -ErrorAction SilentlyContinue).Start
        if ($start -eq 4) { $driverLocked = $true }
    }

    $policyColor = if ($policyLocked) { 'Red' } else { 'Green' }
    $driverColor = if ($driverLocked) { 'Red' } else { 'Green' }
    $policyStatus = if ($policyLocked) { 'ENABLED' } else { 'Disabled' }
    $driverStatus = if ($driverLocked) { 'ENABLED' } else { 'Disabled' }

    Write-Host "  Policy Lock : $policyStatus" -ForegroundColor $policyColor
    Write-Host "  Driver Lock : $driverStatus" -ForegroundColor $driverColor

    if ($policyLocked -or $driverLocked) {
        Write-Host ""
        Write-Host "  Status: LOCKED" -ForegroundColor Red
    } else {
        Write-Host ""
        Write-Host "  Status: Unlocked" -ForegroundColor Green
    }

    if (Test-Path $Script:Config.HashFile) {
        Write-Host "  Password : Set" -ForegroundColor Green
    } else {
        Write-Host "  Password : NOT SET" -ForegroundColor Red
    }
}

# ============================================================
#  Menu
# ============================================================
function Show-Menu {
    Clear-Host
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "   USB-Guard v2.0" -ForegroundColor Cyan
    Write-Host "   For Win11 Home/Pro Edition" -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [0] View Status"
    Write-Host "  [1] Set / Change Password"
    Write-Host ""
    Write-Host "  --- Lock Methods (choose one) ---"
    Write-Host "  [2] Policy Lock (Pro Edition)"
    Write-Host "  [3] Driver Lock (Home Edition)"
    Write-Host "  [4] Double Lock (Most Secure)"
    Write-Host ""
    Write-Host "  [5] Unlock (requires password)"
    Write-Host ""
    Write-Host "  [Q] Quit"
    Write-Host ""
}

# ============================================================
#  Entry Point
# ============================================================
$isAdmin = ([System.Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [System.Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Host "[!] NOT running as Administrator!" -ForegroundColor Yellow
    Write-Host "    Lock/Unlock requires admin privileges." -ForegroundColor Yellow
    Write-Host "    Right-click PowerShell -> Run as Administrator." -ForegroundColor Yellow
    Write-Host ""
}

do {
    Show-Menu
    $choice = Read-Host "Enter option"

    switch ($choice) {
        '0' { Get-USBStatus }
        '1' { Set-Password }
        '2' { Lock-USB-Policy }
        '3' { Lock-USB-Driver }
        '4' { Lock-USB-Double }
        '5' { Unlock-USB }
        'Q' { break }
        'q' { break }
        default { Write-Host "[X] Invalid option." -ForegroundColor Red }
    }

    if ($choice -match '^[0-5]$') {
        Write-Host ""
        Write-Host "Press any key to continue..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
} while ($choice -ne 'Q' -and $choice -ne 'q')
