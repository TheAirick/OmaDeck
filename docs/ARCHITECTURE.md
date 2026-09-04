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
- `services/HardwareController.qml` validates and atomically persists the
  selected deck screen, primary workspace monitor, and authorized direct-touch
  device identities. Connected monitors come from Quickshell; readable direct
  touchscreens come from the native bridge rather than a recurring helper.
- `services/LauncherController.qml` validates and atomically persists the
  ordered Command Center launcher selection. `LauncherPolicy.js` restricts
  touch editing to installed desktop-entry IDs and the built-in action catalog,
  so persisted data cannot introduce an arbitrary command vector.
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
the single controller in `Service.qml`. The tray and OmaDeck Preferences page
are two projections of that one controller; neither writes appearance state
directly. At ordinary companion geometry, the default scene
delegates to `components/OmarchyWeatherVisual.qml`, which follows the installed
Omarchy 4.0.2 weather panel's 64/56 hero scale, right-side location/metric grid,
14-unit vertical rhythm, hairline divider, and three-cell forecast. Constrained
scene geometry retains the prior responsive renderer; glyph and minimal styles
remain separate preferences. The Omarchy renderer activates at `350x110`
logical pixels so the Xeneon Edge's scaled companion card keeps the divider and
three-day forecast instead of falling back to the compressed current-only view.

Timer setup and controls use the same presentation-only boundary:
`modules/TimerModule.qml` owns the editable hours/minutes/seconds draft, compact reflow, sound selector,
and forwarding of timer actions. `components/ClockCompanionTile.qml` is the
Clock-specific `ModuleTile` host: it replaces the ordinary single-card wrapper
with two sibling `DeckCard` boundaries separated by the panel-gap token. The
Clock, Weather, and the temporary Timer surface retain Omarchy's panel-padding
token around their headers and content. The upper Clock card always uses `0.48`
of the available height and the lower companion card always uses `0.52`.
The Clock time scale uses that added height with an enlarged bounded type scale
rather than retaining its former compact cap.
The upper card owns only `ClockModule`; the lower card owns one static
`ClockCompanionModule`, whose title and sole visible occupant switch between
Weather and the explicitly opened Timer surface without changing geometry.
Starting a timer closes that surface, leaving progress in the Clock; tapping the
Clock reopens controls for an active, paused, or completed timer. The pair is
still one saved `clock` leaf for selection, dragging, swapping, and persistence.
Ambient Timer status and progress remain in the Clock without duplicating the
countdown readout. The presentation does not own authoritative
countdown state, deadlines, persistence, notification or audio scheduling,
processes, files, IPC, layout mutation, or settings; those remain with the single
service-owned `TimerController` and existing service IPC.

Media presentation has two independent owners. A permanent full-height
`MediaModule` reserves 27% of the usable dashboard width for one Now Playing
`DeckCard`; it remains mounted beside Clock/Weather and Command Center in every
drawer and overlay state. A frameless left drawer owns only `VolumeModule` and
reserves exactly the mixer's current preferred width while open. This
horizontal allocation is presentation-only and creates no persisted layout
node, schema, setting, or resizable divider. The mixer starts with one
almost-full-height vertical Output control and a bottom expansion chevron.
Expanded mode widens the Volume drawer just enough to add a vertical Mic control and
the active Media, Games, Voice, and Other aggregate categories. Tapping the
slim edge chevron again restores the narrow strip without reserving a full
button column. The stable PipeWire snapshot remains
the presentation model authority while category changes fan out to currently
live member streams.
`modules/NowPlayingModule.qml` owns only the active-player projection, local
duration/position and same-track artwork caches, transport controls, metadata,
and timeline. Its presentation centers bounded artwork at the top, overlays the
single-line title and artist on the artwork's lower edge, centers transport
controls in the band below it, and pins the seek timeline to the bottom. The
artwork remains bounded as the card widens. Previous, ten-second rewind,
play/pause, ten-second forward, and next remain one complete oversized control
row at the live narrow width. It creates no
PipeWire model, process, persistence, IPC, settings, or dynamic QML path; those
concerns remain with the existing service and audio mixer owners.

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

