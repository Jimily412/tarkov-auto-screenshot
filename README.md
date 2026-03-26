# Tarkov Auto-Screenshot

Automatically presses your in-game screenshot key on a set interval so [Tarkov Questie](https://tarkovquestie.com) always has a fresh screenshot to read your position from — no manual pressing required. Screenshots older than 30 seconds are deleted automatically to keep the folder clean.

Works with Questie's team tracking feature: run this on every squad member's PC and everyone's position stays current on the shared map.

---

## How it works

Escape from Tarkov saves a screenshot to your `Documents\Escape from Tarkov\Screenshots` folder every time you press your screenshot key. Tarkov Questie watches that folder and reads each new screenshot to update your position on the interactive map.

This tool simply presses that key for you automatically.

---

## Installation

**Requirements:** Python 3.8+

1. Install Python from https://python.org if you don't have it (check "Add to PATH" during install)
2. Download this repository as a ZIP (green **Code** button → **Download ZIP**)
3. Extract the ZIP anywhere (Desktop is fine)
4. Double-click **run.bat** — it installs the dependency and launches the app automatically

---

## Setup (first run)

1. Open Tarkov Questie and note which folder it is watching
2. Launch the app via `run.bat`
3. Click **Browse…** and select the same folder Questie is watching
   - Default: `C:\Users\<you>\Documents\Escape from Tarkov\Screenshots`
4. Set your **interval** (5 seconds works well)
5. Set your **screenshot key** to match what is bound in EFT settings
6. Click **Start** — the app presses the key automatically from that point on

Your settings are saved in `config.json` and restored on next launch.

---

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| Screenshot Folder | `Documents\Escape from Tarkov\Screenshots` | Must match the folder EFT saves to and Questie watches |
| Interval | `5` seconds | How often to press the screenshot key |
| Screenshot Key | `home` | Must match your EFT screenshot keybind |

### Valid key names

| You type | Key |
|----------|-----|
| `home` | Home key |
| `print_screen` | Print Screen |
| `f1` – `f12` | Function keys |
| `scroll_lock` | Scroll Lock |
| `insert` | Insert |
| Any single letter | That letter key |

---

## For your squad

Each player runs this app on their own PC pointed at their own EFT screenshots folder.
In Tarkov Questie, use the **Team** / session-sharing feature to link everyone to the same session — each player's position updates automatically as screenshots come in.

---

## Notes

- The app must be running while you are in a raid
- Screenshots older than 30 seconds are deleted automatically — disk usage stays near zero
- If Questie loses your position, try lowering the interval (e.g. `3` seconds)
