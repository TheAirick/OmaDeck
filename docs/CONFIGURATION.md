# Configuration

OmaDeck keeps configuration off the deck surface so its touch display stays
focused on primary navigation. Monitor selection and launcher entries remain
source-level options.

## Clock and weather

Open the OmaDeck taskbar icon's menu on the primary desktop and choose
**Clock & weather settings…**. The single settings panel controls:

- Hero, Split, or Compact clock layout
- 12- or 24-hour time and optional seconds
- Weather visibility and manual refresh. Choosing **Hidden** is a privacy
  opt-out: OmaDeck stops weather refreshes, retry work, and location polling,
  and does not start weather provider requests until weather is shown again.
- Rich, Glyph, or Minimal weather visuals
- Compact current conditions, Standard two-day forecast, or Full three-day forecast
- Fahrenheit or Celsius

These choices are saved atomically to
`~/.config/omadeck/appearance.json`. Removing that file restores the defaults.
The selected weather detail is a maximum: OmaDeck temporarily removes forecast,
location, or secondary stats when a drawer or edited split leaves too little
room, then restores them automatically as the card expands.

OmaDeck deliberately shares Omarchy's weather location instead of keeping a
second copy. Choose **Weather location…** from the tray settings panel, or run:

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

OmaDeck's native bridge discovers a direct touchscreen whose evdev name contains
one of the explicitly configured identities, exclusively grabs that node, and
injects events only into the deck window. The defaults are `WCH.CN` and
`XENEON`. If neither identity is present, the bridge fails closed and leaves all
other touchscreens untouched instead of falling back to one of them. This
prevents touch from moving the desktop mouse pointer or activating windows on
another monitor without risking an unrelated laptop or pen display touchscreen.

The configured case-insensitive name substrings live beside the monitor options
in `Service.qml`:

```qml
property var touchDeviceNames: ["WCH.CN", "XENEON"]
```

Replace that list with one or more distinctive substrings reported for another
dedicated deck touchscreen. Do not use a generic value such as `Touchscreen`:
the matching identity is the safety boundary that authorizes the exclusive
grab. The same list is passed to the tray and doctor so their diagnosis reflects
the bridge configuration.

The logged-in user must be able to read the touchscreen event node. Confirm the
device and the bridge state with:

```bash
./scripts/omadeck-doctor
```

To diagnose a source-level custom identity directly, repeat
`--touch-device-name` as needed:

```bash
./scripts/omadeck-doctor --touch-device-name "ACME Deck 9000"
```

The bridge automatically retries once per second when suspend or a USB reset
temporarily removes the device.

For a dedicated Xeneon Edge, disconnect both of its normalized libinput views
from Hyprland so the compositor cannot race the bridge after a shell restart.
Add the names reported by `hyprctl devices` to `~/.config/hypr/input.lua`:

```lua
hl.device({
  name = "wch.cn-touchscreen",
  enabled = false,
})

hl.device({
  name = "wch.cn-touchscreen-1",
  enabled = false,
})
```

Reload with `hyprctl reload` and confirm `hyprctl configerrors` is empty. Other
touchscreen models can use different normalized names.

## System tray

OmaDeck launches a small system-tray controller with the service. Click its
icon from the primary desktop to open the OmaDeck Control Center, inspect touch
and monitor health, copy a sanitized report, request a touch reconnect, or
restart the Omarchy shell. Its context menu also owns the single
**Clock & weather settings…** panel; the deck surface does not duplicate those
controls. This path does not require the deck touchscreen.

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

The Clock's single countdown is stored atomically in
`~/.config/omadeck/timer.json`. Active, paused, and completed countdowns recover
after a plugin rescan or shell recreation. Removing the file while no timer is
needed resets the countdown to idle; invalid state also fails closed to idle.

## Theme behavior

OmaDeck consumes Omarchy's live `Color`, `Style`, and `Border` tokens. Changing
the Omarchy theme updates OmaDeck automatically; there is no separate theme.
