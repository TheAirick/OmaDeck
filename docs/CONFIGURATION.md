# Configuration

OmaDeck does not yet have a settings interface. These options are currently
source-level defaults; a persistent settings model is planned.

## Monitor names

Find Hyprland's monitor names with `hyprctl monitors`. The current defaults live
in `Service.qml`:

```qml
property string targetScreen: "DP-3"
property string primaryMonitor: "DP-1"
```

`targetScreen` displays OmaDeck. `primaryMonitor` receives workspace and
application actions.

## Touch mapping

OmaDeck's native bridge discovers a direct touchscreen, prefers devices named
WCH.CN or XENEON, exclusively grabs its evdev node, and injects events only into
the deck window. This prevents touch from moving the desktop mouse pointer or
activating windows on another monitor.

The logged-in user must be able to read the touchscreen event node. Confirm the
device and the bridge state with:

```bash
./scripts/omadeck-doctor
```

The bridge automatically retries once per second when suspend or a USB reset
temporarily removes the device.

## System tray

OmaDeck launches a small system-tray controller with the service. Click its
icon from the primary desktop to open the OmaDeck Control Center, inspect touch
and monitor health, copy a sanitized report, request a touch reconnect, or
restart the Omarchy shell. This path does not require the deck touchscreen.

The tray is built by `scripts/build-native`. If the tray is missing, rebuild and
restart the shell.

## Application launcher

Entries live in `modules/AppLauncherModule.qml`. Each defines a desktop ID,
label, monochrome glyph, and matching Hyprland classes. Class aliases let
OmaDeck focus a running window before launching a new instance. Touch-based
launcher editing is on the roadmap.

## Monitor input commands

`modules/MonitorInputModule.qml` expects executable scripts at:

```text
~/.local/bin/alienware-to-omarchy
~/.local/bin/alienware-to-mac
```

They may call `ddcutil`, a vendor tool, or any monitor-specific command. Exit
status `0` reports success; another status reports failure.

## Saved layout

The center split tree is stored at `~/.config/omadeck/layout.json`. Removing it
recreates the default Clock/Command Center layout and resets saved positions and
ratios.

## Theme behavior

OmaDeck consumes Omarchy's live `Color`, `Style`, and `Border` tokens. Changing
the Omarchy theme updates OmaDeck automatically; there is no separate theme.
