# Architecture

OmaDeck is a keep-loaded Omarchy shell service written in QML. It does not run
a web server, Electron process, or separate system daemon.

## Entry points

- `manifest.json` declares the `pretty.omadeck` service plugin.
- `Service.qml` selects the target screen and owns persistent services and IPC.
  Its IPC handler remains registered while the target monitor is absent and
  forwards surface-specific commands to the current `DeckSurface` when present.
- `components/DeckSurface.qml` creates the layer surface and drawers, registering
  itself with the service across monitor hotplug. Its `DeckCenter` child owns the
  reserved center geometry and actual root `SplitNode` tiling region.
- `services/AppearanceController.qml` validates and atomically persists the
  Clock/Weather presentation model.
- `services/TimerController.qml` owns the Clock's single deadline-based
  countdown, separate atomic sound preference, and claimed notification/
  three-chime completion effects. Static allowlisted Canberra commands share
  the default PipeWire route, and the controller serializes preview and
  completion players under one lifecycle.
- `services/WeatherController.qml` owns refresh state and normalizes provider
  condition codes for the UI.

Weather presentation has a separate, lifecycle-free boundary:
`modules/WeatherModule.qml` adapts the service-owned `WeatherController` state
to exactly one `components/WeatherVisual.qml`. `ClockCompanionModule.qml`
statically embeds one Weather presenter in the lower companion slot. The module
owns no provider process, polling or retry timer, location state, persistence,
IPC, or settings surface; disabling Weather still stops provider work through
the single controller in `Service.qml`. The tray remains the only Clock and
Weather settings owner.

Timer setup and controls use the same presentation-only boundary:
`modules/TimerModule.qml` owns the duration draft, compact reflow, sound selector,
and forwarding of timer actions. `components/ClockCompanionTile.qml` is the
Clock-specific `ModuleTile` host: it replaces the ordinary single-card wrapper
with two sibling `DeckCard` boundaries separated by the panel-gap token. The
upper `0.37` card owns only `ClockModule`; the lower `0.63` card owns one static
`ClockCompanionModule`, whose title and sole visible occupant switch between
Weather while idle and Timer during setup and every non-idle state. The pair is
still one saved `clock` leaf for selection, dragging, swapping, and persistence.
Ambient Timer status and progress remain in the Clock without duplicating the
countdown readout. The presentation does not own authoritative
countdown state, deadlines, persistence, notification or audio scheduling,
processes, files, IPC, layout mutation, or settings; those remain with the single
service-owned `TimerController` and existing service IPC.

Media presentation uses a frameless left-drawer carrier with two persistent
sibling `DeckCard` boundaries separated by the panel-gap token. The carrier
reserves 42% of the usable deck width so the upper `NowPlayingModule` and lower
`AudioMixerModule` can use the Command Center's former excess width. Their
52/48 vertical allocation is presentation-only and creates no persisted layout
node, schema, setting, or resizable divider. The mixer keeps Output and Mic in
one fixed master row, then gives every dynamic category and source row one
bounded vertical viewport with a dedicated swipe/tap gutter. The stable
PipeWire snapshot remains the viewport's model authority.
`modules/NowPlayingModule.qml` owns only the active-player projection, local
duration/position and same-track artwork caches, transport controls, metadata,
and timeline. It creates no PipeWire model, process, persistence, IPC, settings,
or dynamic QML path; those concerns remain with the existing service and audio
mixer owners.

## Layout model

The center uses a recursive binary split tree. Split nodes contain an
orientation, ratio, and two children; leaves contain module IDs.
`services/LayoutController.qml` validates and atomically persists layout state.
For the current direct horizontal Clock/Command Center split only,
`SplitPresentationPolicy.js` renders the Clock/Weather side at a minimum `0.50`
share. This restores Weather detail while the finite Command Center controls
remain full-size in the other half.
The saved ratio, topology, revision, selected edit path, and drawer state remain
unchanged; other nested or vertical topologies retain their saved geometry.

Edge drawers participate in the same geometry. Four animated reserved-space
values alter both the drawer positions and center boundaries, creating one
synchronized retiling motion rather than an overlay. Cards clip their content
to their live bounds. Finite action panels follow a shared responsive contract:
use geometry-driven `Grid`/`Flow` reflow first, then wrap the complete control
stack in `components/ResponsivePanel.qml` for centered, two-axis bounded
scaling. Primary controls must not depend on undiscoverable scrolling;
`Flickable` is reserved for genuinely unbounded data such as application,
clipboard, or audio-stream lists. `components/ResponsiveLayout.js` owns the
fit and short-wide breakpoint math so future panels use the same policy rather
than copying size formulas.

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
