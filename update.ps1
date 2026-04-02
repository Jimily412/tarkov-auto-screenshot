# Tarkov Auto-Screenshot — Auto Updater
# Called automatically by run.bat before the main script launches.
# Checks GitHub for a newer version, downloads it silently if found.
# On network failure or timeout, continues with the installed version.
# Previous version is always backed up so you can roll back instantly.

$REPO_RAW  = "https://raw.githubusercontent.com/jimily412/tarkov-auto-screenshot/main"
$SCRIPT    = Join-Path $PSScriptRoot "tarkov_auto_screenshot.ps1"
$BACKUP    = Join-Path $PSScriptRoot "tarkov_auto_screenshot.bak.ps1"
$LOCAL_VER = Join-Path $PSScriptRoot "version.txt"

Write-Host ""
Write-Host "  Checking for updates..." -ForegroundColor DarkGray

$local = if (Test-Path $LOCAL_VER) { (Get-Content $LOCAL_VER -Raw).Trim() } else { "0" }

try {
    $remote = (Invoke-WebRequest -Uri "$REPO_RAW/version.txt" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop).Content.Trim()

    if ($remote -eq $local) {
        Write-Host "  Up to date (v$local)" -ForegroundColor DarkGray
    } else {
        Write-Host "  New version available: v$remote  (installed: v$local)" -ForegroundColor Cyan
        Write-Host "  Downloading update..." -ForegroundColor DarkGray

        $newContent = (Invoke-WebRequest -Uri "$REPO_RAW/tarkov_auto_screenshot.ps1" -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop).Content

        # Back up the currently installed version
        if (Test-Path $SCRIPT) {
            Copy-Item $SCRIPT $BACKUP -Force
        }

        # Write the new version
        [System.IO.File]::WriteAllText($SCRIPT, $newContent, [System.Text.Encoding]::UTF8)

        # Record the new version
        Set-Content -Path $LOCAL_VER -Value $remote -Encoding UTF8

        Write-Host "  Updated to v$remote  (previous version saved as .bak for rollback)" -ForegroundColor Green
    }
} catch {
    Write-Host "  Could not reach update server — running installed version." -ForegroundColor DarkGray
}

Write-Host ""
