# Tarkov Auto-Screenshot
#
# Sends screenshot key directly to EFT window only — won't affect anything else.
# Automatically detects when you are in-raid vs in menus/lobby:
#   IN RAID   -> screenshots fire on interval, Questie updates, files are cleaned up
#   NOT IN RAID -> tool idles silently, no keypresses sent, waiting to detect raid start
#
# Detection: EFT only writes coordinates into the screenshot filename when inside a raid.
# If the latest screenshot has no coordinates, you are in a menu or lobby.
#
# SPACE  -> pause / resume
# Ctrl+C -> quit

$VK_CODES = @{
    "home"         = 0x24
    "print_screen" = 0x2C
    "insert"       = 0x2D
    "delete"       = 0x2E
    "end"          = 0x23
    "scroll_lock"  = 0x91
    "pause"        = 0x13
    "f1"  = 0x70; "f2"  = 0x71; "f3"  = 0x72; "f4"  = 0x73
    "f5"  = 0x74; "f6"  = 0x75; "f7"  = 0x76; "f8"  = 0x77
    "f9"  = 0x78; "f10" = 0x79; "f11" = 0x7A; "f12" = 0x7B
}

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
}
"@

$CONFIG_FILE   = Join-Path $PSScriptRoot "config.json"
$COORD_PATTERN = '_-?[\d]+\.[\d]+, -?[\d]+\.[\d]+, -?[\d]+\.[\d]+'

function Load-Config {
    $defaults = @{
        screenshot_dir   = [System.IO.Path]::Combine($env:USERPROFILE, "Documents", "Escape from Tarkov", "Screenshots")
        interval_seconds = 5
        screenshot_key   = "f12"
    }
    if (Test-Path $CONFIG_FILE) {
        try {
            $saved = Get-Content $CONFIG_FILE -Raw | ConvertFrom-Json
            if ($saved.screenshot_dir   -and $saved.screenshot_dir.Trim() -ne "")  { $defaults.screenshot_dir   = $saved.screenshot_dir }
            if ($null -ne $saved.interval_seconds)                                  { $defaults.interval_seconds = [int]$saved.interval_seconds }
            if ($saved.screenshot_key   -and $saved.screenshot_key.Trim() -ne "")  { $defaults.screenshot_key   = $saved.screenshot_key }
        } catch {}
    }
    return $defaults
}

function Save-Config($cfg) {
    [PSCustomObject]@{
        screenshot_dir   = $cfg.screenshot_dir
        interval_seconds = $cfg.interval_seconds
        screenshot_key   = $cfg.screenshot_key
    } | ConvertTo-Json | Set-Content $CONFIG_FILE
}

function Send-KeyToEFT($vk) {
    $eft = Get-Process -Name "EscapeFromTarkov" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $eft -or $eft.MainWindowHandle -eq [IntPtr]::Zero) { return $false }
    $hwnd = $eft.MainWindowHandle
    [Win32]::PostMessage($hwnd, 0x0100, [IntPtr]$vk, [IntPtr]1)          | Out-Null
    Start-Sleep -Milliseconds 50
    [Win32]::PostMessage($hwnd, 0x0101, [IntPtr]$vk, [IntPtr]0xC0000001) | Out-Null
    return $true
}

function Get-FileSnapshot($dir) {
    if (-not (Test-Path $dir)) { return @{} }
    $snap = @{}
    Get-ChildItem -Path $dir -Filter "*.png" -File -ErrorAction SilentlyContinue |
        ForEach-Object { $snap[$_.Name] = $true }
    return $snap
}

function Get-NewFiles($dir, $snapshot) {
    if (-not (Test-Path $dir)) { return @() }
    return Get-ChildItem -Path $dir -Filter "*.png" -File -ErrorAction SilentlyContinue |
        Where-Object { -not $snapshot.ContainsKey($_.Name) }
}

function Purge-Old($dir) {
    if (-not (Test-Path $dir)) { return 0 }
    $cutoff = (Get-Date).AddSeconds(-30)
    $count  = 0
    $files  = Get-ChildItem -Path $dir -File -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        if ($f.Extension -eq '.png' -or $f.Extension -eq '.jpg' -or $f.Extension -eq '.jpeg') {
            if ($f.LastWriteTime -lt $cutoff) {
                try {
                    Remove-Item $f.FullName -Force -ErrorAction Stop
                    $count++
                } catch {}
            }
        }
    }
    return $count
}

# ---- Setup ----

Write-Host ""
Write-Host "  Tarkov Auto-Screenshot" -ForegroundColor Yellow
Write-Host "  ----------------------" -ForegroundColor DarkYellow
Write-Host ""

$cfg = Load-Config

