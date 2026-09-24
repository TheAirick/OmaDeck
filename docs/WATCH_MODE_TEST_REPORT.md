# Watch mode test report — 2026-09-22

The feature source is in the `codex/omadeck-watch-mode` worktree, uncommitted.
On September 23 its runtime files were copied into the linked checkout for
owner testing, preserving the existing touch/system changes. The live shell
was restarted because this Omarchy version retains keepLoaded services through
plugin rescans. The bridge socket and native touch mode were verified afterward. Tests used disposable browser
profiles, private D-Bus sessions, and isolated Quickshell instances. Audio was
muted so the unattended checks did not disturb the owner.

## Observed results

| Check | Result and scope |
| --- | --- |
| Repository checks | `./scripts/check`: 246 passed, zero failures or skips. Includes actual DeckSurface QML fixtures, exact-tab acknowledgements, stalled Return, source-video changes, lock gating, layout preservation, relay framing, and existing native checks. |
| Optional renderer | `./scripts/build-watch-host` passed; Qt WebEngine local-page probe passed. |
| Chromium 151.0.7922.34 | Real YouTube page, unpacked extension, native messaging, source MPRIS, actual controller and WebEngine destination passed transfer, seek, pause/play and Return. |
| Background tab | Selecting another Chromium tab cleared the new-transfer offer. Return still resumed the session's original exact tab at the destination position. |
| Firefox 156.0.1 | Real YouTube page, temporarily installed extension, native messaging and actual WebEngine destination passed transfer, seek, pause/play and Return. Headless Firefox exposed no MPRIS player: only the presence record was a fixture. Desktop discovery is not proven. |
| Position | In the Chromium background-tab run, source paused at 3.197 s. Return from destination 8.548 s resumed source at 8.106 s. Firefox returned from 8.548 s to 8.163 s. |
| Renderer crash | Killing only the isolated watch host resumed the original Chromium tab, returned the controller to idle, and removed the stale socket. |
| Browser exit | Closing the disposable Chromium profile closed Watch mode, removed its connection, and left zero pending requests. |
| Native controls | Injected Qt touch presses exercised back/forward seek, play/pause and Return on the actual WatchMode buttons at 1600×450. This does not exercise the physical evdev device. |
| Layout | Actual QML render: nearly full-height video space left, touch controls beside it, Clock/Weather right; no clipping. The separate renderer is not included in the QML-only capture. |
| Physical placement | A short separate layer probe placed the video host on DP-3 at 768×432 with transparent input. The full dashboard/game/finger flow was not run. |
| Cleanup | Disposable browsers and shell sessions closed; temporary Firefox/Zen native-host manifests removed; no watch host remained; live shell ping returned `ok`. |

## Fixes made from these tests

- Capture the browser's actual paused timestamp and seek the destination to it
  before unmuting; a stale candidate can be several seconds behind.
- Wait for the exact extension acknowledgement even if MPRIS reports a pause
  first. MPRIS state alone cannot complete an extension transfer.
- Bound browser Return playback startup. On failure pause the browser; on an
  unknown acknowledgement timeout keep the destination paused.
- Retain the session's exact tab when browser selection changes or background
  heartbeat timers are throttled. The content script still validates the video.
- Allow graceful host shutdown, then bound it with a termination deadline;
  remove an owned stale socket after a forced renderer exit.
- Drop unused recovery acknowledgement tracking and restore paused sources
  without inadvertently starting audio.

## Reproducing the Chromium network check

Build the optional host first. Install `playwright-core` into a disposable
tools directory and set `NODE_PATH` to its `node_modules`. Use a Chromium build
that supports unpacked extensions (the test used Chrome for Testing).

```bash
OMADECK_TEST_CHROMIUM=/absolute/path/to/chrome \
  dbus-run-session -- node tests/manual/watch-chromium-e2e.cjs
```

