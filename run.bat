@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0update.ps1"
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0tarkov_auto_screenshot.ps1"
pause
