# Tarkov Auto-Screenshot v3.3.0
#
# SPACE  -> pause / resume
# Ctrl+C -> quit

$VERSION    = "3.3.0"
$LOG_FILE   = Join-Path $PSScriptRoot "tarkov_screenshot.log"
$CONFIG_FILE = Join-Path $PSScriptRoot "config.json"
$COORD_PATTERN = '_-?[\d]+\.[\d]+, -?[\d]+\.[\d]+, -?[\d]+\.[\d]+'

function Write-Log($msg, $color = "Gray") {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')]  $msg"
    try { Add-Content -Path $LOG_FILE -Value $line -Encoding UTF8 -ErrorAction Stop } catch {}
    Write-Host "  $line" -ForegroundColor $color
}

function Write-LogError($msg, $err) {
    Write-Log "ERROR: $msg" "Red"
    if ($err) {
        Write-Log "  Exception : $($err.Exception.Message)" "Red"
        Write-Log "  Type      : $($err.Exception.GetType().FullName)" "Red"
        if ($err.ScriptStackTrace) {
            Write-Log "  Stack     : $($err.ScriptStackTrace -replace "`n", ' | ')" "Red"
        }
    }
}

function Rotate-Log {
    try {
        if (Test-Path $LOG_FILE) {
            $lines = Get-Content $LOG_FILE -ErrorAction Stop
            if ($lines.Count -gt 500) {
                $lines | Select-Object -Last 500 | Set-Content $LOG_FILE -Encoding UTF8
            }
        }
    } catch {}
}

Rotate-Log

Add-Content -Path $LOG_FILE -Value "" -Encoding UTF8
Write-Log "============================================================" "DarkYellow"
Write-Log "Tarkov Auto-Screenshot  v$VERSION" "Yellow"
Write-Log "PowerShell  $($PSVersionTable.PSVersion)  |  OS: $([System.Environment]::OSVersion.VersionString)" "DarkGray"
Write-Log "Script path : $PSScriptRoot" "DarkGray"
Write-Log "Log file    : $LOG_FILE" "DarkGray"
Write-Log "============================================================" "DarkYellow"

Write-Log "Loading Win32 interop..." "DarkGray"
try {
    if (-not ([System.Management.Automation.PSTypeName]'Win32PostMsg').Type) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32PostMsg {
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
}
"@ -ErrorAction Stop
    }
    Write-Log "Win32 interop loaded OK." "DarkGray"
} catch {
    Write-LogError "Add-Type failed — cannot send keys to EFT." $_
    Write-Log "Script cannot continue. Press Enter to exit." "Red"
    Read-Host | Out-Null
    exit 1
}

$VK_CODES = @{
    "home"=0x24;"end"=0x23;"insert"=0x2D;"delete"=0x2E
    "print_screen"=0x2C;"scroll_lock"=0x91;"pause"=0x13
    "f1"=0x70;"f2"=0x71;"f3"=0x72;"f4"=0x73;"f5"=0x74;"f6"=0x75
    "f7"=0x76;"f8"=0x77;"f9"=0x78;"f10"=0x79;"f11"=0x7A;"f12"=0x7B
}

function Load-Config {
    $d = @{ screenshot_dir = [System.IO.Path]::Combine($env:USERPROFILE,"Documents","Escape from Tarkov","Screenshots"); interval_seconds = 5; screenshot_key = "f12" }
    if (Test-Path $CONFIG_FILE) {
        try {
            $s = Get-Content $CONFIG_FILE -Raw -ErrorAction Stop | ConvertFrom-Json
            if ($s.screenshot_dir  -and $s.screenshot_dir.Trim()  -ne "") { $d.screenshot_dir   = $s.screenshot_dir }
            if ($null -ne $s.interval_seconds)                             { $d.interval_seconds = [int]$s.interval_seconds }
            if ($s.screenshot_key  -and $s.screenshot_key.Trim()  -ne "") { $d.screenshot_key   = $s.screenshot_key }
        } catch { Write-LogError "Failed to read config.json" $_ }
    }
    return $d
}

function Save-Config($cfg) {
    try {
        [PSCustomObject]@{ screenshot_dir=$cfg.screenshot_dir; interval_seconds=$cfg.interval_seconds; screenshot_key=$cfg.screenshot_key } |
            ConvertTo-Json | Set-Content $CONFIG_FILE -Encoding UTF8
    } catch { Write-LogError "Failed to save config.json" $_ }
}

function Send-KeyToEFT($vk) {
    try {
        $eft = Get-Process -Name "EscapeFromTarkov" -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $eft) { Write-Log "EFT process not found." "DarkGray"; return $false }
        if ($eft.MainWindowHandle -eq [IntPtr]::Zero) { Write-Log "EFT has no window handle (minimised or loading)." "DarkGray"; return $false }
        $hwnd = $eft.MainWindowHandle
        $r1 = [Win32PostMsg]::PostMessage($hwnd, 0x0100, [IntPtr]$vk, [IntPtr]1)
        Start-Sleep -Milliseconds 50
        $r2 = [Win32PostMsg]::PostMessage($hwnd, 0x0101, [IntPtr]$vk, [IntPtr]0xC0000001)
        Write-Log "PostMessage WM_KEYDOWN=$r1  WM_KEYUP=$r2  hwnd=$hwnd  vk=0x$('{0:X2}' -f $vk)" "DarkGray"
        return $true
    } catch {
        Write-LogError "Send-KeyToEFT failed" $_
        return $false
    }
}

function Get-FileSnapshot($dir) {
    $snap = @{}
    try {
        if (Test-Path $dir) {
            Get-ChildItem -Path $dir -Filter "*.png" -File -ErrorAction Stop |
                ForEach-Object { $snap[$_.Name] = $true }
        }
    } catch { Write-LogError "Get-FileSnapshot failed" $_ }
    Write-Log "Snapshot: $($snap.Count) PNG(s) in folder." "DarkGray"
    return $snap
}

function Get-NewFiles($dir, $snapshot) {
    try {
        if (-not (Test-Path $dir)) { return @() }
        $new = @(Get-ChildItem -Path $dir -Filter "*.png" -File -ErrorAction Stop |
            Where-Object { -not $snapshot.ContainsKey($_.Name) })
        Write-Log "New files since snapshot: $($new.Count)  [$($new.Name -join ', ')]" "DarkGray"
        return $new
    } catch {
        Write-LogError "Get-NewFiles failed" $_
        return @()
    }
}

function Purge-Old($dir) {
    $count = 0
    try {
        if (-not (Test-Path $dir)) { Write-Log "Purge: folder not found — $dir" "Red"; return 0 }
        $cutoff = (Get-Date).AddSeconds(-30)
        $all = @(Get-ChildItem -Path $dir -File -ErrorAction Stop)
        Write-Log "Purge: $($all.Count) total file(s), cutoff=$(Get-Date $cutoff -Format 'HH:mm:ss')" "DarkGray"
        foreach ($f in $all) {
            if ($f.Extension -eq '.png' -or $f.Extension -eq '.jpg' -or $f.Extension -eq '.jpeg') {
                if ($f.LastWriteTime -lt $cutoff) {
                    try {
                        Remove-Item $f.FullName -Force -ErrorAction Stop
                        Write-Log "Deleted: $($f.Name)" "DarkGray"
                        $count++
                    } catch { Write-LogError "Could not delete $($f.Name)" $_ }
                }
            }
        }
    } catch { Write-LogError "Purge-Old failed" $_ }
    return $count
}

Write-Log "Starting setup wizard..." "Cyan"
$cfg = Load-Config
Write-Log "Config loaded: dir='$($cfg.screenshot_dir)'  interval=$($cfg.interval_seconds)s  key=$($cfg.screenshot_key)" "DarkGray"

Write-Host ""
Write-Host "  Screenshot folder  (Enter = keep current)" -ForegroundColor Cyan
Write-Host "  Current: $($cfg.screenshot_dir)" -ForegroundColor Gray
$in = Read-Host "  New path"
if ($in.Trim() -ne "") { $cfg.screenshot_dir = $in.Trim().Trim('"') }

if (-not (Test-Path $cfg.screenshot_dir)) {
    try {
        New-Item -ItemType Directory -Path $cfg.screenshot_dir -Force | Out-Null
        Write-Log "Created folder: $($cfg.screenshot_dir)" "DarkGray"
    } catch { Write-LogError "Could not create screenshot folder" $_ }
}

Write-Host ""
Write-Host "  Interval in seconds  (Enter = keep current)" -ForegroundColor Cyan
Write-Host "  Current: $($cfg.interval_seconds)" -ForegroundColor Gray
$in = Read-Host "  New interval"
if ($in.Trim() -ne "") { $cfg.interval_seconds = [int]$in.Trim() }

Write-Host ""
Write-Host "  Screenshot key  (Enter = keep current)" -ForegroundColor Cyan
Write-Host "  Current: $($cfg.screenshot_key)" -ForegroundColor Gray
$in = Read-Host "  New key"
if ($in.Trim() -ne "") { $cfg.screenshot_key = $in.Trim().ToLower() }

$vk = $VK_CODES[$cfg.screenshot_key]
if (-not $vk) {
    if ($cfg.screenshot_key.Length -eq 1) {
        $vk = [byte][char]::ToUpper($cfg.screenshot_key[0])
    } else {
        Write-Log "Unknown key '$($cfg.screenshot_key)' — defaulting to f12." "Red"
        $cfg.screenshot_key = "f12"; $vk = 0x7B
    }
}

Save-Config $cfg
Write-Log "Config saved. key=$($cfg.screenshot_key) (vk=0x$('{0:X2}' -f $vk))  interval=$($cfg.interval_seconds)s  dir=$($cfg.screenshot_dir)" "DarkGray"

Write-Host ""
Write-Host "  ----------------------" -ForegroundColor DarkYellow
Write-Host "  v$VERSION" -ForegroundColor Yellow
Write-Host "  Key      : $($cfg.screenshot_key.ToUpper())" -ForegroundColor White
Write-Host "  Interval : $($cfg.interval_seconds)s" -ForegroundColor White
Write-Host "  Folder   : $($cfg.screenshot_dir)" -ForegroundColor White
Write-Host "  Log      : $LOG_FILE" -ForegroundColor White
Write-Host "  SPACE    : pause / resume" -ForegroundColor DarkGray
Write-Host "  Ctrl+C   : quit" -ForegroundColor DarkGray
Write-Host "  ----------------------" -ForegroundColor DarkYellow
Write-Host ""

Write-Log "Entering main loop." "Green"

$shots=0; $deleted=0; $paused=$false; $inRaid=$false

while ($true) {
    $loopStart = Get-Date

    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq [ConsoleKey]::Spacebar) {
            $paused = -not $paused
            Write-Log $(if ($paused) { "PAUSED." } else { "RESUMED." }) "Yellow"
        }
    }

    if (-not $paused) {
        $sent = Send-KeyToEFT $vk

        if (-not $sent) {
            if ($inRaid) { $inRaid = $false }
        } else {
            $before   = Get-FileSnapshot $cfg.screenshot_dir
            Start-Sleep -Milliseconds 1500
            $newFiles  = Get-NewFiles $cfg.screenshot_dir $before
            $wasInRaid = $inRaid

            if ($newFiles) {
                $hasCoords = @($newFiles | Where-Object { $_.Name -match $COORD_PATTERN })
                $inRaid    = $hasCoords.Count -gt 0
                Write-Log "New file(s) with coords: $($hasCoords.Count)  inRaid=$inRaid" "DarkGray"
                if ($inRaid) {
                    $shots++
                    if (-not $wasInRaid) { Write-Log "Raid detected — tracking started." "Green" }
                    Write-Log "Shots: $shots   Cleaned: $deleted" "DarkGray"
                } else {
                    if ($wasInRaid) { Write-Log "Left raid — idling." "DarkYellow" }
                    else            { Write-Log "In menus — waiting for raid..." "DarkGray" }
                }
            } else {
                Write-Log "No new screenshot appeared after keypress — EFT may be on loading screen or key not registered." "DarkYellow"
            }

            $d = Purge-Old $cfg.screenshot_dir
            $deleted += $d
        }
    }

    $elapsed = ((Get-Date) - $loopStart).TotalSeconds
    $remaining = $cfg.interval_seconds - $elapsed
    if ($remaining -gt 0) { Start-Sleep -Seconds $remaining }
}