The harness creates a `/tmp/omadeck-watch-live-*` profile and private runtime,
registers the native host only there, and exercises the real shared QML
controllers. It checks source MPRIS presence without a substitute player.
It mutes output, prints fixture-only state, and closes its processes in `finally`.
Its logs remain in the reported temporary directory for investigation. It is
an optional network check, outside the deterministic repository suite.

## Remaining limits

- Disposable Zen 1.22.2b sessions, both headed and headless, exposed no normal
  active tabs to extension APIs. This did not reproduce with stock Firefox.
  Zen's extension flow remains unverified; do not weaken exact-tab checks to
  work around the automation result.
- The long YouTube API sample stalled after seeking even in a plain Chromium
  baseline without the extension. The complete transfer checks therefore used
  the short, fully buffered public video `jNQXAC9IVRw`. Long playback, signed-in,
  restricted, advertisement and DRM behavior are not proven.
- Muted tests establish playback state sequencing, not audible gap/overlap
  quality. Physical finger interaction, game focus, live session lock, monitor
  removal and shell rescan of the installed feature still need acceptance.
- This is a YouTube implementation, not arbitrary-site video transfer.

### First hands-on correction — September 23

The owner could not find Watch here. A live DP-3 capture showed the button
rendering as transparent text over bright thumbnail lettering. Give it the
solid deck surface backing, accent foreground and normal control border.
The loaded build and connected Zen native relay were confirmed; full owner
transfer acceptance is still pending.

## Overlay, Zen return and captions correction — September 23

- Watch controls now overlay the video in OmaDeck's guarded native touch window.
  The shell moves to the Overlay layer during Watch mode and leaves a transparent
  video region; the video host stays on the Top layer below it. Touching the
  video reveals transport, timeline, CC and Return; playing hides them after
  four seconds away from the pointer. Clock and Weather stay on the right.
- Watch here moved into the title/creator strip, with space reserved for the
  button so long titles elide. It requires the browser bridge to be ready;
  the browser's MPRIS-only path did not give reliable seek completion in Zen.
- Zen sometimes omits sender.tab. A browser-owned content-script port now
  identifies the exact source document and carries acknowledgements. Commands
  still validate the current video; closed/navigated documents cannot retarget
  another tab. No additional browser permissions were added.
- Return pauses and samples the renderer on demand, seeks the exact browser
  video, waits for seek completion and playback, then closes the renderer.
  The legacy MPRIS path also waits for position confirmation and fails paused.
- A disposable Zen 1.22.2b session with real MPRIS discovery and actual browser
  extension passed handoff, seek, pause/play and Return: destination 9.062 s
  returned to browser 9.161 s. This supersedes the earlier Zen test limitation.
- Chromium passed those flows plus background-tab Return, renderer failure and
  browser exit. Captions default off and CC toggles passed. A separate renderer
  DOM check observed empty caption text when off, real caption text when on,
  then empty text after switching off. YouTube retains the selected track in
  getOption even when captions are off, so that value is not the enabled state.
- `./scripts/check` passed all 246 tests. Optional reproducible browser harnesses
  live in `tests/manual/watch-chromium-e2e.cjs` and `watch-firefox-e2e.cjs`.
  The latter needs `OMADECK_TEST_FIREFOX` and `OMADECK_TEST_GECKODRIVER` paths;
  it uses a distinct test-only native messaging name and restores registration.

The packaged browser extension must be reloaded after this update, then the
YouTube page refreshed. Owner acceptance of the new overlay remains pending.

The updated runtime was activated at 03:27 on September 23. Shell ping and
native touch diagnostics passed; the live metadata-strip button was captured.
The native video/overlay stacking was also captured on DP-3 in a short muted
probe. The old browser add-on remained connected with zero candidates until
its required reload; owner interaction with the new version is pending.

## Compact layout follow-up — September 23, 03:40

The owner confirmed transfer after closing the Omarchy scratchpad and supplied
screenshots of the active native overlay. They requested less unused width,
smaller controls, a quieter Watch here action, and an unobscured thumbnail.

- Video is anchored left at 782×440 logical pixels on the 1600×450 Edge.
  A compact Command Center uses the recovered width beside Clock and Weather.
