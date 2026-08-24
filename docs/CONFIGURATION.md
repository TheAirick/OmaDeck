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

Hyprland must map the touchscreen input device to OmaDeck's output. OmaDeck
deliberately does not move the software mouse pointer during touch actions.
Confirm device and output names with:

```bash
hyprctl devices
hyprctl monitors
```

Configure input-to-output mapping through your normal Omarchy or Hyprland
monitor configuration.

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
