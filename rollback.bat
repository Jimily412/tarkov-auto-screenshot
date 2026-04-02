@echo off
echo.
echo   Tarkov Auto-Screenshot -- Rollback
echo   -----------------------------------
echo.
if not exist "%~dp0tarkov_auto_screenshot.bak.ps1" (
    echo   No backup found. Nothing to roll back to.
    echo.
    pause
    exit /b 1
)
copy /Y "%~dp0tarkov_auto_screenshot.bak.ps1" "%~dp0tarkov_auto_screenshot.ps1" >nul
echo   Rolled back to previous version.
echo   Run run.bat to launch.
echo.
pause