- One 56-pixel bottom overlay holds transport, timeline, CC and Return.
  Buttons retain 44-pixel touch targets and the overlay still auto-hides.
- The title/creator footer is below the thumbnail. Watch here is borderless.
- Browser candidates remain available when the already-selected document is
  hidden by another window. Hidden documents cannot replace the selection.
  This add-on update is packaged but requires the owner's reload in Zen.
- Drawer/overlay requests wait for confirmed browser Return before altering
  video geometry; a failed Return clears the pending navigation.

Validation: 13 focused Node tests passed, including the actual DeckSurface QML
suite (47 cases), touch presses, source handoff/Return acknowledgement, layout
geometry and hidden-document candidate regression. A short muted real YouTube
probe on DP-3 confirmed compact native overlay placement. Its disposable view
had no weather data or monitor controller; live dashboard data is unaffected.
Runtime activated at 03:40 with backup in
`~/.cache/omadeck/watch-live-backups/20260923-034021-compact`.
Live shell ping passed, browser connection/candidate recovered, native touch
reported active, and the dashboard screenshot showed the unboxed action and
full thumbnail. No matching QML errors appeared in the bounded user journal.
Owner acceptance of this new layout and the reloaded scratchpad fix is pending.
Changes remain uncommitted.

## Dashboard order correction — September 23, 14:47

The owner accepted the video size and compact controls, then pointed out that
Watch mode had swapped the normal companion order. Clock/Weather now sit
immediately beside the video, with Command Center on the far right. Panel
widths, video geometry and controls are unchanged. Seven focused tests passed,
including the DeckSurface layout/touch suite. The offscreen rendered layout
confirmed the order. After the owner returned playback to the browser, the
updated WatchMode was copied to the live checkout and the shell reloaded.
Shell ping passed; native input and the browser candidate recovered. Backup:
`~/.cache/omadeck/watch-live-backups/20260923-144754-panel-order`.

## Watch here availability follow-up — September 23, 15:01

After the panel-order reload, the owner reported both touch and mouse failing
on Watch here. Live diagnostics showed an idle renderer, active native input,
one browser connection and zero candidates while the scratchpad was open.
The UI was disabling the action when only MPRIS metadata remained.

The bridge now retains a selection until explicit clear/disconnect rather
than expiring it after three seconds of throttled page timers. The extension
replays its selected connected document after native/shell reconnect regardless
of report age. Navigating away from a usable YouTube video disconnects the
content port. Transfer still revalidates the exact video at pause and uses its
actual timestamp before committing. Watch here now explains missing selection
on both mouse and touch instead of silently ignoring input.

Validation: 13 focused browser/relay/QML tests passed. A follow-up run of seven
UI boundary tests passed with a new actual DeckSurface mouse-and-touch feedback
case. Regressions cover a 120-second report gap, native reconnect, exact source
selection and closed-port clearing. The runtime was activated with backup
`~/.cache/omadeck/watch-live-backups/20260923-150143-watch-reconnect`.
The browser package is updated; owner reload/refresh and a live covered-browser
transfer are pending. Changes remain uncommitted.

## Return timestamp stabilization — September 23

The owner confirmed touch now works but reported Return jumping to the old
browser timestamp. The former content script checked currentTime only once
after play() resolved; the controller accepted ok=true without checking the
acknowledged timestamp. These were gaps in the confirmation protocol; the
owner's exact page-reset event has not been captured.

The content script now samples the resumed playhead five times over 750 ms,
validates document/video identity throughout, and retries the seek once when
the page restores its previous position. Repeated failure pauses the browser.
The existing six-second deadline bounds the operation. The controller requires
a measured timestamp within three seconds of the fresh renderer snapshot;
otherwise it retains the Edge session paused. Read-only watchState diagnostics
now expose the last requested and acknowledged Return positions.

