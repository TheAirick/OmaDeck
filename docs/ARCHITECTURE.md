# Architecture

OmaDeck is a keep-loaded Omarchy shell service written in QML. It does not run
a web server, Electron process, or separate system daemon.

## Entry points

- `manifest.json` declares the `pretty.omadeck` service plugin.
- `Service.qml` selects the target screen and owns persistent services and IPC.
  Its IPC handler remains registered while the target monitor is absent and
  forwards surface-specific commands to the current `DeckSurface` when present.
- `components/DeckSurface.qml` creates the layer surface, drawers, and bounded
  tiling region, registering itself with the service across monitor hotplug.
- `services/AppearanceController.qml` validates and atomically persists the
  Clock/Weather presentation model.
- `services/TimerController.qml` owns the Clock's single deadline-based
  countdown, separate atomic sound preference, and claimed notification/
  three-chime completion effects. Static allowlisted Canberra commands share
  the default PipeWire route, and the controller serializes preview and
  completion players under one lifecycle.
- `services/WeatherController.qml` owns refresh state and normalizes provider
  condition codes for the UI.

## Layout model

The center uses a recursive binary split tree. Split nodes contain an
orientation, ratio, and two children; leaves contain module IDs.
`services/LayoutController.qml` validates and atomically persists layout state.

Edge drawers participate in the same geometry. Four animated reserved-space
values alter both the drawer positions and center boundaries, creating one
synchronized retiling motion rather than an overlay. Cards clip their content
to their live bounds; dense modules scale or progressively hide secondary
details when a split becomes constrained.

Each open drawer owns a contextual directional button back to the center. It
floats above drawer content without changing its geometry and appears only
while a mouse is over OmaDeck; touch interaction keeps the control hidden and
uses reverse-swipe dismissal instead.

## Native integrations

- Omarchy `Color`, `Style`, and `Border` tokens drive appearance.
- Quickshell PipeWire and media services provide live models.
- Hyprland IPC handles exact-window focus, workspaces, placement, and close.
- Omarchy clipboard history provides text and image entries.
- Omarchy panels provide network and disk speed tests.

Small shell helpers under `scripts/` bridge system data or actions that are
awkward to express safely in QML.

`scripts/weather-json` reads Omarchy's location state, uses `wttr.in` for
automatic or name-only location resolution, and fetches structured current and
daily conditions from Open-Meteo. The controller preserves the last good result
across transient failures; the renderer maps provider codes to Omarchy's clear,
cloud, fog, drizzle, rain, snow, hail, and thunderstorm glyph language.

OmaDeck also contains two native Qt components:

- `TouchBridge` exclusively reads the direct touchscreen evdev node and injects
  pointer events only into the OmaDeck window. An explicit list of distinctive,
  case-insensitive device-name substrings authorizes the exclusive grab; an
  absent match fails closed without selecting another direct touchscreen. It
  automatically releases dead descriptors, hands ownership between QML-engine
  instances after crash recovery, marks the device close-on-exec, and retries
  after USB re-enumeration or suspend.
- `omadeck-tray` is a separate `QSystemTrayIcon` process. It remains usable by
  mouse when deck touch is unavailable and runs the same health checks exposed
  by `scripts/omadeck-doctor`. It also owns the single Clock/Weather settings
  panel and updates the validated QML appearance controller through bounded IPC;
  it never writes the appearance file directly.

`scripts/build-native` configures and builds both components. Generated build
artifacts are deliberately not stored in Git because they are tied to the
local Qt and Quickshell ABI.

The audio mixer snapshots live PipeWire streams before presenting them. Its
per-stream delegates use a fixed repeater model so `PwNode` removal never asks
Qt to regenerate a `QQuickRepeater` while Quickshell is unbinding that node.

## IPC

The `pretty.omadeck` target exposes navigation and layout methods useful for
automation and deterministic captures:

```bash
omarchy-shell pretty.omadeck drawer left
omarchy-shell pretty.omadeck system performance
omarchy-shell pretty.omadeck closeDrawer
omarchy-shell pretty.omadeck reconnectTouch
omarchy-shell pretty.omadeck appearanceState
omarchy-shell pretty.omadeck setAppearance showSeconds true
omarchy-shell pretty.omadeck timerState
omarchy-shell pretty.omadeck timerStart 0 5
omarchy-shell pretty.omadeck timerPause
omarchy-shell pretty.omadeck timerResume
omarchy-shell pretty.omadeck timerAdd 5
omarchy-shell pretty.omadeck timerRestart
omarchy-shell pretty.omadeck timerCancel
omarchy-shell pretty.omadeck timerDismiss
```

## Security model

OmaDeck runs as the logged-in user. It can read that user's clipboard history
and process metadata, control PipeWire streams, focus and close windows, signal
user processes, and exclusively read the selected direct touchscreen input
node. It does not require root when normal input-device permissions are
configured. Force Kill has an expiring two-tap confirmation.

Weather is optional, but enabled by default. As with Omarchy's built-in weather
panel, enabling it sends a configured location—or the public-IP-derived
location when automatic—to `wttr.in` and Open-Meteo.