The left Volume and right System drawers participate in the dashboard geometry.
Their two animated reserved-space values alter both drawer positions and center
boundaries, creating one synchronized horizontal retiling motion. Top and
bottom gestures deliberately do not reserve geometry: they reveal full-surface
`DeckOverlay` instances above an unchanged dashboard. The Command Center also
opens Preferences in the same overlay layer. Pulling down opens recent
notifications; pulling up opens the workspace and scratchpad overview. Overlay
state is independent of horizontal drawer state: dismissing an overlay reveals
the same Volume or System drawer and the same underlying geometry that was
present before the vertical gesture. The two horizontal drawers remain mutually
exclusive, and only one full-surface overlay can be open at a time.

The notification overlay borrows the single installed
`omarchy.notifications` service for live notification actions, DND, clearing,
and application focus. It reads that service's bounded on-disk history for
presentation only and never creates another `NotificationServer`. Its compact
control rail delegates DND and Night Light to the corresponding first-party
services, Wi-Fi to Quickshell's NetworkManager model, and Bluetooth power to
Omarchy's persistent rfkill helper. The notification feed is width-capped so
messages remain scannable on the ultra-wide deck. The overview
delegates workspace focus and `special:scratchpad` actions to Hyprland's native
dispatch language.

The Command Center is a small page host. Its six controls expose Volume, System,
Notifications, Overview, Applications, and Preferences. Applications replaces
the home controls in place with `AppLauncherModule`; Home returns without changing
the center layout. Preferences opens a full-surface category browser. Its first
functional page owns OmaDeck layout entry points, Clock/Weather controls, and
the timer sound selector, all delegated to the existing validated controllers.
The Shell page projects Do Not Disturb, Night Light, and Keep Awake directly
from the installed first-party notification, nightlight, and idle services.
Appearance and Desktop expose the small settings for which the shell already
owns live state and validated persistence—bar position/transparency and idle
timeouts—through `shell.mutateShellConfig`. Richer Appearance, Desktop,
Displays, Input, Sound, Applications, Power, and Advanced actions summon the
installed Omarchy menu or first-party panel that owns the setting. Preferences
therefore neither spawns helpers nor writes `shell.json`, Hyprland files, or
application defaults itself. Launcher entries may be added from Omarchy's filtered live
application library or a curated shortcut catalog, removed, and moved left or
right. The service-owned launcher controller saves only stable IDs.

Cards clip their content to their live bounds. Finite action panels follow a shared responsive contract:
use geometry-driven `Grid`/`Flow` reflow first, then wrap the complete control
stack in `components/ResponsivePanel.qml` for centered, two-axis bounded
scaling. Primary controls must not depend on undiscoverable scrolling;
`Flickable` is reserved for genuinely unbounded data such as application,
clipboard, or audio-stream lists. `components/ResponsiveLayout.js` owns the
fit and short-wide breakpoint math so future panels use the same policy rather
than copying size formulas.

Each open horizontal drawer owns a contextual directional button back to the center. It
floats above drawer content without changing its geometry and appears only
while a mouse is over OmaDeck; touch interaction keeps the control hidden and
uses reverse-swipe dismissal instead. Full-surface overlays retain an explicit
48-unit close target and a reverse gesture on the edge opposite their reveal.

## Native integrations

- Omarchy `Color`, `Style`, and `Border` tokens drive appearance.
- Quickshell PipeWire and media services provide live models.
- Hyprland IPC handles exact-window focus, workspaces, placement, and close.
- Omarchy clipboard history provides text and image entries.
- Omarchy panels provide network and disk speed tests.

Small shell helpers under `scripts/` bridge system data or actions that are
awkward to express safely in QML.

