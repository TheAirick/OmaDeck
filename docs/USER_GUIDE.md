# User guide

## Requirements

- A current Omarchy installation with `omarchy-shell`
- Hyprland and a secondary touchscreen
- PipeWire for mixer controls
- `jq` and standard Linux system utilities
- Optional NVIDIA tools and `lm_sensors` for GPU and temperature readings

The current release assumes the deck is `DP-3` and the primary monitor is
`DP-1`. If your monitor names differ, configure them first.

## Starting OmaDeck

After installation and `scripts/build-native`, OmaDeck is loaded by the Omarchy
shell at every login. To reload it manually:

```bash
omarchy restart shell
```

## System-tray control center

OmaDeck adds an icon to the primary desktop's system tray. Click it with the
mouse to open diagnostics even when the deck touchscreen is unavailable. The
Control Center shows monitor, touchscreen, native-build, input-script, and
command health. It can copy a sanitized report, request touch reconnection, and
restart the Omarchy shell after confirmation.

The tray's **Configuration guide** action opens the source-level options
described in [Configuration](CONFIGURATION.md).

## Clock and weather

The left center card combines the clock with current weather. OmaDeck uses
Omarchy's existing weather location and refreshes every 15 minutes. Its Rich
visual uses Omarchy's recognizable condition glyphs, current-condition stats,
and a multi-day forecast. When the provider is unreachable, the clock remains
usable and the weather area reports that it is unavailable.

Tap the gear in the card's upper-right corner to open its settings sheet. You
can change clock layout and time format, show seconds, hide weather, select a
weather visual and detail level, switch temperature units, refresh immediately,
or open Omarchy's location editor. Every appearance choice persists across
shell restarts and computer locks.

If automatic location is unavailable, choose **Set in Omarchy** and enter a
city in the weather panel that opens on the primary display. The deck will
refresh after Omarchy saves its weather location; **Refresh** is also available
in the sheet.

## Touch interactions

### Edge drawers

- Swipe inward from the left edge for Media.
- Swipe inward from the right edge for System.
- Swipe down from the top edge for Workspaces.
- Swipe up from the bottom edge for Applications.
- Repeat a drawer gesture, use its Command Center button, or tap the center
  canvas to dismiss it.

Drawers reserve space and re-tile the center modules. They do not cover or push
the intact layout beyond the display. The drawer and center cards move on the
same animated boundary. During a tighter layout, modules preserve primary
controls and may temporarily reduce secondary text, weather stats, or forecast
days; the chosen detail returns automatically when space is available again.

### Applications

Tap a launcher once. OmaDeck first searches Hyprland for a matching window. If
one exists, it focuses the exact window and switches the primary monitor to its
workspace. Otherwise, it launches the application on the primary monitor.

### Media and audio

- Tap the media icon on any audio row to mute it.
- Drag a slider to change volume.
- Tap an audio category label to reveal its individual sources.
- Tap Output to fold or expand the mixer and give Now Playing more room.
- Use the progress slider to seek when the active MPRIS player exposes a valid
  duration.

### System

The System overview links to Performance, Network, Applications, Clipboard,
and Storage. Breadcrumbs are interactive: in
`System › Applications › Zen`, tap `System` for the overview or `Applications`
for the process list.

Network and Storage summon Omarchy's native internet and disk speed tests.

### Clipboard

- Tap an entry to inspect its complete text or image.
- Hold an entry to copy it immediately.
- Use Copy inside the inspector to restore that exact entry.
- Use Delete to remove it from Omarchy clipboard history. Image files owned by
  that entry are removed when no other history item references them.

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

The Clock/Weather gear is separate from layout editing. A normal tap opens card
settings; continue to use a long press anywhere else in the center module to
edit the split layout.

## Monitor input switching

The Command Center input control calls two user-owned scripts:

```text
~/.local/bin/alienware-to-omarchy
~/.local/bin/alienware-to-mac
```

They are not included because DDC/CI input codes and monitor buses differ by
setup. See [Configuration](CONFIGURATION.md).
