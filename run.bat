@echo off
:: Tarkov Auto-Screenshot Launcher
:: Double-click this file to install and run.

echo Checking for Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo.
    echo Python is not installed or not in PATH.
    echo Please download and install Python from https://python.org
    echo Make sure to check "Add Python to PATH" during installation.
    echo.
    pause
    exit /b 1
)

echo Installing dependencies...
python -m pip install -r requirements.txt -q

echo Starting Tarkov Auto-Screenshot...
python tarkov_auto_screenshot.py