Fifteen focused tests passed, including simulated delayed rollback, permanent
rollback, stale/missing acknowledgement and actual DeckSurface controls. A real
YouTube test in a disposable Zen profile returned from Edge 8.631 s to browser
8.766 s, then 11.753 s after three more seconds, still playing. The longer clip
probe did not reach MPRIS discovery and is not counted as a pass. The short
clip passed with actual Zen MPRIS. Tests used a private D-Bus config without
service activation to avoid starting disposable desktop portals.

Updated add-on files are packaged. After the owner returned the video, runtime
activation completed September 23 at 15:19. Backup:
`~/.cache/omadeck/watch-live-backups/20260923-151917-return-position`.
Shell ping passed and the new Return diagnostic fields are present. The browser
add-on reload and owner retry remain pending. Changes remain uncommitted.

## Owner acceptance and focused video — September 23

The owner confirmed the transfer now starts at the right timestamp on OmaDeck
and Return immediately resumes at that timestamp in Zen. They described the
current experience as solid. Load-time optimization is deferred at their request.

Added an expand/collapse action beside CC for Focus mode. It centers the existing
full-height video, hides Clock/Weather and Command Center, and makes the remaining
surface black. The native host receives only a position update, so the iframe,
process, playback state and timestamp are retained. The same touch controls
auto-hide and can be revealed by tapping the video. New sessions start in the
dashboard view; the saved dashboard layout is untouched.

The optional native host build passed. Seven focused UI tests passed, including
a new actual DeckSurface mouse/touch toggle case verifying centered geometry,
hidden/restored companions, unchanged playback position/state and no load command.
The offscreen focused layout was visually inspected. After the owner authorized
activation, a muted live DP-3 probe moved the actual video layer from x=925 to
x=1329 and back to x=925, retaining the same renderer PID and 782×440 geometry.
Playback advanced from 4 seconds to 5.131 seconds during the toggle. The probe
exited cleanly. Runtime activation completed at 15:38 with backup:
`~/.cache/omadeck/watch-live-backups/20260923-153830-focus`.
Shell ping passed; native touch and the new focused-state diagnostic are present.
No matching QML errors appeared in the bounded user journal. Owner acceptance
of the focus toggle remains pending. No browser add-on changes are required.

## Background sources, drawers and overlays — September 23

The owner reported Watch here requiring the source tab to be selected, Command
Center actions returning/closing the video, and a monitor-switching hitch.
The extension cleared selection on tab activation. DeckSurface explicitly
called Return before opening drawers or overlays. Both behaviors are removed.
A playing background page can be selected; the selected paused page is retained
across tab changes. Closed/navigated sources are cleared and exact-page commands
still validate the video identity.

Volume and System now reserve their existing animated dashboard space and resize
the video proportionally at 16:9. The native host receives bounded geometry
updates without loading another page. Notifications, Workspaces and Preferences
retain playback behind their modal overlays and keep dashboard input disabled.
Focus mode and explicit Return retain their existing behavior.

Verification:
- Browser bridge tests passed, including background playing/paused selection,
  closed/navigated page clearing and reconnect behavior.
- Seven UI test wrappers passed, including actual DeckSurface drawer geometry,
  overlay input guards, no pause/return/reload commands, and 44-pixel controls
  remaining inside the video in both drawers. Volume/System fixture images were
  inspected. These use simulated renderer replies, not physical touch.
- Native host build passed. A muted YouTube probe on the actual DP-3 layer resized
  782x440 at global (925,1445) to 730x411 at (1031,1459), then restored it with the
  same renderer PID. Playback advanced from 4 to 4.926 seconds.
- Disposable Zen with actual MPRIS passed transfer while another tab was active,
  seek and pause/play, then Return from 8.592 to 8.766 seconds; after three seconds
  the browser was at 11.753 seconds, still playing.
- Disposable Chromium passed background-tab transfer and Return, CC toggle,
  renderer-loss source restoration and browser-loss cleanup. Both harnesses use
  a private D-Bus configuration without service activation.

