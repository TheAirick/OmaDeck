# Architecture

OmaDeck is a keep-loaded Omarchy shell service written in QML. It does not run
a web server, Electron process, or separate system daemon.

## Entry points

- `manifest.json` declares the `pretty.omadeck` service plugin.
- `Service.qml` selects the target screen and owns persistent services.
- `components/DeckSurface.qml` creates the layer surface, drawers, IPC entry
  points, and bounded tiling region.

## Layout model

The center uses a recursive binary split tree. Split nodes contain an
orientation, ratio, and two children; leaves contain module IDs.
`services/LayoutController.qml` validates and atomically persists layout state.

Edge drawers participate in the same geometry. Four animated reserved-space
values alter the center boundaries, creating retiling motion rather than
overlaying or translating complete panels off-screen.

## Native integrations

- Omarchy `Color`, `Style`, and `Border` tokens drive appearance.
- Quickshell PipeWire and media services provide live models.
- Hyprland IPC handles exact-window focus, workspaces, placement, and close.
- Omarchy clipboard history provides text and image entries.
- Omarchy panels provide network and disk speed tests.

Small shell helpers under `scripts/` bridge system data or actions that are
awkward to express safely in QML.

OmaDeck also contains two native Qt components:

- `TouchBridge` exclusively reads the direct touchscreen evdev node and injects
  pointer events only into the OmaDeck window. It automatically releases dead
  descriptors and retries after USB re-enumeration or suspend.
- `omadeck-tray` is a separate `QSystemTrayIcon` process. It remains usable by
  mouse when deck touch is unavailable and runs the same health checks exposed
  by `scripts/omadeck-doctor`.

`scripts/build-native` configures and builds both components. Generated build
artifacts are deliberately not stored in Git because they are tied to the
local Qt and Quickshell ABI.

## IPC

The `pretty.omadeck` target exposes navigation and layout methods useful for
automation and deterministic captures:

```bash
omarchy-shell pretty.omadeck drawer left
omarchy-shell pretty.omadeck system performance
omarchy-shell pretty.omadeck closeDrawer
omarchy-shell pretty.omadeck reconnectTouch
```

## Security model

OmaDeck runs as the logged-in user. It can read that user's clipboard history
and process metadata, control PipeWire streams, focus and close windows, signal
user processes, and exclusively read the selected direct touchscreen input
node. It does not require root when normal input-device permissions are
configured. Force Kill has an expiring two-tap confirmation.
