# Tarkov Auto-Screenshot
#
# Zero-interference position tracking for Tarkov Questie.
# Never sends keypresses to EFT — no popups, no game interference, no effect on typing.
#
# How it works:
#   1. Watches your EFT screenshot folder for real screenshots you take manually.
#   2. Extracts coordinates from EFT's coordinate-encoded filename instantly.
#   3. Generates silent 1x1 PNGs every 2 seconds so Questie stays updated.
#   4. Deletes files older than 30 seconds to prevent disk buildup.
#
# One-time per raid:
#   When you load into a map, press your EFT screenshot key ONCE.
#   The tool locks onto the coordinates and runs silently from there.
#   Press it again any time you want to refresh your position on the squad map.
#
# SPACE  -> pause / resume
# Ctrl+C -> quit

Add-Type -AssemblyName System.Drawing

$CONFIG_FILE  = Join-Path $PSScriptRoot "config.json"
$DEFAULT_DIR  = [System.IO.Path]::Combine($env:USERPROFILE, "Documents", "Escape from Tarkov", "Screenshots")
$COORD_PATTERN = '_(-?[\d]+\.[\d]+, -?[\d]+\.[\d]+, -?[\d]+\.[\d]+)_(-?[\d.]+, -?[\d.]+, -?[\d.]+, -?[\d.]+)_([\d.]+) \('

function Load-Config {
    $d = @{ screenshot_dir = $DEFAULT_DIR }
    if (Test-Path $CONFIG_FILE) {
        try {
            $s = Get-Content $CONFIG_FILE -Raw | ConvertFrom-Json
            if ($s.screenshot_dir -and $s.screenshot_dir.Trim() -ne "") {
                $d.screenshot_dir = $s.screenshot_dir
            }
        } catch {}
    }
    return $d
}

function Save-Config($cfg) {
    [PSCustomObject]@{ screenshot_dir = $cfg.screenshot_dir } | ConvertTo-Json | Set-Content $CONFIG_FILE
}

function New-FakePng($dir, $coords, $rotation, $speed) {
    $ts   = Get-Date -Format 'yyyy-MM-dd[HH-mm-ss]'
    $name = "${ts}_${coords}_${rotation}_${speed} (0).png"
    $path = Join-Path $dir $name
    if (Test-Path $path) { return $false }
    try {
        $bmp = New-Object System.Drawing.Bitmap(1, 1)
        $bmp.SetPixel(0, 0, [System.Drawing.Color]::Black)
        $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        return $true
    } catch { return $false }
}

function Purge-Old($dir) {
    $cutoff = (Get-Date).AddSeconds(-30)
    $count  = 0
    try {
        Get-ChildItem -Path $dir -File -ErrorAction Stop |
            Where-Object {
                ($_.Extension -eq '.png' -or $_.Extension -eq '.jpg' -or $_.Extension -eq '.jpeg') -and
                $_.LastWriteTime -lt $cutoff
            } |
            ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue; $count++ }
    } catch {}
    return $count
}

Clear-Host
Write-Host ""
Write-Host "  Tarkov Auto-Screenshot" -ForegroundColor Yellow
Write-Host "  ----------------------" -ForegroundColor DarkYellow
Write-Host ""

$cfg = Load-Config

if (-not (Test-Path $cfg.screenshot_dir)) {
    Write-Host "  NOTE: The saved folder doesn't exist on this machine." -ForegroundColor Red
    Write-Host "  Default EFT location: $DEFAULT_DIR" -ForegroundColor DarkGray
    Write-Host ""
}

Write-Host "  Screenshot folder (press Enter to keep, or type a new path)" -ForegroundColor Cyan
Write-Host "  Current: $($cfg.screenshot_dir)" -ForegroundColor Gray
$in = Read-Host "  Path"
if ($in.Trim() -ne "") {
    $cfg.screenshot_dir = $in.Trim().Trim('"')
}

