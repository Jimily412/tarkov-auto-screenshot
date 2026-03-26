#!/usr/bin/env python3
"""
Tarkov Auto-Screenshot
Automatically presses your screenshot key at a set interval so Tarkov Questie
always has a fresh screenshot to read your position from.

Questie watches your Escape from Tarkov screenshots folder:
  C:\Users\<you>\Documents\Escape from Tarkov\Screenshots

This tool:
  1. Simulates pressing your in-game screenshot key on your chosen interval
  2. Automatically deletes screenshots older than 30 seconds to avoid buildup

Setup: pip install -r requirements.txt
Run:   python tarkov_auto_screenshot.py
"""

import json
import os
import sys
import time
import threading
from pathlib import Path
from datetime import datetime, timedelta
import tkinter as tk
from tkinter import ttk, filedialog, messagebox

def _ensure(package, import_as=None):
    import importlib
    mod_name = import_as or package
    try:
        return importlib.import_module(mod_name)
    except ImportError:
        print(f"Installing {package}...")
        os.system(f'"{sys.executable}" -m pip install {package} -q')
        return importlib.import_module(mod_name)

_ensure("pynput", "pynput.keyboard")
from pynput import keyboard as pynput_keyboard

CONFIG_FILE = Path(__file__).parent / "config.json"

DEFAULT_CONFIG = {
    "screenshot_dir":   str(Path.home() / "Documents" / "Escape from Tarkov" / "Screenshots"),
    "interval_seconds": 5,
    "screenshot_key":   "home",
}

def load_config() -> dict:
    cfg = dict(DEFAULT_CONFIG)
    if CONFIG_FILE.exists():
        try:
            with open(CONFIG_FILE) as f:
                cfg.update(json.load(f))
        except Exception:
            pass
    return cfg

def save_config(cfg: dict):
    with open(CONFIG_FILE, "w") as f:
        json.dump(cfg, f, indent=4)

KEY_MAP = {
    "print_screen": pynput_keyboard.Key.print_screen,
    "printscreen":  pynput_keyboard.Key.print_screen,
    "f1":  pynput_keyboard.Key.f1,  "f2":  pynput_keyboard.Key.f2,
    "f3":  pynput_keyboard.Key.f3,  "f4":  pynput_keyboard.Key.f4,
    "f5":  pynput_keyboard.Key.f5,  "f6":  pynput_keyboard.Key.f6,
    "f7":  pynput_keyboard.Key.f7,  "f8":  pynput_keyboard.Key.f8,
    "f9":  pynput_keyboard.Key.f9,  "f10": pynput_keyboard.Key.f10,
    "f11": pynput_keyboard.Key.f11, "f12": pynput_keyboard.Key.f12,
    "scroll_lock": pynput_keyboard.Key.scroll_lock,
    "pause":  pynput_keyboard.Key.pause,
    "insert": pynput_keyboard.Key.insert,
    "home":   pynput_keyboard.Key.home,
    "end":    pynput_keyboard.Key.end,
    "delete": pynput_keyboard.Key.delete,
}

def parse_key(key_str: str):
    s = key_str.strip().lower()
    if s in KEY_MAP:
        return KEY_MAP[s]
    if len(s) == 1:
        return pynput_keyboard.KeyCode.from_char(s)
    return pynput_keyboard.Key.print_screen

_kb = pynput_keyboard.Controller()

def press_key(key):
    _kb.press(key)
    time.sleep(0.05)
    _kb.release(key)

KEEP_SECONDS = 30

def purge_old_screenshots(directory: Path) -> int:
    cutoff = datetime.now() - timedelta(seconds=KEEP_SECONDS)
    deleted = 0
    for ext in ("*.png", "*.jpg", "*.jpeg"):
        for f in directory.glob(ext):
            try:
                if datetime.fromtimestamp(f.stat().st_mtime) < cutoff:
                    f.unlink()
                    deleted += 1
            except OSError:
                pass
    return deleted

