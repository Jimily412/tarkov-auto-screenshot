# Tarkov Auto-Screenshot

Silently captures your screen at a set interval so Tarkov Questie always has a fresh screenshot. No game popups, no sounds, no keypresses. Screenshots older than 30 seconds are deleted automatically.

Works with Questie's team feature — run this on every squad member's PC.

**No installation required.** Uses PowerShell which is built into Windows 10/11.

## How to run

1. Download ZIP (green Code button → Download ZIP)
2. Extract anywhere
3. Double-click run.bat

## First run setup

The script asks three questions — press Enter to keep the current value:

1. Screenshot folder — must match what Questie is watching (default: `C:\Users\<you>\Documents\Escape from Tarkov\Screenshots`)
2. Interval — how often to take a screenshot (default: 5 seconds)
3. Which screen — lists all monitors with resolutions so you can pick the one Tarkov is on

Settings saved to config.json. Press Ctrl+C to stop.
