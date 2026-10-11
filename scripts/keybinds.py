#!/usr/bin/env python3
"""Chuleta de atajos (SUPER+H): lee los binds en vivo de Hyprland y los muestra en rofi."""
import json
import subprocess

MODS = [(64, "󰖳"), (4, "CTRL"), (8, "ALT"), (1, "SHIFT")]
KEYS = {"Return": "󰌑", "SPACE": "󱁐", "TAB": "󰌒", "ESCAPE": "ESC", "Print": "PRINT",
        "left": "←", "right": "→", "up": "↑", "down": "↓",
        "mouse:272": "󰍽 izq", "mouse:273": "󰍽 der", "mouse_down": "󰍽 rueda↓", "mouse_up": "󰍽 rueda↑"}

if subprocess.run(["pkill", "-x", "rofi"]).returncode == 0:
    raise SystemExit  # SUPER+H con la chuleta abierta la cierra

binds = json.loads(subprocess.run(["hyprctl", "binds", "-j"], capture_output=True, text=True).stdout)
rows, seen = [], set()
for b in binds:
    desc = b.get("description") or ""
    key = b["key"]
    if key.startswith("XF86") or (b["modmask"] == 0 and key.startswith("mouse")):
        continue  # teclas multimedia y clics sin modificador (reglas internas, no atajos)
    combo = " + ".join([sym for bit, sym in MODS if b["modmask"] & bit] + [KEYS.get(key, key.upper())])
    if (combo, desc) in seen:
        continue
    seen.add((combo, desc))
    rows.append(f"<span foreground='#00ffc8'><b>{combo:<22}</b></span>  {desc}")

subprocess.run(
    ["rofi", "-dmenu", "-i", "-markup-rows", "-p", "󰌌  atajos", "-no-custom",
     "-theme-str", "window { width: 760px; } listview { lines: 14; } element-icon { enabled: false; }"],
    input="\n".join(rows), text=True,
)