The monitor input helper previously ran full DDC discovery before every write.
It now validates unique connected EDID identity from kernel state and issues
one targeted DDC command with redundant support checks disabled. Disconnected,
ambiguous and corrupt identities still fail without writing; six monitor test
wrappers passed. Read-only measurements: full discovery 1.432 seconds, normal
EDID-targeted getvcp 0.832 seconds, reduced-check getvcp 0.314 seconds, kernel
identity lookup 0.41 ms. No actual input change or visual hitch reproduction was
performed. Whether the reported lag concerns selection arrows or input buttons
remains unanswered; the observed extra work was in the input-button path.

Activated at 15:54 with backup
`~/.cache/omadeck/watch-live-backups/20260923-155420-drawers-background`.
Shell ping passed, native touch is active, and the browser bridge reconnected.
No matching QML errors appeared in the bounded activation journal. The browser
package is updated; owner add-on reload and YouTube refresh are required for the
background-tab fix. Owner acceptance of this set is pending. All changes remain
uncommitted, and unrelated live checkout changes were preserved.

## Dashboard video border — September 23

The owner accepted the drawer/overlay improvements and requested the standard
OmaDeck border around video, hidden only in focused/fullscreen mode. WatchMode
now paints a transparent BorderSurface around the actual video rectangle using
the same popup border spec and corner radius as DeckCard. It follows drawer
resizing, stays visible when controls hide, and accepts no input.

Seven existing UI test wrappers passed, including dashboard, drawer and focused
layout rendering. The dashboard and focused fixture images were inspected;
`git diff --check` passed. Activation is pending because the current Watch session
is still open and paused at 1197.861 seconds, with a failed browser Return
confirmation. The owner was asked whether to reload now or return the video first.

The owner authorized reloading the paused session. Activation completed at 18:55
with backup `~/.cache/omadeck/watch-live-backups/20260923-185534-video-border`.
Shell ping passed, Watch is idle, and native touch is active. No matching QML
errors appeared in the bounded activation journal. No browser add-on reload is
needed for this visual change.

## Closing a Watch session after its source tab closes — September 23

The owner reported an ended Watch session becoming impossible to exit after
closing the original Zen tab and playing another video. Browser connection
liveness did not convey per-document closure, and Return was the only exit.

The extension now reports sourceClosed for its exact document port, even when
another document is the selected candidate. The bounded native relay forwards
that event; the controller matches both connection and document IDs. An already
loaded video stays available, with Return relabeled Close. Closing an unrelated
tab has no effect. Closure during startup cancels that startup. A small 44-pixel
Close action also remains available with the overlay controls in dashboard and
focused modes, including startup and failed/pending Return. Close does not seek,
pause or resume any browser page.

Fifteen focused test wrappers passed. New UI cases cover an ended session with
a replaced candidate, unrelated-tab closure, exact source closure, closing in
focused/launching/playing/returning states, and leaving new browser playback
untouched. Native relay and extension tests cover the document-close event.
The disposable real-Zen harness passed normal background transfer/Return, then
let an Edge video end, closed its source tab, opened a new document for the same
clip and started it at 2 seconds. Closing the old Edge session left the new
browser document playing at 2.040 seconds. Reusing the same clip additionally
checks that document identity, not only video ID, owns Return. The private bus
had service activation disabled.

During this work the owner also reported immediate startup exit. A native player
probe of their selected video reproduced YouTube error 150, independently of the
border. YouTube documents 150 as the same embed restriction as 101:
https://developers.google.com/youtube/iframe_api_reference#onError
The UI now explains embed restriction/unavailable-video failures. Startup failure
no longer sends a restore/seek to a browser that OmaDeck never paused. A regression
test verifies error 150 closes the failed destination without a browser command.
Restricted videos remain browser-only with this embedded-player implementation.

Runtime activated at 19:01 while Watch was idle. Backup:
`~/.cache/omadeck/watch-live-backups/20260923-190124-source-close`.
Shell ping and native touch passed; no matching QML errors appeared in the bounded
activation journal. Both browser packages are updated. Owner add-on Reload and
YouTube refresh are required for automatic tab-closure detection; the independent
Close action works without that update. Owner acceptance is pending. Changes
remain uncommitted.
