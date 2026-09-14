# Roadmap

OmaDeck is useful today but remains an early, hardware-specific project. This
roadmap is directional rather than a release promise.

## v1 release hardening

Keep existing feature scope fixed while validating clipboard action fidelity,
media synchronization, settings failure feedback, and recovery from unavailable
helpers. Fresh-install, upgrade, persistence, and real touchscreen acceptance
are release gates, not implied by passing unit tests. See
[Release checklist](docs/RELEASE_CHECKLIST.md).

## Later candidates (not v1 requirements)

- Resize and choose glyphs for launcher entries
- Persistent drawer preferences and left/right module selection
- Whole-process-tree accounting for multi-process applications
- On-demand sortable storage usage scan
- Better empty, loading, and unavailable states
- Broader hardware testing and installer validation

## Interaction system

- **Implemented, awaiting touchscreen acceptance — explicit layout customization
  and timer holds (reported 2026-09-13).** Preferences → Dashboard → Customize
  moves all four panels independently, offers edge placement and tap/drop swaps,
  resizes dividers, and has Done/Cancel. Normal dashboard long presses no longer
  enter layout editing. Timer duration buttons repeat and accelerate while held,
  stopping on release, cancellation, hide, or disable. Validate the feel on the
  physical touchscreen before release closeout.
- Pin or float modules inside the split tree
- Touch-first resizing and placement refinements
- Contextual modules triggered by media, microphone, timer, or warning state
- Configurable top/bottom drawer assignment
- Additional notification and timer presentation options
- **Timer sound selection — requested 2026-09-13.** Replace the small set of
  generic system events with a curated choice of soft chimes and audible alarms,
  a named list with individual previews, consistent loudness, and Silent.
  **2026-09-13 update:** Erik auditioned and selected KDE Ocean's
  `alarm-clock-elapsed` as the default. Bundled unchanged under CC-BY-SA-4.0
  with attribution in `assets/sounds/`; named selection and preview are in
  Preferences → Timer. A larger curated library and loudness matching remain
  future work.

## Integrations

- Home Assistant controls
- Download and transfer status
- **Configurable monitor inputs — in local validation (2026-09-13).** Optional
  Command Center controls, detected monitor/input choices, device labels, atomic
  per-user settings, and DDC requests matched to hardware identity. Awaiting
  owner acceptance and the next release commit.
- Optional agent integrations without duplicating Omarchy's agent UI

## Presentation

- **Window previews — feasibility checked 2026-09-13.** Quickshell's native
  `ScreencopyView` captured a Steam window from another workspace without
  activating it; live capture also initialized. Preview presentation is not yet
  implemented. Start with stills refreshed on opening, with optional live mode
  later. Verify inactive-app update behavior, aspect ratio, GPU cost, window
  removal, and capture teardown on closing/locking before activation.

- Screenshots across multiple Omarchy themes
- Versioned releases and changelog

## Completed foundations

- Crash-safe touch ownership and PipeWire stream teardown
- Output and microphone device selection with immediate picker tab switching
- Theme-aware secondary text contrast with a 4.5:1 floor
- Responsive module density and synchronized drawer retiling
- Persistent touch settings for Clock/Weather appearance
- Current weather with Omarchy-shared location, condition glyphs, and forecast
- Mouse-accessible tray diagnostics and touch reconnection
- OmaDeck-only Preferences: Dashboard, Timer, Display & touch, and Launcher
- Add, remove, and reorder application launcher entries
- Notification and workspace overlays; persistent single countdown

EQ and audio-preset integrations are deferred. Volume, mute, device selection,
and aggregate mixing remain the audio scope; an optional external-backend integration can be
considered separately if users request it.
