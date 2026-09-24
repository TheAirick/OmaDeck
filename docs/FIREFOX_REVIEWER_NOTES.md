# OmaDeck Watch — reviewer notes

## Purpose and platform

Unlisted companion extension for OmaDeck, an MIT-licensed touchscreen command
surface for Omarchy Linux. It transfers a YouTube video into OmaDeck's native
embedded player and returns playback to the original document and current
timestamp. There is no independent browser toolbar UI. The user invokes
**Watch here**, playback controls and **Return** on OmaDeck.

The extension requires Firefox desktop 140+ (also tested with Zen), the OmaDeck
plugin, its optional Qt WebEngine Watch host, and the registered Python native
messaging relay. It does not support Android, Windows or macOS. No OmaDeck
account, subscription or YouTube login is required for public embeddable videos.

## Source and build

`submission.json` in the preparation kit identifies the exact Git commit and
source URL. `companion-source.zip` contains that snapshot of the entire app.
The extension's `background.js` and `content.js` are original readable source;
there is no bundler, minification, remote executable code or third-party library.
The packaging helper copies the two JavaScript files, Firefox manifest, README,
privacy notice and MIT license into the unsigned ZIP without modifying code.

App setup and dependencies: `docs/WATCH_MODE.md` in the source snapshot.
Native relay: `scripts/browser-watch-native-host`.
Host registration: `scripts/install-watch-native-messaging`.
Local receiving service: `services/BrowserWatchBridge.qml`.
Native player: `native/watch/` (Qt WebEngine / YouTube embedded player).

## Permissions and data

`nativeMessaging` is needed to communicate with `pretty.omadeck.watch`. No
history, cookies, storage or tabs permission is requested. Basic tab events and
active-tab queries do not access privileged tab properties. Content scripts
match www.youtube.com and m.youtube.com to support YouTube's same-document
navigation; they report only validated `/watch?v=` video identifiers.

The consent declaration requires `browsingActivity` for the video ID and
`websiteActivity` for playback time/state. These reports start while enabled,
before Watch here is pressed, to make the dashboard action available. They go
to the local app through native messaging and an owner-only Unix socket.
Temporary document/request IDs, acknowledgements and a browser-family protocol
label are used only for routing and handoff; no telemetry is collected.
The scripts do not transmit page text, thumbnails, video bytes, search terms or
cookies. Full details, including YouTube player and GitHub update requests,
are in the included `PRIVACY.md`. Mozilla's classification may be reviewed;
local native messaging is deliberately not declared as “no data.”

## Manual verification

1. Install the OmaDeck plugin on Omarchy Linux. Build the optional Watch host
   and register the native relay using `docs/WATCH_MODE.md`. Install this add-on
   in Firefox and accept its installation consent prompt.
2. Open a public, embeddable YouTube watch page, play and seek to 60 seconds.
3. Press **Watch here** on the OmaDeck Now Playing panel. The browser pauses and
   the native player begins near that position. Advance at least 20 seconds.
4. Press **Return**. The original browser video seeks to the newer position and
   resumes. Repeat while the source tab is in the background.
5. Transfer again, close the source tab and open a different video. OmaDeck's
   **Close** must still dismiss the old session without touching the new video.
6. Navigate YouTube Home → watch without refreshing; repeat the round trip.

For review without a physical Edge display, the repository's isolated manual
fixtures `tests/manual/watch-firefox-e2e.cjs` and `watch-stress-scenarios.cjs` exercise
real browser/native playback with disposable profiles. Consult
`docs/WATCH_MODE_OVERNIGHT_REPORT.md` for exact prerequisites and evidence;
these fixtures do not establish physical touchscreen acceptance.

There is no reviewer account to supply. Contact the maintainer via the Mozilla
submission or https://github.com/TheAirick/OmaDeck/issues if the Linux companion
environment prevents testing.