class ScreenshotWorker:
    def __init__(self):
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self.running = False
        self.last_status = ""
        self.shot_count = 0
        self.del_count = 0
        self.on_tick: callable = None

    def start(self, key, interval: float, directory: Path):
        self._stop.clear()
        self.running = True
        self._thread = threading.Thread(
            target=self._loop,
            args=(key, interval, directory),
            daemon=True,
        )
        self._thread.start()

    def stop(self):
        self._stop.set()
        self.running = False

    def _loop(self, key, interval: float, directory: Path):
        while not self._stop.is_set():
            try:
                press_key(key)
                self.shot_count += 1
                deleted = purge_old_screenshots(directory)
                self.del_count += deleted
                self.last_status = (
                    f"[{datetime.now().strftime('%H:%M:%S')}]  "
                    f"Screenshots taken: {self.shot_count}   "
                    f"Deleted: {self.del_count}"
                )
                if self.on_tick:
                    self.on_tick(self.last_status)
            except Exception as e:
                self.last_status = f"Error: {e}"
                if self.on_tick:
                    self.on_tick(self.last_status)
            self._stop.wait(timeout=interval)

class App(tk.Tk):
    PAD = 12

    def __init__(self):
        super().__init__()
        self.title("Tarkov Auto-Screenshot")
        self.resizable(False, False)
        self.configure(bg="#1e1e1e")
        self.cfg = load_config()
        self.worker = ScreenshotWorker()
        self.worker.on_tick = self._on_tick
        self._build_ui()
        self.protocol("WM_DELETE_WINDOW", self._on_close)

    def _build_ui(self):
        p = self.PAD
        bg   = "#1e1e1e"
        fg   = "#e0e0e0"
        acc  = "#c8aa6e"
        dark = "#2a2a2a"

        style = ttk.Style(self)
        style.theme_use("clam")
        style.configure("TLabel",      background=bg, foreground=fg, font=("Segoe UI", 10))
        style.configure("TEntry",      fieldbackground=dark, foreground=fg, insertcolor=fg)
        style.configure("TButton",     background=dark, foreground=fg, borderwidth=0, padding=6)
        style.map("TButton",           background=[("active", "#3a3a3a")])
        style.configure("Start.TButton", background="#2d5a27", foreground="#90ee90")
        style.map("Start.TButton",       background=[("active", "#3a7033")])
        style.configure("Stop.TButton",  background="#5a2727", foreground="#ee9090")
        style.map("Stop.TButton",        background=[("active", "#703333")])

        outer = tk.Frame(self, bg=bg, padx=p, pady=p)
        outer.pack(fill="both", expand=True)

        tk.Label(outer, text="Tarkov Auto-Screenshot",
                 bg=bg, fg=acc, font=("Segoe UI", 14, "bold")).pack(anchor="w", pady=(0, 8))
        tk.Label(outer, text="Automatically presses your screenshot key so Questie always\n"
                             "has a fresh position. Screenshots older than 30 s are deleted.",
                 bg=bg, fg="#888", font=("Segoe UI", 9), justify="left").pack(anchor="w", pady=(0, p))
        ttk.Separator(outer).pack(fill="x", pady=(0, p))

        tk.Label(outer, text="Screenshot Folder", bg=bg, fg=acc,
                 font=("Segoe UI", 10, "bold")).pack(anchor="w")
        tk.Label(outer, text="Must match Escape from Tarkov → Settings → Screenshot path",
                 bg=bg, fg="#666", font=("Segoe UI", 8)).pack(anchor="w")

        dir_row = tk.Frame(outer, bg=bg)
        dir_row.pack(fill="x", pady=(4, p))
        self.dir_var = tk.StringVar(value=self.cfg["screenshot_dir"])
        ttk.Entry(dir_row, textvariable=self.dir_var, width=46).pack(side="left", fill="x", expand=True)
        ttk.Button(dir_row, text="Browse…", command=self._browse).pack(side="left", padx=(6, 0))

        tk.Label(outer, text="Interval (seconds)", bg=bg, fg=acc,
                 font=("Segoe UI", 10, "bold")).pack(anchor="w")
        tk.Label(outer, text="How often to press the screenshot key (2–30 s recommended)",
                 bg=bg, fg="#666", font=("Segoe UI", 8)).pack(anchor="w")
        interval_row = tk.Frame(outer, bg=bg)
        interval_row.pack(fill="x", pady=(4, p))
        self.interval_var = tk.StringVar(value=str(self.cfg["interval_seconds"]))
        ttk.Entry(interval_row, textvariable=self.interval_var, width=8).pack(side="left")
        tk.Label(interval_row, text="s", bg=bg, fg=fg).pack(side="left", padx=4)

        tk.Label(outer, text="Screenshot Key", bg=bg, fg=acc,
                 font=("Segoe UI", 10, "bold")).pack(anchor="w")
        tk.Label(outer, text='Match what is set in EFT keybindings (e.g. home, print_screen, f12)',
                 bg=bg, fg="#666", font=("Segoe UI", 8)).pack(anchor="w")
        self.key_var = tk.StringVar(value=self.cfg["screenshot_key"])
        ttk.Entry(outer, textvariable=self.key_var, width=20).pack(anchor="w", pady=(4, p))

        ttk.Separator(outer).pack(fill="x", pady=(0, p))

        btn_row = tk.Frame(outer, bg=bg)
        btn_row.pack(fill="x", pady=(0, p))
        self.start_btn = ttk.Button(btn_row, text="▶  Start", style="Start.TButton", command=self._start)
        self.start_btn.pack(side="left", padx=(0, 8))
        self.stop_btn = ttk.Button(btn_row, text="■  Stop", style="Stop.TButton", command=self._stop, state="disabled")
        self.stop_btn.pack(side="left")

        self.status_var = tk.StringVar(value="Stopped — configure above and press Start.")
        tk.Label(outer, textvariable=self.status_var,
                 bg=dark, fg="#aaa", font=("Consolas", 9),
                 anchor="w", padx=8, pady=6, relief="flat").pack(fill="x")

    def _browse(self):
        path = filedialog.askdirectory(
            title="Select Escape from Tarkov Screenshot Folder",
            initialdir=self.dir_var.get() or str(Path.home()),
        )
        if path:
            self.dir_var.set(path)

    def _start(self):
        directory = Path(self.dir_var.get().strip())
        if not directory.exists():
            try:
                directory.mkdir(parents=True)
            except Exception as e:
                messagebox.showerror("Bad folder", f"Cannot create folder:\n{e}")
                return
        try:
            interval = float(self.interval_var.get())
            assert interval > 0
        except Exception:
            messagebox.showerror("Bad interval", "Interval must be a number greater than 0.")
            return
        key_str = self.key_var.get().strip()
        if not key_str:
            messagebox.showerror("No key", "Please enter a screenshot key (e.g. print_screen).")
            return
        key = parse_key(key_str)
        self.cfg.update({
            "screenshot_dir":   str(directory),
            "interval_seconds": interval,
            "screenshot_key":   key_str,
        })
        save_config(self.cfg)
        self.worker.shot_count = 0
        self.worker.del_count  = 0
        self.worker.start(key, interval, directory)
        self.start_btn.config(state="disabled")
        self.stop_btn.config(state="normal")
        self.status_var.set(f"Running — pressing [{key_str.upper()}] every {interval}s  |  folder: {directory}")

    def _stop(self):
        self.worker.stop()
        self.start_btn.config(state="normal")
        self.stop_btn.config(state="disabled")
        self.status_var.set("Stopped.")

    def _on_tick(self, msg: str):
        self.after(0, lambda: self.status_var.set(msg))

    def _on_close(self):
        self.worker.stop()
        self.destroy()

if __name__ == "__main__":
    app = App()
    app.mainloop()