if (-not (Test-Path $cfg.screenshot_dir)) {
    try {
        New-Item -ItemType Directory -Path $cfg.screenshot_dir -Force | Out-Null
        Write-Host "  Folder created." -ForegroundColor DarkGray
    } catch {
        Write-Host ""
        Write-Host "  ERROR: Cannot create folder: $($cfg.screenshot_dir)" -ForegroundColor Red
        Write-Host "  Check the path and try again." -ForegroundColor Red
        Write-Host ""
        Read-Host "  Press Enter to exit"
        exit 1
    }
}

Save-Config $cfg

Write-Host ""
Write-Host "  ----------------------" -ForegroundColor DarkYellow
Write-Host "  Folder : $($cfg.screenshot_dir)" -ForegroundColor White
Write-Host "  ----------------------" -ForegroundColor DarkYellow
Write-Host ""
Write-Host "  When you load into a map, press your EFT screenshot key ONCE." -ForegroundColor Yellow
Write-Host "  This tool will handle the rest silently." -ForegroundColor Gray
Write-Host ""
Write-Host "  SPACE : pause / resume    Ctrl+C : quit" -ForegroundColor DarkGray
Write-Host ""

$global:coords       = $null
$global:rotation     = $null
$global:speed        = $null
$global:coordUpdated = $false

$seed = Get-ChildItem -Path $cfg.screenshot_dir -Filter "*.png" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match $COORD_PATTERN } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if ($seed) {
    if ($seed.Name -match $COORD_PATTERN) {
        $global:coords   = $Matches[1]
        $global:rotation = $Matches[2]
        $global:speed    = $Matches[3]
        $global:coordUpdated = $true
        Write-Host "  [READY]  Picked up coordinates from existing screenshot." -ForegroundColor DarkGray
    }
}

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path                = $cfg.screenshot_dir
$watcher.Filter              = "*.png"
$watcher.NotifyFilter        = [System.IO.NotifyFilters]::FileName
$watcher.EnableRaisingEvents = $true

Register-ObjectEvent -InputObject $watcher -EventName "Created" -SourceIdentifier "EftScreenshot" -Action {
    $name = $Event.SourceEventArgs.Name
    if ($name -match '_(-?[\d]+\.[\d]+, -?[\d]+\.[\d]+, -?[\d]+\.[\d]+)_(-?[\d.]+, -?[\d.]+, -?[\d.]+, -?[\d.]+)_([\d.]+) \(') {
        $global:coords       = $Matches[1]
        $global:rotation     = $Matches[2]
        $global:speed        = $Matches[3]
        $global:coordUpdated = $true
    }
} | Out-Null

$paused    = $false
$generated = 0
$deleted   = 0

try {
    while ($true) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq [ConsoleKey]::Spacebar) {
                $paused = -not $paused
                $label  = if ($paused) { "PAUSED  (press Space to resume)" } else { "RESUMED" }
                Write-Host "  [$(Get-Date -Format 'HH:mm:ss')]  $label" -ForegroundColor Yellow
            }
        }

        if ($global:coordUpdated) {
            $global:coordUpdated = $false
            Write-Host "  [$(Get-Date -Format 'HH:mm:ss')]  Position updated: $($global:coords)" -ForegroundColor Cyan
        }

        if (-not $paused) {
            if ($global:coords) {
                $ok = New-FakePng $cfg.screenshot_dir $global:coords $global:rotation $global:speed
                if ($ok) { $generated++ }
                $d = Purge-Old $cfg.screenshot_dir
                $deleted += $d
                Write-Host "  [$(Get-Date -Format 'HH:mm:ss')]  Running  |  Generated: $generated  Cleaned: $deleted" -ForegroundColor DarkGray
            } else {
                Write-Host "  [$(Get-Date -Format 'HH:mm:ss')]  Waiting... Press your EFT screenshot key once in-game to start." -ForegroundColor Yellow
            }
        }

        Start-Sleep -Seconds 2
    }
} finally {
    Unregister-Event -SourceIdentifier "EftScreenshot" -ErrorAction SilentlyContinue
    $watcher.EnableRaisingEvents = $false
    $watcher.Dispose()
}
