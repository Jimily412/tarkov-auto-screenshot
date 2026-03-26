# Tarkov Auto-Screenshot
# Press Ctrl+C to stop at any time.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$CONFIG_FILE = Join-Path $PSScriptRoot "config.json"

function Load-Config {
    $defaults = @{
        screenshot_dir   = [System.IO.Path]::Combine($env:USERPROFILE, "Documents", "Escape from Tarkov", "Screenshots")
        interval_seconds = 5
        screen_index     = 0
    }
    if (Test-Path $CONFIG_FILE) {
        try {
            $saved = Get-Content $CONFIG_FILE -Raw | ConvertFrom-Json
            if ($null -ne $saved.screenshot_dir)   { $defaults.screenshot_dir   = $saved.screenshot_dir }
            if ($null -ne $saved.interval_seconds) { $defaults.interval_seconds = [int]$saved.interval_seconds }
            if ($null -ne $saved.screen_index)     { $defaults.screen_index     = [int]$saved.screen_index }
        } catch {}
    }
    return $defaults
}

function Save-Config($cfg) {
    [PSCustomObject]@{
        screenshot_dir   = $cfg.screenshot_dir
        interval_seconds = $cfg.interval_seconds
        screen_index     = $cfg.screen_index
    } | ConvertTo-Json | Set-Content $CONFIG_FILE
}

function Take-Screenshot($screen, $dir) {
    $bounds = $screen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $filename = "tarkov_$(Get-Date -Format 'yyyyMMdd_HHmmss_fff').png"
    $bitmap.Save([System.IO.Path]::Combine($dir, $filename))
    $graphics.Dispose()
    $bitmap.Dispose()
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
$screens = [System.Windows.Forms.Screen]::AllScreens

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
Write-Host "  Which screen is Tarkov on?" -ForegroundColor Cyan
for ($i = 0; $i -lt $screens.Length; $i++) {
    $s = $screens[$i]
    $primary = if ($s.Primary) { " (Primary)" } else { "" }
    Write-Host "  [$i] $($s.Bounds.Width)x$($s.Bounds.Height) at position ($($s.Bounds.X), $($s.Bounds.Y))$primary" -ForegroundColor Gray
}
Write-Host "  Current: $($cfg.screen_index)" -ForegroundColor Gray
$in = Read-Host "  Screen number"
if ($in.Trim() -ne "") { $cfg.screen_index = [int]$in.Trim() }

if ($cfg.screen_index -lt 0 -or $cfg.screen_index -ge $screens.Length) {
    Write-Host "  Invalid screen, using 0" -ForegroundColor Red
    $cfg.screen_index = 0
}

$selectedScreen = $screens[$cfg.screen_index]
Save-Config $cfg

Write-Host ""
Write-Host "  ----------------------" -ForegroundColor DarkYellow
Write-Host "  Running" -ForegroundColor Green
Write-Host "  Screen   : $($cfg.screen_index) ($($selectedScreen.Bounds.Width)x$($selectedScreen.Bounds.Height))" -ForegroundColor White
Write-Host "  Interval : $($cfg.interval_seconds)s" -ForegroundColor White
Write-Host "  Folder   : $($cfg.screenshot_dir)" -ForegroundColor White
Write-Host "  Press Ctrl+C to stop" -ForegroundColor DarkGray
Write-Host "  ----------------------" -ForegroundColor DarkYellow
Write-Host ""

$shots = 0
$deleted = 0

while ($true) {
    Take-Screenshot $selectedScreen $cfg.screenshot_dir
    $shots++
    $d = Purge-Old $cfg.screenshot_dir
    $deleted += $d
    Write-Host "  [$(Get-Date -Format 'HH:mm:ss')]  Shots: $shots   Cleaned: $deleted" -ForegroundColor DarkGray
    Start-Sleep -Seconds $cfg.interval_seconds
}
