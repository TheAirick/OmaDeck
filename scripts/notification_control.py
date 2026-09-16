#!/usr/bin/python3
"""Small, on-demand bridge to Omarchy's public notification/night-light commands."""
from __future__ import annotations
import json
import os
import re
import shutil
import subprocess
import sys

SAFE_PATH = "/usr/bin:/usr/share/omarchy/bin"


def run_command(name: str, *args: str) -> str:
    command = shutil.which(name, path=SAFE_PATH)
    if not command:
        raise RuntimeError("Command unavailable")
    result = subprocess.run([command, *args], env={**os.environ, "PATH": SAFE_PATH},
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                            timeout=3, check=True, text=True)
    if len(result.stdout) > 4096:
        raise RuntimeError("Unexpected command response")
    return result.stdout.strip()


def status() -> dict:
    state = {"ok": True, "dndAvailable": False, "nightAvailable": False,
             "dnd": False, "night": False}
    try:
        value = run_command("omarchy-shell", "notifications", "dndState")
        state.update(dndAvailable=value in ("on", "off"), dnd=value == "on")
    except (OSError, RuntimeError, subprocess.SubprocessError):
        pass
    try:
        value = json.loads(run_command("omarchy-shell", "nightlight", "status"))
        if isinstance(value, dict) and isinstance(value.get("enabled"), bool):
            state.update(nightAvailable=True, night=value["enabled"])
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError):
        pass
    return state


def dispatch(action: str, value: str = "") -> dict:
    if action == "status":
        return status()
    if action in ("dnd", "night"):
        if value not in ("on", "off"):
            raise ValueError("Expected on or off")
        if action == "dnd":
            result = run_command("omarchy-shell", "notifications", "setDnd", value)
            if result != value:
                raise RuntimeError("Focus change was not confirmed")
        else:
            result = run_command("omarchy-shell", "nightlight", "enable" if value == "on" else "disable")
            if result != ("enabled" if value == "on" else "disabled"):
                raise RuntimeError("Night Light change was not confirmed")
        return {"ok": True}
    if action == "clear" and not value:
        # The shell serializes archiving before clearing its history. Never
        # unlink the owner's files or operate on a guessed popup index here.
        for method in ("dismissAll", "clear"):
            if run_command("omarchy-shell", "notifications", method) != "ok":
                raise RuntimeError("Clear was not confirmed")
        return {"ok": True}
    if action == "focus" and value and len(value) <= 256:
        # The installed helper accepts a regular expression: escape the app
        # identity so a notification cannot select an unrelated window.
        run_command("omarchy-hyprland-focus-app", re.escape(value))
        return {"ok": True}
    raise ValueError("Unsupported notification action")


def main() -> int:
    try:
        if not 2 <= len(sys.argv) <= 3:
            raise ValueError("Expected an action and optional value")
        result = dispatch(sys.argv[1], sys.argv[2] if len(sys.argv) == 3 else "")
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError):
        result = {"ok": False}
    print(json.dumps(result, separators=(",", ":")))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
