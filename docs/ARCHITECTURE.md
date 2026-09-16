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
  Clock/Weather presentation model and Workspaces navigation preference.
- `services/HardwareController.qml` validates and atomically persists the
  selected deck screen, primary workspace monitor, and authorized direct-touch
  device identities. Connected monitors come from Quickshell; readable direct
  touchscreens come from the native bridge rather than a recurring helper.
- `services/LauncherController.qml` validates and atomically persists the
  ordered Command Center launcher selection and explicitly authored command
  buttons in one atomic `launcher-v2.json` snapshot. `LauncherPolicy.js` validates
  desktop IDs, stable custom IDs, bounded command fields, and icon choices.
  Legacy `launcher.json` is migrated without overwriting it.
- `services/TimerController.qml` owns the Clock's single deadline-based
  countdown, separate atomic sound preference, and claimed notification/
  three-chime completion effects. Ocean is the default, bundled unchanged with
  its CC-BY-SA-4.0 attribution under `assets/sounds/`. Its full 6.15-second clip
  has an eight-second playback deadline; legacy system events retain three
  seconds. A running player always blocks the next chime. Allowlisted Canberra
  event/file commands share the default PipeWire route, and the controller serializes preview and
  completion players under one lifecycle.
- `services/WeatherController.qml` owns refresh state and normalizes provider
  condition codes for the UI.

`theme/DeckColors.qml` derives OmaDeck's opaque panel backing and secondary-text
role from live Omarchy colors. `TextContrast.js` preserves readable muted colors
and otherwise mixes toward the foreground to reach 4.5:1 sRGB contrast. If the
foreground itself cannot meet that floor, it uses the stronger black/white
endpoint. Color quantization is included in the check. Bindings react to theme
changes without polling or writing theme files; labels on control fills can
request `secondaryTextOn(background)` for their actual backing.

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
and forwarding of timer actions. The version 3 dashboard tree contains separate
`media`, `clock`, `weather`, and `command-center` leaves. `ModuleTile` renders each
in its own `DeckCard`; the Weather leaf owns one `ClockCompanionModule` whose sole
visible occupant switches between Weather and Timer without changing geometry.
`DeckSurface` connects Clock taps to that mounted companion, including after
moves or swaps. Starting a timer closes the controls, leaving progress in Clock.
The former `ClockCompanionTile` remains a compatibility fixture for paired leaves.
Ambient Timer status and progress remain in the Clock without duplicating the
countdown readout. The presentation does not own authoritative
countdown state, deadlines, persistence, notification or audio scheduling,
processes, files, IPC, layout mutation, or settings; those remain with the single
service-owned `TimerController` and existing service IPC.

Layout editing starts explicitly through Preferences. Panel contents and edge
swipes are inert while editing; the split tree provides touch dividers, edge
placement, and swaps. `LayoutController` snapshots the tree on entry, saves only
on Done, and restores it on Cancel. Its version 3 `dashboard-layout.json` is
separate from the legacy `layout.json`, which is migrated without overwriting it.
The default media share is 27%; Clock/Weather start in a 48/52 vertical split.

Media presentation has two independent owners. `DeckSurface` owns the stable
MPRIS adapter, supplied to the movable `MediaModule`, so changing layout topology
does not replace the active backend. A frameless left drawer owns only
`VolumeModule` and reserves the mixer's preferred width while open. The entire
dashboard reflows within the remaining space using its saved proportions.
The mixer starts with one
almost-full-height vertical Output control and a bottom expansion chevron.
Expanded mode widens the Volume drawer just enough to add a vertical Mic control and
the active Media, Games, Voice, and Other aggregate categories. Tapping the
slim edge chevron again restores the narrow strip without reserving a full
button column. The stable PipeWire snapshot remains
the presentation model authority while category changes fan out to currently
live member streams.
The expanded mixer's Output and Mic rows open an in-drawer device picker.
`services/AudioDeviceController.qml` observes the shared PipeWire graph and
defers scalar device snapshots before rebuilding the picker. Selection checks
both the current node ID and name, serializes a bounded installed Omarchy
audio-switch command, and confirms the actual default from PipeWire before
returning to the mixer. It adds no persisted routing state or discovery process.
Both device lists remain mounted while the picker is open; Output/Mic tab taps
change visibility immediately without recreating the themed row controls.
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

