# Historical design: Watch mode

Status: source remains in the isolated worktree; runtime files are active in the
owner's linked checkout for hands-on testing. Real YouTube transfer and Return passed with disposable
Chromium, stock Firefox and Zen profiles. Automated touch input and a brief physical
layer placement probe pass. Physical finger input and audible playback acceptance remain pending. See [test report](WATCH_MODE_TEST_REPORT.md).

## Intended experience

- A **Watch here** action in Now Playing transfers the displayed YouTube video
  from Firefox, Zen, or Chromium to the Xeneon Edge near its current position.
- Now Playing stays on the left and grows to fit a 16:9 picture. Clock and Weather
  stay beside the video, with a compact Command Center on the far right. The video uses nearly
  the full display height, with native touch controls overlaid on the video and hidden during playback.
  At the Edge's current 1600×450 logical resolution, a 16:9 picture can use
  782×440 inside the outer gaps without cropping. A single 56-pixel overlay
  row holds transport, timeline, CC and Return with 44-pixel touch targets.
- The expand button beside CC toggles Focus mode: the same full-height video
  moves to the center, Clock/Weather and Command Center hide, and the surrounding
  area turns black. Tap the video to reveal controls and use collapse to restore
  the dashboard. Switching modes keeps the same renderer and playback position.
- Playback has one owner at a time. The source browser pauses only after the
  destination reports that the same video is ready. **Return** seeks and resumes
  the exact extension tab and waits for its acknowledgement before closing the
  Edge player. The MPRIS-only path targets the exact player bus name.
- Watch mode is temporary presentation state; it never saves a replacement
  `dashboard-layout.json` or changes the user's chosen layout.

## Evidence and platform boundary

- The current Zen MPRIS player exposed an `xesam:url` YouTube watch URL and
  `Position`. That is enough to offer a YouTube-only action without an add-on
  for this source. Other browser versions may expose less information.
- Qt Multimedia's `MediaPlayer` and `VideoOutput` loaded and played a generated
  local video in an isolated Quickshell 0.3.1 process. A YouTube watch page is
  not a direct media URL.
- Creating `QtWebEngine.WebEngineView` crashed an isolated Quickshell 0.3.1
  process. Qt documents `QtWebEngineQuick::initialize()` before creating the
  `QGuiApplication`; OmaDeck is loaded into the already-running shell. A
  standalone Qt WebEngine process loaded a local test page successfully. A
  second isolated Quickshell probe called `QtWebEngineQuick::initialize()`
  through a temporary native QML plugin before constructing `WebEngineView`;
  it still crashed with an empty Qt command-line argument fatal error. The
  standalone app remains the viable tested boundary.
- Corsair's iCUE widget specification identifies Qt WebEngine/Chromium as its
  HTML runtime. Its built-in YouTube widget accepts video and playlist links.
  The independent MIT-licensed YoutubeToXeneon project demonstrates a browser
  video-ID/time handoff to a YouTube IFrame API player with touch controls.
- OmaDeck's native touch bridge exclusively grabs the direct touchscreen and
  injects events into the shell. A separate video process cannot receive that
  input until a safe routing handoff is proven on the live Xeneon Edge.

## Implemented first slice: YouTube

1. `WatchController.qml` owns the bounded session state and exact source
   identity. It rejects unsupported URLs and disconnected browser sources and does
   not log titles or full URLs.
2. The separately built, on-demand Qt WebEngine host loads the official YouTube
   IFrame player with an off-record profile. It starts muted at the captured
   position and reports actual playing state through an owner-only Unix socket.
   OmaDeck pauses the source only after the destination plays, then unmutes it.
3. `WatchMode.qml` replaces only the presentation of the saved center split.
   It leaves the 16:9 video nearly full height on the left, OmaDeck touch
   transport controls overlaid on it, followed by Clock/Weather and Command
   Center in the normal dashboard order. Volume and System reserve space and
   resize the existing video as they slide out. Notifications, Workspaces and
   Preferences overlay the continuing video with dashboard input guarded.
   Explicit Return restores the original split without writing layout state.
4. A shared WebExtension reports a selected YouTube tab and executes pause and
   return commands against that exact tab after validating the video ID again.
   Firefox and Chromium have separate Manifest V3 entry points; both use the
   same scripts and owner-only native messaging relay.
5. Source loss, lock, monitor removal, host error, and shell teardown close the
   child host. Browser exit and renderer crash recovery passed live isolated
   checks. Full physical touch and audible handoff still require acceptance.

