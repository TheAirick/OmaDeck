# Configuration

OmaDeck keeps configuration off the deck surface so its touch display stays
focused on primary navigation. Monitor selection and launcher entries remain
source-level options.

## Clock and weather

Open the OmaDeck taskbar icon's menu on the primary desktop and choose
**Clock & weather settings…**. The single settings panel controls:

- The saved Hero, Split, or Compact clock preference (retained for rollback and
  compatibility); the Clock + Weather/Timer companion surface currently uses
  the accepted compact Clock presentation
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

The Clock leaf always keeps a compact Clock above one lower companion. Weather
occupies that lower region while the countdown is idle; tapping the Clock opens
Timer setup there, and active, paused, and completed timers remain there until
cancelled or dismissed. A direct Clock/Command Center split may render the Clock
at a `0.36` minimum share for touch-safe companion geometry. This is a
presentation guard only: a narrower saved ratio and the exact `layout.json`
topology remain unchanged.

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

## Media and Volume

Now Playing is a permanent dashboard card beside Clock/Weather and Command
Center. Pull right from the left edge to reveal the separate Volume drawer;
reverse-swipe its inner edge to hide it. Expanding Volume changes only the
drawer width and never removes or recreates the Now Playing presenter.

## Application launcher

Tap **Applications** in Command Center to replace its home controls with the
launcher page. **Add** opens Omarchy's installed application library followed
by OmaDeck's curated shortcut catalog.
**Arrange** lets a selected tile move left, move right, or be removed; a long
press on a launcher tile enters the same mode. These choices are stored
atomically in `~/.config/omadeck/launcher.json` as stable catalog IDs. Removing
that file restores the six default applications.

Application entries define a desktop ID, label, monochrome glyph, and matching
Hyprland classes. Class aliases let OmaDeck focus a running window before
launching a new instance. Shortcut entries call only built-in OmaDeck actions;
the persisted file cannot add arbitrary executable commands.

## Vertical overlays

Pull down from the top edge to open Notification Center. It combines live
notifications from Omarchy's existing notification service with that service's
bounded recent history. Live entries retain their normal click action; archived
entries focus their sending application. **Clear all** clears live popups and
recorded history. The left control rail exposes native **Focus**, **Wi-Fi**,
**Bluetooth**, and **Night Light** toggles plus routes to OmaDeck's Network and
Audio panels. A missing Wi-Fi or Bluetooth adapter is shown as unavailable
rather than presenting a control that cannot work.

Pull up from the bottom edge to open OmaDeck Overview. The left side focuses
workspaces on `primaryMonitor`; the right side toggles Omarchy's native
`special:scratchpad`, parks the last focused window there, or opens clipboard
controls. Neither overlay changes the dimensions or layout of the dashboard
underneath it. If the Volume or System drawer was open before the vertical
gesture, it remains open behind the overlay and is restored unchanged when the
overlay closes.

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

Command Center launcher choices are stored independently in
`~/.config/omadeck/launcher.json`. Invalid or unknown catalog entries are
dropped; invalid files recover to the default launcher set.

The Clock's single countdown is stored atomically in
`~/.config/omadeck/timer.json`. Active, paused, and completed countdowns recover
after a plugin rescan or shell recreation. Removing the file while no timer is
needed resets the countdown to idle; invalid state also fails closed to idle.

The timer's selected Freedesktop sound event is stored independently and
atomically in `~/.config/omadeck/timer-settings.json`. Missing, corrupt, or
unsupported settings are repaired to **Complete** without changing countdown
state. The setup sheet only accepts OmaDeck's curated events; **Silent** stores
an empty event ID and suppresses completion playback.

## Theme behavior

OmaDeck consumes Omarchy's live `Color`, `Style`, and `Border` tokens. Changing
the Omarchy theme updates OmaDeck automatically; there is no separate theme.
