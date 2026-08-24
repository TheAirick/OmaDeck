# Configuration

OmaDeck now has a touch-friendly settings sheet for its Clock/Weather card.
Monitor selection and launcher entries remain source-level options.

## Clock and weather

Tap the gear in the upper-right of the Clock/Weather card. The sheet controls:

- Hero, Split, or Compact clock layout
- 12- or 24-hour time and optional seconds
- Weather visibility and manual refresh
- Rich, Glyph, or Minimal weather visuals
- Compact current conditions, Standard two-day forecast, or Full three-day forecast
- Fahrenheit or Celsius

These choices are saved atomically to
`~/.config/omadeck/appearance.json`. Removing that file restores the defaults.
The selected weather detail is a maximum: OmaDeck temporarily removes forecast,
location, or secondary stats when a drawer or edited split leaves too little
room, then restores them automatically as the card expands.

OmaDeck deliberately shares Omarchy's weather location instead of keeping a
second copy. Choose **Set in Omarchy** from the settings sheet, or run:

```bash
omarchy-weather-location --set "Seattle" "47.6062,-122.3321"
```

Omit coordinates to let the provider resolve a city name. Run
`omarchy-weather-location --clear` to return to automatic IP-based location.
Location and forecast requests use the same public `wttr.in` and Open-Meteo
services as Omarchy's built-in weather panel. A saved location name or
coordinates, or the network-derived IP location, is therefore sent to those
providers when weather is enabled.

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

Clock and weather preferences are stored separately in
`~/.config/omadeck/appearance.json`, so rearranging the layout never resets
appearance choices.

## Theme behavior

OmaDeck consumes Omarchy's live `Color`, `Style`, and `Border` tokens. Changing
the Omarchy theme updates OmaDeck automatically; there is no separate theme.