Write-Host "  Screenshot folder  (Enter = keep current)" -ForegroundColor Cyan
Write-Host "  Current: $($cfg.screenshot_dir)" -ForegroundColor Gray
$in = Read-Host "  New path"
if ($in.Trim() -ne "") { $cfg.screenshot_dir = $in.Trim().Trim('"') }
if (-not (Test-Path $cfg.screenshot_dir)) {
    New-Item -ItemType Directory -Path $cfg.screenshot_dir -Force | Out-Null
}

Write-Host ""
Write-Host "  Interval in seconds  (Enter = keep current)" -ForegroundColor Cyan
Write-Host "  Current: $($cfg.interval_seconds)" -ForegroundColor Gray
$in = Read-Host "  New interval"
if ($in.Trim() -ne "") { $cfg.interval_seconds = [int]$in.Trim() }

Write-Host ""
Write-Host "  Screenshot key — must match your EFT keybind  (Enter = keep current)" -ForegroundColor Cyan
Write-Host "  Current: $($cfg.screenshot_key)" -ForegroundColor Gray
$in = Read-Host "  New key"
if ($in.Trim() -ne "") { $cfg.screenshot_key = $in.Trim().ToLower() }

$vk = $VK_CODES[$cfg.screenshot_key]
if (-not $vk) {
    if ($cfg.screenshot_key.Length -eq 1) {
        $vk = [byte][char]::ToUpper($cfg.screenshot_key[0])
    } else {
        Write-Host "  Unknown key, defaulting to 'f12'" -ForegroundColor Red
        $cfg.screenshot_key = "f12"
        $vk = 0x7B
    }
}

Save-Config $cfg

Write-Host ""
Write-Host "  ----------------------" -ForegroundColor DarkYellow
Write-Host "  Key      : $($cfg.screenshot_key.ToUpper())" -ForegroundColor White
Write-Host "  Interval : $($cfg.interval_seconds)s" -ForegroundColor White
Write-Host "  Folder   : $($cfg.screenshot_dir)" -ForegroundColor White
Write-Host "  SPACE    : pause / resume" -ForegroundColor DarkGray
Write-Host "  Ctrl+C   : quit" -ForegroundColor DarkGray
Write-Host "  ----------------------" -ForegroundColor DarkYellow
Write-Host ""

$shots   = 0
$deleted = 0
$paused  = $false
$inRaid  = $false

while ($true) {
    $loopStart = Get-Date

    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq [ConsoleKey]::Spacebar) {
            $paused = -not $paused
            $label  = if ($paused) { "PAUSED — press Space to resume" } else { "RESUMED" }
            Write-Host "  [$(Get-Date -Format 'HH:mm:ss')]  $label" -ForegroundColor Yellow
        }
    }

    if (-not $paused) {
        $sent = Send-KeyToEFT $vk

        if (-not $sent) {
            if ($inRaid) {
                $inRaid = $false
                Write-Host "  [$(Get-Date -Format 'HH:mm:ss')]  EFT not running — waiting..." -ForegroundColor DarkGray
            }
        } else {
            $before = Get-FileSnapshot $cfg.screenshot_dir
            Start-Sleep -Milliseconds 1500

            $newFiles  = Get-NewFiles $cfg.screenshot_dir $before
            $wasInRaid = $inRaid

            if ($newFiles) {
                $hasCoords = $newFiles | Where-Object { $_.Name -match $COORD_PATTERN }
                $inRaid    = [bool]$hasCoords

                if ($inRaid) {
                    $shots++
                    if (-not $wasInRaid) {
                        Write-Host "  [$(Get-Date -Format 'HH:mm:ss')]  Raid detected — tracking started." -ForegroundColor Green
                    }
                    Write-Host "  [$(Get-Date -Format 'HH:mm:ss')]  Shots: $shots   Cleaned: $deleted" -ForegroundColor DarkGray
                } else {
                    if ($wasInRaid) {
                        Write-Host "  [$(Get-Date -Format 'HH:mm:ss')]  Left raid — idling." -ForegroundColor DarkYellow
                    } else {
                        Write-Host "  [$(Get-Date -Format 'HH:mm:ss')]  In menus — waiting for raid..." -ForegroundColor DarkGray
                    }
                }
            } else {
                Write-Host "  [$(Get-Date -Format 'HH:mm:ss')]  Waiting for screenshot response from EFT..." -ForegroundColor DarkGray
            }

            $d = Purge-Old $cfg.screenshot_dir
            $deleted += $d
        }
    }

    $elapsed   = ((Get-Date) - $loopStart).TotalSeconds
    $remaining = $cfg.interval_seconds - $elapsed
    if ($remaining -gt 0) {
        Start-Sleep -Seconds $remaining
    }
}
