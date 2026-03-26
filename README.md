# Tarkov Auto-Screenshot

Automatically presses your EFT screenshot key on an interval so Tarkov Questie always has a fresh position update. No installation required — uses PowerShell built into Windows 10/11.

## How it works

When you press the screenshot key in EFT, the game saves a .png with your coordinates in the filename. Tarkov Questie reads those coordinates to place you on the map. This tool presses that key automatically.

## How to run

1. Download ZIP (green Code button → Download ZIP)
2. Extract anywhere
3. Double-click run.bat

## First run setup

Press Enter to keep current values:
1. Screenshot folder — where EFT saves screenshots (default: `C:\Users\<you>\Documents\Escape from Tarkov\Screenshots`)
2. Interval — how often to press the key (default: 5 seconds)
3. Screenshot key — must match your EFT keybind (default: home)

Settings saved to config.json. Press Ctrl+C to stop.

## Silencing the screenshot sound/popup

The sound comes from EFT, not this tool. Disable it in EFT Settings → Sound → screenshot notification.

## Valid key names
home, print_screen, f1-f12, insert, end, delete, scroll_lock, or any single letter
