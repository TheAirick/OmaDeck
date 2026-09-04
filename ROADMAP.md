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

- Pin or float modules inside the split tree
- Touch-first resizing and placement refinements
- Contextual modules triggered by media, microphone, timer, or warning state
- Configurable top/bottom drawer assignment
- Additional notification and timer presentation options

## Integrations

- Home Assistant controls
- Download and transfer status
- Configurable monitor/DDC profiles
- Optional agent integrations without duplicating Omarchy's agent UI

## Presentation

- Screenshots across multiple Omarchy themes
- Versioned releases and changelog

## Completed foundations

- Crash-safe touch ownership and PipeWire stream teardown
- Responsive module density and synchronized drawer retiling
- Persistent touch settings for Clock/Weather appearance
- Current weather with Omarchy-shared location, condition glyphs, and forecast
- Mouse-accessible tray diagnostics and touch reconnection
- Preferences hub with detected display/native-touch selection and Omarchy handoffs
- Add, remove, and reorder application launcher entries
- Notification and workspace overlays; persistent single countdown

EQ and audio-preset integrations are deferred. Volume, mute, and aggregate
mixing remain the audio scope; an optional external-backend integration can be
considered separately if users request it.