## Browser coverage

The Now Playing button prefers a fresh, exact-tab WebExtension candidate when
available. A browser bridge is required for the Watch here action so Return can confirm
the exact document and updated timestamp. Chromium does not currently publish that URL
through its standard MPRIS service, so the extension is required there. The
extension reports only video ID, current time, playback state, and tab identity.
The browser's native-host manifest restricts the extension ID; the relay
validates bounded messages and exposes no TCP listener. The extension is a
source adapter; the video renderer belongs to OmaDeck's on-demand host.

## Build and local setup

For current installation instructions and limitations, use [Watch setup](WATCH_MODE.md).

Run `./scripts/build-watch-host` from the intended OmaDeck checkout. It builds
the optional Qt 6 WebEngine / LayerShellQt host into ignored `native/bin/`.
Without it, **Watch here** is unavailable and the rest of OmaDeck still works.
Run `./scripts/package-watch-extension` to make unpacked Firefox and Chromium
packages under `${XDG_CACHE_HOME:-~/.cache}/omadeck/watch-extension/`.

For Firefox, load the generated Firefox `manifest.json` as a temporary add-on
for development, then run `./scripts/install-watch-native-messaging` to register
the owner-side native host. Permanent Firefox distribution requires normal
add-on signing. For Chromium, load the generated Chromium directory as an
unpacked extension, copy its ID from `chrome://extensions`, and run
`./scripts/install-watch-native-messaging --chromium-id ID`. This writes the
Firefox and Chromium native-host manifests under the user's home; it does not
install either browser extension. Relaunch or reload the extension after
registering the native host. Packaging and registration have been exercised
with disposable profiles. The temporary Firefox/Zen user-level native-host
registrations were removed after testing; the owner's profiles were unchanged.

The host is an optional separate process because Qt WebEngine must initialize
before a Qt application starts; the already-running Quickshell cannot provide
that boundary. It is not a persistent daemon. Closing Watch mode or losing the
OmaDeck socket ends it.

## Verification so far

- Repository check: 246 tests passed with zero failures or skips after the
  browser handoff, background-tab Return, timeout, and cleanup changes.
- Standalone WebEngine local-page probe passed. An offscreen IFrame session for
  YouTube's public API sample reached a playing `primed` event in about 5.3 s.
- A short physical monitor probe placed the host's transparent-input layer on
  DP-3 at the requested 768×432 rectangle and exited cleanly. It did not
  activate the full OmaDeck UI or test touch/audio handoff.
- An isolated Quickshell 0.3.1 instance accepted a Chromium candidate over the
  real Unix socket. The framed native messaging relay passed a roundtrip test.
- Chromium passed real MPRIS discovery, extension handoff, seek, pause/play,
  Return to the original background tab, renderer crash, and browser exit.
- Stock Firefox passed the actual extension/relay/renderer transfer and Return;
  its headless test used a stand-in MPRIS presence record. Desktop Firefox
  discovery and Zen's extension behavior are not established by that check.
- Injected Qt touch events exercised the actual control buttons at 1600×450.
  The rendered QML layout kept full-height video space and readable companions.

## Acceptance gates

- Firefox/Zen and Chromium each transfer a standard YouTube video within two
  seconds of the source position, without two simultaneous audio streams.
- The video occupies almost the full logical height; Clock and Weather remain
  readable; Command Center returns exactly as it was.
- Touch play/pause, seek, and Return work on the physical Edge while a game
  remains focused on the primary display.
- A failed load, browser exit, monitor removal, shell rescan, and session lock
  leave no orphaned watch host or grabbed input device. These lifecycle cases
  need live verification; direct-touch re-enumeration requires owner approval.
- No source title, full URL, or playback history is persisted or written to
  shareable diagnostics. The original dashboard layout file is unchanged.

## Reference implementation boundary

YoutubeToXeneon's idea is useful, but its Chrome-only extension, broad localhost
HTTP server, title logging, and pause-before-success behavior should not be
copied into OmaDeck. Any code copied from its MIT repository must retain its
copyright and license notice. The intended implementation should be small,
source-aware, and governed by OmaDeck's shell and lock lifecycle.

References: Corsair iCUE widget specification, Corsair Xeneon Edge widget
guide, YouTube IFrame Player API, Qt WebEngine QML initialization documentation,
and `https://github.com/Ripolin99/YoutubeToXeneon`.
