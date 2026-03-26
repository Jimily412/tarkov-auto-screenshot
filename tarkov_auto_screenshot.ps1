# Tarkov Auto-Screenshot
# Press Ctrl+C to stop at any time.

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
public class KeySender {
    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);
    public static void Press(byte vk) {
        keybd_event(vk, 0, 0, 0);
        System.Threading.Thread.Sleep(50);
        keybd_event(vk, 0, 2, 0);
    }
}
"@

$CONFIG_FILE = Join-Path $PSScriptRoot "config.json"

function Load-Config {
    $defaults = @{
        screenshot_dir   = [System.IO.Path]::Combine($env:USERPROFILE, "Documents", "Escape from Tarkov", "Screenshots")
        interval_seconds = 5
        screenshot_key   = "home"
    }
    if (Test-Path $CONFIG_FILE) {
        try {
            $saved = Get-Content $CONFIG_FILE -Raw | ConvertFrom-Json
            if ($saved.screenshot_dir)   { $defaults.screenshot_dir   = $saved.screenshot_dir }
            if ($saved.interval_seconds) { $defaults.interval_seconds = [int]$saved.interval_seconds }
            if ($saved.screenshot_key)   { $defaults.screenshot_key   = $saved.screenshot_key }
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

function Purge-Old($dir) {
    $cutoff = (Get-Date).AddSeconds(-30)
    $count = 0
    Get-ChildItem -Path $dir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -match '\.(png|jpg|jpeg)$' -and $_.LastWriteTime -lt $cutoff } |
        ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue; $count++ }
    return $count
}

Clear-Host
Write-Host ""
Write-Host "  Tarkov Auto-Screenshot" -ForegroundColor Yellow
Write-Host "  ----------------------" -ForegroundColor DarkYellow
Write-Host ""

$cfg = Load-Config

Write-Host "  Screenshot folder  (Enter = keep current)" -ForegroundColor Cyan
Write-Host "  Current: $($cfg.screenshot_dir)" -ForegroundColor Gray
$in = Read-Host "  New path"
if ($in.Trim() -ne "") { $cfg.screenshot_dir = $in.Trim() }

if (-not (Test-Path $cfg.screenshot_dir)) {
    New-Item -ItemType Directory -Path $cfg.screenshot_dir -Force | Out-Null
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
        Write-Host "  Unknown key, defaulting to 'home'" -ForegroundColor Red
        $cfg.screenshot_key = "home"
        $vk = 0x24
    }
}

Save-Config $cfg

Write-Host ""
Write-Host "  ----------------------" -ForegroundColor DarkYellow
Write-Host "  Running" -ForegroundColor Green
Write-Host "  Key: $($cfg.screenshot_key.ToUpper())   Interval: $($cfg.interval_seconds)s   Folder: $($cfg.screenshot_dir)" -ForegroundColor White
Write-Host "  Press Ctrl+C to stop" -ForegroundColor DarkGray
Write-Host "  ----------------------" -ForegroundColor DarkYellow
Write-Host ""

$shots = 0
$deleted = 0

while ($true) {
    [KeySender]::Press($vk)
    $shots++
    $d = Purge-Old $cfg.screenshot_dir
    $deleted += $d
    Write-Host "  [$(Get-Date -Format 'HH:mm:ss')]  Shots: $shots   Cleaned: $deleted" -ForegroundColor DarkGray
    Start-Sleep -Seconds $cfg.interval_seconds
}