If the host's scoped plugin API hides `omarchy.media`, `MediaModule` uses
`services/MprisMediaAdapter.qml` over Quickshell's shared MPRIS discovery model.
This adds no watcher process, duplicate D-Bus service, or PipeWire model. The
adapter prefers a playing source, then track metadata, with stable bus-name
ordering; an explicitly controlled source remains selected until it disappears.
Transport commands require that displayed source's live bus name and advertised
capabilities, and never fall back to a different player for a stale key.

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
notifications; pulling up opens the Workspaces browser and scratchpad. Overlay
state is independent of horizontal drawer state: dismissing an overlay reveals
the same Volume or System drawer and the same underlying geometry that was
present before the vertical gesture. Dashboard and drawer input is disabled from
the moment an overlay opens until all overlay closing animations finish; outgoing
overlay controls are also disabled. The direct-touch bridge targets the guarded
root content item so disabling the dashboard does not disable overlay input.
The two horizontal drawers remain mutually
exclusive, and only one full-surface overlay can be open at a time.

`NotificationController` projects Omarchy's notification ownership into a bounded
scalar feed; it never creates another `NotificationServer`. Hosts exposing the
first-party service retain its live default actions, resolved by notification
identity at activation rather than a stale model index. On scoped plugin APIs,
the on-demand `notification_control.py` bridge uses public Omarchy commands for
DND, Night Light, clearing, and literal application focus. Clear serializes the
owner's popup dismissal and history clear; OmaDeck never deletes owner files or
executes notification-supplied command vectors itself.

The history helper reads pending and archived files under Omarchy's XDG state
directory, enforcing directory, file-count, per-file and aggregate byte limits.
While the drawer is open, Qt directory watchers detect arrivals/archiving and at
most twelve watch-only FileViews detect edits to displayed files. Their names
come from the validated helper and their contents are never loaded by FileView.
Changes coalesce into a bounded read; closing destroys the watchers and cancels
the reader, and opening reconciles again. All helper processes have external
deadlines and QML lifecycle backstops.

The presenter uses a borderless recent list, a full-message reader on wide
screens, and a compact control rail. Narrow layouts provide Back navigation.
Selecting a row only reads its text; opening the app and confirmed Clear all
are separate actions. Selection survives new arrivals and all message text is
plain text; icons accept theme names only. Wi-Fi uses Quickshell's NetworkManager
model and Bluetooth power uses Omarchy's persistent rfkill helper.

The Workspaces overlay owns one `WorkspaceController`, which projects shared
Quickshell Hyprland models into scalar workspace/window rows and resolves app
names/icons through desktop entries. A coalesced native refresh follows window
mapping/movement and monitor/workspace lifecycle events while the view is active,
and each opening reconciles metadata again. This covers new native toplevels
whose initial IPC metadata does not yet include their app identity or workspace.
It adds no polling, process, or persisted window state. Five baseline slots are supplemented by existing numbered
workspaces. Delegates never retain removed native window objects; actions
re-resolve the exact window address before using Hyprland's native dispatcher.
Scratchpad visibility follows monitor IPC metadata, refreshed on special-workspace
events. Card and app-row taps toggle it without dismissing the browser; Return
and Park retain independent actions. Scratchpad return targets the current numbered
workspace or the primary monitor's active numbered workspace. The legacy `overview` IPC route remains
compatible with saved launcher shortcuts. Navigation leaves the view open unless
`workspaceCloseOnActivate` is enabled through the existing atomic appearance
store. Active workspace and visible scratchpad cards use an accent outline without
an additional selected fill. When pointer focus moves to the deck's named workspace
or a special workspace, the numbered highlight follows the primary monitor's live
active workspace. Overlay headers share their surrounding padding with
the close control's 48-unit touch target, keeping the borderless glyph compact.

The Command Center is a small page host. Its six controls expose Volume, System,
Notifications, Workspaces, Applications, and Preferences. Applications replaces
the home controls in place with `AppLauncherModule`; Home returns without changing
the center layout. Preferences opens a full-surface browser with Dashboard, Workspaces,
Timer, Display & touch, Monitor switching, and Launcher categories. These delegate layout, appearance,
sound, hardware, and launcher choices to OmaDeck's existing validated
controllers. Preferences has no system-wide shell configuration mutators or
Omarchy settings-menu routes. `LauncherPreferences` owns draft editing and a
searchable catalog backed by Quickshell's native desktop-entry collection;
`LauncherCatalog` snapshots scalar metadata without retaining removed native
entries. `LauncherListModel` reconciles those snapshots by ID instead of replacing
the view model, preserving delegates and scroll position during icon and app
refreshes. Both launcher grids and the command form limit flick momentum and
stop at their content bounds. Preferences uses the available width for app
columns and keeps selection actions below the scroll area. Omarchy's app library supplies icon fallback, but its menu filters do
not hide apps from this browser. App and command buttons can be added, removed,
and reordered. Custom command names, Bash text, working folders, terminal mode,
and curated icon IDs persist with their stable IDs.

