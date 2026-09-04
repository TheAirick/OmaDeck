# Troubleshooting

## Development rescan still shows old controls

First verify the live plugin resolves to the intended checkout, then rescan and
check a visibly changed control. Omarchy 4.0.2 / Quickshell 0.3.1 can retain old
QML across `omarchy-shell shell rescanPlugins`; a successful ping only proves
health, not that new code loaded. If the visible marker remains old, save work
and explicitly approve one `omarchy restart shell` before running it. This
briefly removes the bar and OmaDeck. Verify the marker, doctor, and logs afterward;
do not routinely restart as a substitute for diagnosing a failed reload.

## Layout or applications report “not saved”

The current edit is retained in memory while storage is unavailable. Restore
write access/free disk space, then use the visible **Retry** button. The
controller also retries at a bounded interval. Avoid restarting before the
notice clears: unsaved changes are not durable across shell recreation.

## OmaDeck does not appear

Confirm the plugin is enabled in `~/.config/omarchy/shell.json` and that the
saved `targetScreen` in `~/.config/omadeck/hardware.json` matches a connected
output from `hyprctl monitors`, then run `omarchy restart shell`.
For a linked checkout, run `omarchy-shell shell rescanPlugins`.

## Touch affects the wrong monitor

Standard mode uses Hyprland's compositor-managed touch mapping. Configure the
touchscreen for the OmaDeck output in Hyprland, or build the optional native
integration for isolated direct routing.

With the native integration, OmaDeck isolates the direct touchscreen and
injects it only into the deck window. Run `scripts/omadeck-doctor` and confirm
that the configured device is both readable and owned by the bridge. If doctor
reports that the configured touchscreen is absent or mismatched, OmaDeck has
deliberately refused to grab the other direct touchscreen(s) it found. Reconnect
the deck device or choose its distinctive evdev name in **Preferences → Input**; do not
broaden the match to a generic `Touchscreen` value.

## Touch stops after suspend or a USB reset

The optional native bridge automatically closes the dead evdev descriptor and retries once per
second until the touchscreen returns. If it does not recover, open the OmaDeck
system-tray icon with the mouse and choose **Reconnect touchscreen**, or run:

```bash
omarchy-shell pretty.omadeck reconnectTouch
```

The Control Center's copied report identifies a missing device, permission
problem, absent native build, or disconnected bridge without including
clipboard contents or window titles.

## Touch stops after Quickshell recovers from a crash

OmaDeck releases a previous in-process bridge before the recovered QML engine
acquires touch, and its evdev descriptor is protected from inheritance by tray,
editor, and watcher processes. Rebuild native components after updating so that
protection is active:

```bash
~/.config/omarchy/plugins/pretty.omadeck/scripts/build-native
omarchy restart shell
```

The build uses a fresh private directory, runs the native tests, and atomically
installs verified outputs. If the tray reports an invalid artifact record, do
not copy an old binary into place; rerun `scripts/build-native` so the executable
and its local integrity record are regenerated together.

The dedicated touch endpoints must also be disabled in Hyprland as described in
[Configuration](CONFIGURATION.md#touch-mapping). Otherwise Hyprland can claim
the device during the brief gap between bridge instances. A healthy restart
logs `[OmaDeckTouch] grabbed` and `closeOnExec true`.

If Quickshell itself dumped core during an audio-device change, inspect it with
`coredumpctl info quickshell`. OmaDeck snapshots playback streams and uses fixed
category controls instead of regenerating per-stream delegates during node teardown.

## The OmaDeck tray icon is missing

The tray is an optional native enhancement and is not present after the
standard one-line install. Build the native components and restart the shell:

```bash
~/.config/omarchy/plugins/pretty.omadeck/scripts/build-native
omarchy restart shell
```

## Applications open on the deck

Confirm **Preferences → Displays → Primary workspace monitor** names a connected
output. OmaDeck launches through a
workspace-bound Hyprland rule so placement does not depend on cursor position.

## Notification Center is empty

OmaDeck uses the installed `omarchy.notifications` service and its bounded
history rather than running a second notification daemon. Confirm the service
responds with `omarchy-shell notifications ping`. Notifications marked
transient by an application may not remain in history after their popup closes.

## Scratchpad controls do nothing

OmaDeck delegates to Omarchy's native Hyprland scratchpad. Confirm the standard
scratchpad shortcut works with `Super + S`, then inspect `hyprctl configerrors`.
**Park focused window** acts on the last focused application because the deck
layer surface intentionally never requests keyboard focus.

## A launcher opens another copy

Compare the live application's class with its installed desktop-entry identity.
Matching is owned by `services/LauncherPolicy.js` and `scripts/focus-or-launch`,
not a user-editable `classes` array in the launcher module. Report the desktop
entry ID and class (without private window titles) when they do not match.

## Media metadata or seeking is unavailable

OmaDeck uses MPRIS. Some web players omit artwork, duration, or seek support,
and metadata can briefly reset when tracks change. Missing capabilities are
hidden or disabled rather than emulated.

## Audio sources are missing

Confirm the application is actively producing audio with `wpctl status`.
Stream categories are inferred from metadata and may fall back to Other.

## GPU or temperature values are blank

NVIDIA readings require `nvidia-smi`; CPU temperature requires a sensor exposed
by `sensors` as `Tctl`. Other System features continue working without them.

## Weather says unavailable

Open **Preferences → OmaDeck** and tap **Refresh weather**. If automatic IP
location is not available, use the optional tray's **Weather location…** action,
or configure one directly:

```bash
omarchy-weather-location --set "Seattle" "47.6062,-122.3321"
```

OmaDeck keeps the clock operational when `wttr.in` or Open-Meteo is offline and
refreshes normally every 15 minutes. Each request has a strict body cap and the
whole provider sequence has a ten-second deadline. Location files that are
symlinks, oversized, malformed, outside latitude/longitude ranges, owned by
another user, or group/world writable are ignored. If Omarchy's built-in
weather panel is also unavailable, the issue is upstream connectivity or
location resolution rather than the OmaDeck card.

When a location is saved for the first time after OmaDeck starts, the card
detects the new Omarchy location file within ten seconds and refreshes. A
transient provider failure retries after one minute.

## Monitor input switching fails

Run the configured script directly and inspect its exit code. Input switching
is monitor-specific and the scripts are not shipped by OmaDeck.

## Diagnostics

```bash
omarchy version
omarchy-shell shell ping
hyprctl configerrors
journalctl --user _COMM=quickshell --since "10 minutes ago" --no-pager -n 100
```

Reports should include the OmaDeck commit, Omarchy version, monitor names,
logs, and reproduction steps. Remove private clipboard text and window titles.

For a focused, sanitized report, run:

```bash
~/.config/omarchy/plugins/pretty.omadeck/scripts/omadeck-doctor
```
