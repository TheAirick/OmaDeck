# User guide

## Requirements

- A current Omarchy installation with `omarchy-shell`
- Hyprland and a secondary touchscreen
- PipeWire for mixer controls
- `jq` and standard Linux system utilities
- Optional NVIDIA tools and `lm_sensors` for GPU and temperature readings

On first run OmaDeck prefers `DP-3` and `DP-1`, then selects connected displays
when those names are unavailable. If the automatic choice is not right, change
it in **Preferences → Displays**.

## Starting OmaDeck

After installation, OmaDeck is loaded by the Omarchy shell at every login. No
native build is required for the dashboard or compositor-managed touch. To
reload it manually:

```bash
omarchy restart shell
```

## System-tray control center

The optional native build adds an icon to the primary desktop's system tray. Click it with the
mouse to open diagnostics even when the deck touchscreen is unavailable. The
Control Center shows monitor, touchscreen, native-build, input-script, and
command health. It can copy a sanitized report, request touch reconnection, and
restart the Omarchy shell after confirmation.

Build the native integration with `scripts/build-native`, then restart the
shell. The tray's **Configuration guide** action opens the source-level options
described in [Configuration](CONFIGURATION.md).

## Clock and weather

The left center leaf has separate Clock and Weather panels. OmaDeck uses
Omarchy's existing weather location and refreshes every 15 minutes. Its Rich
visual uses Omarchy's recognizable condition glyphs, current-condition stats,
and a multi-day forecast. When the provider is unreachable, the clock remains
usable and the weather area reports that it is unavailable.

Use **Preferences → OmaDeck** to change time format, weather treatment, detail,
visibility, or units. The optional tray's **Clock & weather settings…** exposes
the same persisted appearance settings. The current Clock uses a fixed
presentation; the legacy clock-style setting does not change it.

Tap the Clock card to set a countdown. Choose hours, minutes, and seconds. The
setup sheet's **Sound** row cycles through
Silent, Alarm, Complete, Bell, Ring, and Warning; **Preview** plays the current
choice once. Tap **Start** to begin and return the lower companion to Weather;
the Clock shows timer progress. Tap the Clock again to open pause, resume,
add-five, restart, and cancel controls. Completed state remains available until
you dismiss it. Audible choices play three non-overlapping completion chimes; Silent keeps
the visual state and desktop notification without launching a player.

## Touch interactions

### Edge drawers

- Swipe inward from the left edge for Volume. Now Playing stays on the dashboard.
- Swipe inward from the right edge for System.
- Swipe down from the top edge for Notifications.
- Swipe up from the bottom edge for Overview (workspaces and scratchpad).
- Reverse-swipe a horizontal drawer's inner edge to dismiss it, or toggle its
  Command Center button. Vertical overlays have a close button and reverse gesture.

Horizontal drawers reserve space and re-tile the center modules. They do not cover or push
the intact layout beyond the display. The drawer and center cards move on the
same animated boundary. During a tighter layout, modules preserve primary
controls and may temporarily reduce secondary text, weather stats, or forecast
days; the chosen detail returns automatically when space is available again.
Vertical overlays cover the dashboard without changing its geometry and retain
the horizontal drawer underneath. Applications opens from Command Center.

### Applications

Tap a launcher once. OmaDeck first searches Hyprland for a matching window. If
one exists, it focuses the exact window and switches the primary monitor to its
workspace. Otherwise, it launches the application on the primary monitor.

### Media and audio

- Tap the icon above a volume slider to mute that output, microphone, or category.
- Drag a vertical slider to change volume.
- Tap the expansion chevron to reveal the microphone and active Media, Games,
  Voice, and Other category sliders; tap it again to return to Output only.
- Categories control their current member streams together. This release does
  not expose individual application sliders, EQ, or sound presets.
- Use the progress slider to seek when the active MPRIS player exposes a valid
  duration.

### System

The System overview links to Performance, Network, Applications, Clipboard,
and Storage. Breadcrumbs are interactive: in
`System › Applications › Zen`, tap `System` for the overview or `Applications`
for the process list.

Network and Storage summon Omarchy's native internet and disk speed tests.

### Clipboard

- Tap an entry to inspect its bounded text preview or image.
- Hold an entry to copy it immediately.
- Use Copy inside the inspector to restore that exact entry.
- Use Delete to remove it from Omarchy clipboard history. OmaDeck deliberately
  retains image payload files rather than risk deleting an image still in use.
  The list is limited to recent entries, not the entire clipboard archive.

### Task manager

Tap a running application to inspect its CPU use, memory, state, workspace, and
uptime. Focus activates its window; Close requests a normal close; Force Kill
sends `SIGKILL` to its primary process after a second confirmation tap.

> [!WARNING]
> Force Kill does not allow an application to save its work. Use Close first.

## Layout editing

Long-press a center module to enter edit mode. Select or drag modules to swap
them, and drag the highlighted divider to resize the split. Changes are saved
to `~/.config/omadeck/layout.json`.

A normal Clock tap opens its temporary timer controls. The existing long press
still enters layout editing without starting or changing a timer.

## Optional monitor input module

The repository includes a monitor-input module for custom layouts, but it is
not exposed by the standard Command Center. It calls two user-owned scripts:

```text
~/.local/bin/alienware-to-omarchy
~/.local/bin/alienware-to-mac
```

They are not included because DDC/CI input codes and monitor buses differ by
setup. See [Configuration](CONFIGURATION.md).