Custom launches read only the selected, saved entry through `launcher-command`.
The helper validates the owned regular settings file, resolves the working
folder, and launches Bash through UWSM's application scope (optionally through
`xdg-terminal-exec`). User jobs have their own session and closed inherited
file descriptors; the short helper deadline does not terminate long-running
user commands. Saving, searching, and editing never execute the command.
Explicit launcher text entry temporarily raises the deck to the top layer,
requests compositor keyboard focus, and exposes a touch keyboard. Closing the overlay, changing category, or losing
host input permission releases the keyboard; the normal deck remains unfocused.

`MonitorInputController` owns optional input-switch settings in `monitors.json`.
It starts no discovery on startup, and serializes on-demand scans and switches
through the bounded `monitor_inputs.py` helper. The helper queries ddcutil and
the DRM EDID, returns scalar choices, and resolves a unique hardware identity
again before requesting VCP 0x60. Display/bus numbers and arbitrary commands are
never persisted. Missing, ambiguous, or unresponsive monitors fail visibly.
Configuration writes are atomic and revert on failure; default settings disable
the controls. Input actions also honor the overlay's disabled dashboard state.
`MonitorSetupGuide` takes first-time users through computer readiness, DDC/CI
instructions and discovery, then the shared input editor. A read-only
`monitor_setup.py check` runs through the controller's bounded process only when
the guide requests it. The explicit setup action launches an independent Omarchy
terminal running `monitor_setup.py prepare`: fixed packaged commands install
ddcutil, load i2c-dev, and reapply packaged uaccess rules. Only those system
commands use sudo; the script remains unprivileged. No package transaction is
owned or timed out by QML, and an advisory lock prevents duplicate setup runs.
The guide rechecks real readiness instead of inferring success from opening the
terminal. Neither preparation nor discovery writes an input value.

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
  pointer events only into the OmaDeck window. Each contact primes Qt's local
  hover chain with a move before the press, so the release's Leave event clears
  MouseArea highlights even when the finger never moved. The compositor's mouse
  cursor is unaffected. An explicit list of distinctive,
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

The audio mixer snapshots live PipeWire streams before presenting aggregate
category controls. Output, microphone, and category controls are statically
instantiated; there is no individual-stream repeater or category drill-down in
the current UI. Preserve this stable presentation boundary during node teardown.

## Interaction and refresh hardening

When the host exposes its `omarchy.lock` service, the deck binds its content's
enabled state to that service, resolving enabled user clones through the
plugin registry. A requested/active lock or unresolved orphan-lock recovery
disables interaction. Hosts with a capability-scoped plugin API keep
authentication services private. An optional `HostInputGuard` loader inside the
enabled user-owned lock clone can publish only a boolean through the native
library. The lock object, its context and PAM/credentials remain private.
Native guard state defaults to denied, denies ambiguous multiple publishers,
and revokes permission synchronously on lock and QML-context teardown, including
before a Loader's deferred QObject destruction. The bridge rechecks permission
for every event and cancels existing MouseArea/PointerHandler grabs on revocation.
This route works independently of compositor pointer capture and window focus.
See [host integration](../integrations/omarchy/README.md).

Without either synchronous guard, OmaDeck stops direct injection, releases
the native grab, and uses compositor-managed input, whose session-lock routing
is enforced by Hyprland. The touchscreen must be enabled and mapped to the deck
output in Hyprland for that mode. Reconnect cannot acquire a native grab without
the synchronous lock guard. The native bridge also checks the effective
enabled state of its target item and backing window, clears its synthetic
contact when disabled, and ignores motion/release from a contact begun before
unlock. Qt cancels the descendant pointer grabs; no synthetic release is used
to complete an action during lock. When direct routing is supported, the bridge
retains device ownership while locked.

Now Playing sends transport actions with the displayed player's exact Omarchy
key and verifies that the key still resolves to that object before dispatch.
It never falls back to another player when its displayed source disappears.
Play/pause follows the source's current capabilities. Status text distinguishes
playing, paused/stopped, unavailable controls, no player, and unavailable media
service. This remains an MPRIS presenter; unmatched audio streams are still
shown only in the mixer.

System snapshots run only while the System drawer is open and interaction is
allowed. Opening it requests a fresh snapshot; failed requests retain the last
good data and expose its age, a failure message, and Retry. An outer twelve-second
deadline covers locks and the complete helper, with one-second kill escalation.
Automatic retries back off from the normal two-second cadence to thirty seconds.
The mixer resolves its physical output when opened and every five seconds while
open; default-output changes invalidate the old selection, and results for a
superseded output are discarded. The stable PipeWire model remains mounted.

`scripts/check` runs the complete offscreen suite, including private native
build/CTest, real Quickshell recovery fixtures, and two synthetic MPRIS players
on a private D-Bus session. It requires an ordinary user and rejects skipped
tests. The GitHub Actions workflow runs the same command in an Arch container;
it does not install or reload a desktop plugin.

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
