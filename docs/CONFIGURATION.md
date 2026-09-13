# Configuration

OmaDeck keeps configuration behind the Command Center's **Preferences** page so
its normal touch surface stays focused on primary navigation.

## Clock and weather

Open **Preferences** from OmaDeck's Command Center, or open the OmaDeck
taskbar icon's menu on the primary desktop and choose **Clock & weather
settings…**. Both surfaces use the same validated controller for:

- 12- or 24-hour time and optional seconds
- Weather visibility and manual refresh. Choosing **Hidden** is a privacy
  opt-out: OmaDeck stops weather refreshes, retry work, and location polling,
  and does not start weather provider requests until weather is shown again.
- Rich, Glyph, or Minimal weather visuals
- Compact current conditions, Standard two-day forecast, or Full three-day forecast
- Fahrenheit or Celsius

The OmaDeck Preferences page also selects and previews the timer completion
sound through the timer's existing allowlisted, atomically persisted sound
controller.

## OmaDeck preferences

Preferences contains four app-specific categories:

- **Dashboard**: layout editing, clock format, weather visibility, style, detail,
  units, and refresh.
- **Timer**: completion sound selection and preview. **Ocean** is the default.
- **Display & touch**: OmaDeck's display, the monitor used for its application
  and workspace actions, and touchscreen selection/reconnection.
- **Launcher**: add, remove, and rearrange Command Center applications.

System themes, bar settings, keybindings, power, and broader Omarchy configuration
remain in Omarchy's own interface. The Command Center retains its everyday
Volume, System, Notifications, Overview, and Applications controls.

OmaDeck's Clock and Weather choices are saved atomically to
`~/.config/omadeck/appearance.json`. Removing that file restores the defaults.
The selected weather detail is a maximum: OmaDeck temporarily removes forecast,
location, or secondary stats when a drawer or edited split leaves too little
room, then restores them automatically as the card expands.

The Clock leaf keeps a Clock above one lower companion. Weather occupies that
lower region by default; tapping the Clock opens Timer setup or controls there.
Starting a timer returns to Weather, with ambient progress in the Clock; tapping
the Clock reopens controls. A direct Clock/Command Center split may render the Clock
at a `0.50` minimum share for touch-safe companion geometry. This is a
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

Open **Preferences → Display & touch**. **OmaDeck screen** chooses the connected output
that displays the dashboard; changing it moves OmaDeck immediately. **Primary
workspace monitor** chooses where workspace and application actions are sent.
The selectors use Quickshell's connected-screen model, so a stale or invented
output name cannot be saved from the UI. A fresh install prefers `DP-3` for
OmaDeck and `DP-1` for the primary workspace monitor. When those names are not
connected, it chooses a connected secondary display and primary display so the
dashboard is usable before configuration.

## Touch mapping

Standard installs use compositor-managed touch and need no local compilation.
Map the touchscreen to the selected output through Hyprland when its default
mapping is not correct.

Omarchy versions with a capability-scoped plugin API use this compositor
mode unless the optional [host input guard](../integrations/omarchy/README.md)
is installed in the enabled user-owned lock clone. It shares synchronous input
permission without exposing authentication services. Check `omarchy-shell
pretty.omadeck touchState` for `mode: compositor`. On Hyprland's Lua configuration,
the Xeneon Edge mapping can be set in `~/.config/hypr/input.lua`:

```lua
hl.device({ name = "wch.cn-touchscreen", enabled = true, output = "DP-3" })
-- Disable the separate mouse-emulation endpoint to avoid duplicate input.
hl.device({ name = "wch.cn-touchscreen-1", enabled = false })
```

Use the live device names from `hyprctl devices` and output from `hyprctl
monitors`; distinguish the `touch` endpoint from any companion `mice` endpoint.
Replace the older `enabled = false` rule for the actual touchscreen,
then run `hyprctl reload` and check `hyprctl configerrors`.