`scripts/weather-location` reads Omarchy's location through a bounded,
descriptor-relative, no-follow path and exposes only normalized coordinates,
an 80-character name, and a digest. `scripts/run-weather` supervises the worker
under an absolute ten-second process-group deadline that includes DNS, connect,
TLS, and body reads. `scripts/weather-json` streams at most 256 KiB from each
HTTPS provider, strictly validates coordinate, scalar, string, and forecast
bounds, and emits at most 16 KiB. The QML controller consumes both helpers
through incremental bounded parsers rather than retaining arbitrary process
output and retains a later termination/kill timer as a supervisor backstop. The
worker uses `wttr.in` for automatic or name-only location resolution and
Open-Meteo for structured current and daily conditions. The controller
preserves the last good result across transient failures; the renderer maps
provider codes to Omarchy's clear, cloud, fog, drizzle, rain, snow, hail, and
thunderstorm glyph language.

`scripts/system-stats` is a bounded Python probe that invokes only explicitly
checked, root-owned executables at fixed `/usr/bin` paths. CPU and network
counters live in a private `0700` runtime directory and are opened relative to
validated directory descriptors with no symlink following and atomic
replacement. Every external producer has a byte limit, deadline, cardinality
cap, and process-group kill path. Clipboard and Hyprland values are projected
into a capped schema before the helper emits its 256 KiB maximum snapshot.

OmaDeck runs without compiled artifacts by using Hyprland's compositor-managed
input path. `OptionalTouchBridge.qml` probes once for a locally built bridge and
loads the native QML type only when its verified artifact is present; a clean
plugin checkout therefore never fails its keep-loaded service import.

OmaDeck also contains two optional native Qt components:

- `TouchBridge` exclusively reads the direct touchscreen evdev node and injects
  pointer events only into the OmaDeck window. An explicit list of distinctive,
  case-insensitive device-name substrings authorizes the exclusive grab; an
  absent match fails closed without selecting another direct touchscreen. It
  exposes the bounded set of readable direct-touch device names to Preferences
  and rescans only on startup, reconnect, retry, or an explicit refresh. It
  automatically releases dead descriptors, hands ownership between QML-engine
  instances after crash recovery, marks the device close-on-exec, and retries
  after USB re-enumeration or suspend.
- `omadeck-tray` is a separate `QSystemTrayIcon` process. It remains usable by
  mouse when deck touch is unavailable and runs the same health checks exposed
  by `scripts/omadeck-doctor`. It also owns the single Clock/Weather settings
  panel and updates the validated QML appearance controller through bounded IPC;
  it never writes the appearance file directly. `scripts/run-tray` verifies the
  build record, owner, mode, size, and digest, keeps the validated executable
  inode open through launch, and applies a parent-death signal. The service uses
  exponential restart backoff for failures, treats the absent optional tray as
  a clean terminal state, uses a stable-run reset, graceful stop, and bounded
  kill escalation.

`scripts/build-native` configures and tests both components in a newly-created
private build directory. It refuses unexpected destination types or unsafe
ownership/modes, verifies staged bytes, atomically installs the two runtime
artifacts, and writes a local integrity record. Generated build artifacts and
that record are deliberately not stored in Git because they are tied to the
local Qt and Quickshell ABI.

The audio mixer snapshots live PipeWire streams before presenting them. Its
per-stream delegates use a fixed repeater model so `PwNode` removal never asks
Qt to regenerate a `QQuickRepeater` while Quickshell is unbinding that node.

## IPC

The `pretty.omadeck` target exposes navigation and layout methods useful for
automation and deterministic captures:

```bash
omarchy-shell pretty.omadeck drawer left
omarchy-shell pretty.omadeck overlay notifications
omarchy-shell pretty.omadeck overlay overview
omarchy-shell pretty.omadeck system performance
omarchy-shell pretty.omadeck closeDrawer
omarchy-shell pretty.omadeck reconnectTouch
omarchy-shell pretty.omadeck hardwareState
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
location when automatic—to `wttr.in` and Open-Meteo. Provider responses,
location input, process metadata, and clipboard history are all bounded before
they reach the long-running QML engine.
