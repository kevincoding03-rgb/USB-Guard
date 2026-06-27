# USB-Guard Enhanced v2.0

## 简介 / Introduction

USB-Guard Enhanced 是一个专为 Windows 11 Home/Canary Edition 设计的 PowerShell 脚本，用于管理和控制 USB 设备的访问权限。

USB-Guard Enhanced is a PowerShell script designed specifically for Windows 11 Home/Canary Edition to manage and control USB device access permissions.

## 功能特点 / Features

- 🔐 **多重锁定机制** / Multiple Lock Mechanisms
  - 策略锁定 / Policy Lock
  - 驱动锁定 / Driver Lock
  - 双重锁定 / Double Lock
  
- 🔒 **安全密码管理** / Secure Password Management
  - SHA-256 哈希加密 / SHA-256 Hash Encryption
  - 密码更改验证 / Password Change Verification
  - 最小密码长度要求 / Minimum Password Length Requirement
  
- 🚫 **失败尝试保护** / Failed Attempt Protection
  - 最多5次失败尝试 / Maximum 5 failed attempts
  - 失败后锁定5分钟 / 5-minute lockout after failures
  - 自动记录失败尝试 / Automatic failure recording
  
- 📊 **实时状态监控** / Real-time Status Monitoring
  - USB设备锁定状态 / USB device lock status
  - 密码设置状态 / Password setup status

## 使用方法 / Usage

### 1. 以管理员身份运行 / Run as Administrator
```powershell
# 右键点击 PowerShell → 以管理员身份运行
# Right-click PowerShell → Run as Administrator
```

### 2. 执行脚本 / Execute Script
```powershell
.\USB-Guard.ps1

### 3. 菜单选项 / Menu Options
| 选项 / Option | 功能 / Function |
|--------------|----------------|
| `[0]` | 查看当前状态 / View Status |
| `[1]` | 设置/更改密码 / Set/Change Password |
| `[2]` | 策略锁定 / Policy Lock |
| `[3]` | 驱动锁定 / Driver Lock |
| `[4]` | 双重锁定 / Double Lock |
| `[5]` | 解锁 / Unlock |
| `[Q]` | 退出 / Quit |

## 锁定机制详解 / Lock Mechanisms

### 策略锁定 / Policy Lock
```powershell
# 修改注册表策略 / Modify registry policy
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\{53f56307-b6bf-11d0-94f2-00a0c91efb8b}" -Name Deny_Read -Value 1
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\{53f56307-b6bf-11d0-94f2-00a0c91efb8b}" -Name Deny_Write -Value 1
```

### 驱动锁定 / Driver Lock (推荐 / Recommended)
```powershell
# 禁用 USBSTOR 驱动 / Disable USBSTOR driver
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR" -Name Start -Value 4
```

### 双重锁定 / Double Lock
```powershell
Lock-USB-Policy
Lock-USB-Driver
```

## 配置说明 / Configuration

```powershell
$Script:Config = @{
    HashFile = "$env:USERPROFILE\.usb-guard-hash"
    PolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\{53f56307-b6bf-11d0-94f2-00a0c91efb8b}"
    DriverPath = "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR"
    MaxTries = 5
    LockDurationMinutes = 5
}
```

## 注意事项 / Notes

1. **管理员权限** / Administrator Privileges：锁定/解锁操作必须以管理员身份运行
   Lock/Unlock operations must be performed with administrator privileges

2. **重启建议** / Reboot Recommended：某些锁定操作后建议重启系统以确保完全生效
   A reboot is recommended after certain lock operations to ensure full effect

3. **兼容性** / Compatibility：策略锁定在 Windows 11 Home 上可能不完全有效
   Policy lock may not be fully effective on Windows 11 Home

4. **数据备份** / Data Backup：使用前建议备份重要注册表设置
   It is recommended to back up important registry settings before use

5. **已插入设备** / Inserted Devices：驱动锁定后，已插入的 USB 设备可能仍可工作
   After driver lock, already-inserted USB devices may still work

## 技术细节 / Technical Details

- **密码存储** / Password Storage：使用 SHA-256 哈希加密存储密码
  Passwords are stored using SHA-256 hash encryption

- **失败追踪** / Failure Tracking：记录失败尝试次数和时间戳
  Records failure attempts and timestamps

- **文件位置** / File Locations：
  - 密码哈希 / Password Hash: `$env:USERPROFILE\.usb-guard-hash`
  - 失败记录 / Failure Record: `$env:USERPROFILE\.usb-guard-fail`

- **注册表修改** / Registry Modifications：直接修改系统注册表以控制 USB 设备访问
  Directly modifies system registry to control USB device access

## 免责声明 / Disclaimer

本脚本仅用于增强系统安全性，使用者应了解修改系统注册表的风险。作者不对因使用此脚本而导致的任何数据损失或系统问题负责。

This script is intended to enhance system security only. Users should be aware of the risks of modifying the system registry. The author is not responsible for any data loss or system issues caused by the use of this script.
