# Tarkov Auto-Screenshot

Keeps [Tarkov Questie](https://tarkovquestie.com) updated with your position — silently, with no popups, and no interference with anything else on your PC.

**No installation required.** Uses PowerShell which is built into Windows 10/11.

---

## How it works

EFT embeds your exact map coordinates in every screenshot filename (e.g. `..._-519.33, -39.61, 68.41_...png`). Tarkov Questie reads those coordinates to place you on the map — it never looks at the image itself.

This tool:
1. Watches your screenshot folder for real EFT screenshots you take manually
2. Extracts the coordinates from the filename the moment a new file appears
3. Generates tiny silent 1×1 pixel PNGs every 2 seconds with those coordinates
4. Deletes files older than 30 seconds automatically

**Zero keypresses to EFT. Zero popups. Zero effect on typing or other apps.**

---

## How to run

1. Download ZIP → green **Code** button → **Download ZIP**
2. Extract anywhere
3. Double-click **run.bat**

---

## Setup (first run on each PC)

The script will ask for your **screenshot folder** — press Enter to use the default:

```
C:\Users\<you>\Documents\Escape from Tarkov\Screenshots
```

If EFT saves screenshots somewhere else on your machine, paste that path.
Settings are saved to `config.json` so you only need to do this once.

---

## In-game

When you **load into a raid**, press your EFT screenshot key **once**.
The tool picks up your coordinates and runs silently from there.

Press it again any time you want to manually refresh your position marker on the squad map.

---

## For your squad

Each player runs this on their own PC. In Tarkov Questie use the **Team** session-sharing feature — everyone's position updates on the shared map automatically.

---

## Troubleshooting

**Questie isn't updating**
- Make sure the screenshot folder in setup matches where EFT actually saves screenshots
- Press your screenshot key at least once after loading into a map — the tool needs one real screenshot to read coordinates from

**Files aren't being deleted**
- Confirm the screenshot folder path is correct (it must be the same folder EFT saves to)
- The tool only deletes files it can see in the configured folder

**SPACE** — pause / resume  
**Ctrl+C** — quit