Compositor mode can lose deck taps while a game captures the mouse on Hyprland
0.56.2. For the verified Valheim workaround and optional native integration,
see [gameplay touch troubleshooting](TROUBLESHOOTING.md#touch-works-on-the-desktop-but-stops-during-gameplay).

The optional native integration provides stricter dedicated-screen routing.
It requires a synchronous lock-service guard or the optional host input guard. Build it with
`scripts/build-native` and restart the shell before using the
device selector and exclusive mapping below.

OmaDeck's native bridge discovers a direct touchscreen whose evdev name contains
one of the explicitly configured identities, exclusively grabs that node, and
injects events only into the deck window. The defaults are `WCH.CN` and
`XENEON`. If neither identity is present, the bridge fails closed and leaves all
other touchscreens untouched instead of falling back to one of them. This
prevents touch from moving the desktop mouse pointer or activating windows on
another monitor without risking an unrelated laptop or pen display touchscreen.

Open **Preferences → Display & touch** to choose from direct touchscreens that the native
bridge can currently open and verify. Saving a device records its exact evdev
name and reconnects the bridge. The initial fallback identities are `WCH.CN`
and `XENEON`; they allow first-run discovery without authorizing an unrelated
laptop touchscreen. Do not replace the saved identity with a generic value such
as `Touchscreen`: the match is the safety boundary that authorizes the exclusive
grab. The same setting is passed to the tray and doctor so their diagnosis
reflects the bridge configuration.

The logged-in user must be able to read the touchscreen event node. Confirm the
device and the bridge state with:

```bash
./scripts/omadeck-doctor
```

To diagnose a custom identity directly, repeat `--touch-device-name` as needed:

```bash
./scripts/omadeck-doctor --touch-device-name "ACME Deck 9000"
```

The bridge automatically retries once per second when suspend or a USB reset
temporarily removes the device.

Keep the actual touch endpoint enabled and mapped to the deck so compositor
fallback remains usable if the native bridge or lock guard is unavailable.
Disable only its separate mouse-emulation endpoint. Use the names reported by
`hyprctl devices` in `~/.config/hypr/input.lua`:

```lua
hl.device({
  name = "wch.cn-touchscreen",
  enabled = true,
  output = "DP-3",
})

hl.device({
  name = "wch.cn-touchscreen-1",
  enabled = false,
})
```

Reload with `hyprctl reload` and confirm `hyprctl configerrors` is empty. Other
touchscreen models can use different normalized names. An active native bridge
holds an exclusive grab, preventing duplicate delivery to the compositor.

## System tray

When the optional native integration is built, OmaDeck launches a small
system-tray controller with the service. Click its
icon from the primary desktop to open the OmaDeck Control Center, inspect touch
and monitor health, copy a sanitized report, request a touch reconnect, or
restart the Omarchy shell. Its context menu exposes **Clock & weather settings…**,
using the same controller as **Preferences → Dashboard**. This path does not
require the deck touchscreen.

The tray is intentionally absent in standard mode. If you want it, run
`scripts/build-native` and restart the shell.

## Media and Volume

Now Playing is a permanent dashboard card beside Clock/Weather and Command
Center. Pull right from the left edge to reveal the separate Volume drawer;
reverse-swipe its inner edge to hide it. Expanding Volume changes only the
drawer width and never removes or recreates the Now Playing presenter.

Tap the Volume drawer's chevron to expand it. The **Output** and **Mic** rows
show the current system devices; tap either row to choose a connected device.
The checkmark follows the actual system default, including changes made outside
OmaDeck. Output and microphone are selected independently. **Back** returns to
the mixer without switching. Device choices use Omarchy's native audio routing
commands, including moving current application streams; volumes and mute states
are left as they are. Applications that pin their own device may still require
their in-app audio setting. WirePlumber owns the saved defaults.

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

`modules/MonitorInputModule.qml` is an optional source-level module, not a
standard Command Center action. It expects executable scripts at:

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

Monitor and direct-touch choices are stored atomically in
`~/.config/omadeck/hardware.json`. A missing or invalid file prefers the safe
DP-3, DP-1, WCH.CN/XENEON defaults, then selects connected displays when those
outputs are unavailable. A saved target monitor that is temporarily
disconnected remains selected so OmaDeck returns to that display after hotplug.

The Clock's single countdown is stored atomically in
`~/.config/omadeck/timer.json`. Active, paused, and completed countdowns recover
after a plugin rescan or shell recreation. Removing the file while no timer is
needed resets the countdown to idle; invalid state also fails closed to idle.

The timer's selected sound ID is stored independently and atomically in
`~/.config/omadeck/timer-settings.json`. Missing, corrupt, or
unsupported settings are repaired to **Ocean** without changing countdown
state. Existing valid selections, including Silent, are preserved. Ocean plays
the bundled KDE Ocean `alarm-clock-elapsed.oga`; the other audible choices use
Freedesktop sound events from the system theme. See the bundled
[sound attribution and license](../assets/sounds/README.md).
The setup sheet only accepts OmaDeck's curated sound IDs; **Silent** stores
an empty event ID and suppresses completion playback.

## Theme behavior

OmaDeck consumes Omarchy's live `Color`, `Style`, and `Border` tokens. Changing
the Omarchy theme updates OmaDeck automatically; there is no separate theme.

Secondary labels use a shared contrast floor of **4.5:1** against their OmaDeck
panel. Already-readable muted colors retain the theme's choice; faint colors
move toward its foreground just enough to reach the floor. This brightens text
on dark themes and darkens it on light themes, updating immediately when the
theme changes. Cards and the media caption band use a solid backing derived
from the popup/background palette, so wallpaper and artwork cannot wash out
those labels. Disabled controls and decorative dividers retain their separate
visual states. This changes OmaDeck only, not the system theme.

The contrast target follows [WCAG's normal-text guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).
Regression checks cover captured light/dark palettes, arbitrary custom colors,
and existing QML labels during live palette changes. Physical screen brightness,
viewing angle, and very thin fonts still affect perceived readability.
