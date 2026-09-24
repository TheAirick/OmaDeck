# Watch mode pre-release stress test — September 23–24, 2026

**Release held in draft. Overnight automated coverage is complete. The September
24 owner test passed the main Zen/Edge workflow and found a rapid-seek issue;
its correction is now loaded after an owner-approved reload and still needs
owner acceptance. This is not release approval.**

The product fixes and original expanded test report are committed and pushed as
`455f746acd18c665eded96247486175602d306a1`. Later commits may refine the test harness
or update this report. No owner-session reload accompanied that commit.
Its [hosted CI run](https://github.com/TheAirick/OmaDeck/actions/runs/35951870093)
also passed.

## Evidence boundary

- Real network integration runs use disposable Zen/Chromium profiles, real
  browser extensions/native messaging, real MPRIS discovery, the actual Watch
  controller and the native Qt WebEngine YouTube player rendered offscreen.
- The owner's Zen window is not exposed through the available computer-use
  connection. Its existing tabs were not automated or changed. These results
  do not certify that profile or its currently loaded temporary extension.
- Live Edge checks used OmaDeck's public panel IPC while preserving the owner's
  paused Watch session. They exercise real shell/native-layer geometry, not
  physical finger input. No shell reload, lock, monitor input switch or audio
  routing change was performed.
- The expanded suite is repeatable. YouTube network failures, unavailable MPRIS,
  fixture timing and product defects are tracked separately.

## Confirmed findings and fixes

1. **Return could pause a replacement video during navigation.** A deterministic
   content-script regression reproduced the old Return request pausing the same
   HTML video element after YouTube reused it for another ID. The error handler
   now checks ownership before pausing. Regression passes.
2. **Home/search-to-video navigation lacked extension coverage.** The content
   script only matched direct watch URLs. Both manifests now load on YouTube
   pages, while reporting only valid watch URLs. Document-port validation accepts
   the trusted YouTube origin instead of requiring a stale sender video URL.
   Invalid IDs and deceptive origins remain rejected. Chromium's corrected
   same-document navigation scenario passes; an initial fixture attempt ran
   before Home navigation settled and was discarded as invalid evidence. An A/B
   run using the original committed extension and the corrected fixture still
   failed, with the browser confirmed on the watch URL and no reporter port.
3. **Return at natural end could fail playback confirmation.** Reproduced with
   the actual Chromium/YouTube/Qt player and separately in a unit regression.
   A video ending naturally near the requested timestamp now counts as a
   successful return, without repeatedly restarting playback. If the source
   disappears during an already requested Return, Watch closes without issuing
   commands to the replacement page. Live-network Chromium retest passes.
4. **Immediate re-entry during native shutdown could be rejected.** An early
   stress run reached idle just before the old native process exited. Watch here
   now stays disabled with a brief Closing state until that process is gone.
   The integration fixture waits for this same UI readiness condition, verifies
   zero remaining owned renderer sockets/processes, and then starts the next run.
5. **Volume drawer made the monitor switcher shrink and rearrange.** Reported by
   the owner after the overnight run and reproduced on the physical Edge. A
   fixed 360-unit cutoff forced a stacked layout despite enough available room.
   The switcher now measures the label, navigation and two 64-unit touch targets
   before falling back. Regression coverage spans six widths (304–480), including
   four that failed before the fix; 11 focused monitor/responsive tests pass.
   A non-disruptive rescan retained the old live QML. The owner then approved the
   documented shell reload, which completed successfully with the fix at
   `628a0641fe3a289d84023ef7f21f108eeb34cc8b`. Shell ping and doctor passed,
   Watch returned to idle, and the browser bridge reconnected. The owner then
   confirmed that the alignment fix works after the reload.

## Results so far

| Scenario | Chromium | Zen |
| --- | --- | --- |
| Background source handoff, seek, pause/play, timestamp return | Pass | Pass |
| Captions off by default, on/off toggle | Pass | Covered by common player; no separate Zen live toggle claim |
| Ended source closed; a new document stays untouched | Pass | Pass |
| Five consecutive transfers with settled timestamp returns | Pass | Pass with corrected private-audio fixture |
| Originally paused source returns paused | Pass | Pass |
| Ended video returns with original tab still open | Pass | Pass |
| Double Watch / double Return | Pass | Pass |
| Cancel during launch | Pass | Pass |
| Thirty focus/resize cycles retaining the same native process | Pass | Pass |
| Close playing source; play and transfer a different second video | Pass | Pass |
| Navigate source to a second video; close old Watch safely | Pass | Pass |
| Return to original document while a second video plays | Pass | Pass |
| Reload source document, then close old Watch | Pass | Pass |
| Source closes during startup, then recover | Pass | Pass |
| Home-to-watch same-document navigation | Pass | Pass |
| Owned renderer killed; browser restored | Pass | Not separately exercised in Zen |
| Test browser exits; Watch cleaned up | Pass | Not separately exercised in Zen |
| Source browser offline, return to buffered timestamp | Pass | Not separately exercised in Zen |
| Source reloads offline, close Watch, reconnect and transfer again | Pass | Not separately exercised in Zen |

Chromium's final stress run passed **12/12 scenarios**, and a subsequent focused
run passed **2/2 browser-offline scenarios**, in addition to baseline, captions and
process-loss checks. Five measured handoffs took 1.402–1.404 seconds each in the
warm, offscreen fixture; this is not a cold-start timing guarantee for the Edge.
The complete repository suite passed **255 tests,
0 failures, 0 skipped**, including actual offscreen DeckSurface interaction tests,
private native builds and touch/lifecycle checks.

The live Edge passed **36 panel transitions** (three cycles through Volume,
System, Notifications, Workspaces, Preferences and Applications). Volume/System
resized the same native video layer; overlays and Applications preserved it.
The original player process, paused position and final geometry were unchanged.
The shell ping and doctor also passed afterward.

### Zen test-environment finding

After the baseline closes its original source tab, some headless Zen runs still
send valid extension candidates and play video, but no longer expose a Firefox
MPRIS player. OmaDeck correctly rejects a direct test-controller Begin without
the Now Playing player prerequisite. Do not count downstream timeouts as twelve
distinct product bugs or as passes. Determine whether this is a disposable
profile/headless browser limitation or an owner-visible browser lifecycle defect.
An independent query of the fixture's D-Bus confirmed no MPRIS service, rather
than only a missing row in OmaDeck. A ten-minute second video also failed this
prerequisite, so the observation is not limited to the 19-second sample clip.
The harness now stops dependent scenarios after two prerequisite failures.
A subsequent sequential run using a unique test host/extension ID reproduced
the missing-MPRIS prerequisite, so the earlier shared-registration collision
does not explain it.
The September 24 follow-up reproduced this with stock Firefox 156.0.1 as well
as Zen 1.22.3b (Gecko 156.0.1). Gecko's media log reported
`Delay starting: controllable source not yet audible` for subsequent videos.
The fixture had globally zeroed browser volume and provided no working audio
graph in its private runtime. This made the missing MPRIS result unsuitable as
evidence of an owner-visible browser or OmaDeck defect.

A corrected fixture uses normal internal browser volume and an actual private
PipeWire null sink. It loads no hardware discovery modules or session manager,
connects only its own test streams, and shuts down with the test. The user's
audio graph and volume remain untouched. Five consecutive Zen transfers and
settled returns then passed with real MPRIS. Subsequent scenario coverage is
recorded below. No fake MPRIS player or product workaround was introduced.
The owner's current paused session and normal shell remain healthy.

### September 24 repeat after idle

- Chromium passed all **14/14 stress scenarios** in one run, including both
  offline/reconnection cases, plus baseline/captions and renderer/browser-loss
  cleanup. Its five warm handoffs measured 1.401–1.406 seconds.
- The initial Zen repeat reproduced the original silent-fixture MPRIS failure;
  baseline and source-tab closure still passed. Dependent cases were blocked,
  not counted as product failures or passes.
- The matched stock Firefox control reproduced the same prerequisite failure.
- The corrected private-audio Zen diagnostic passed five transfers after source
  closure. Subsequent full runs exercised the remaining scenarios.
- Two initial scenario failures required fixture corrections: the short source
  reached its end while loading a second tab and the next candidate had a new
  video ID at time zero (consistent with YouTube autoplay); another case used
  the same video ID in two tabs, allowing a stale candidate to satisfy readiness.
  The ownership check now uses a long source, and the startup-closure check uses
  different IDs so it can prove which tab is selected.
- The second full Zen run passed **11/12 scenarios**. Its remaining ownership
  check exposed another fixture error: the native Qt player became the generic
  active MPRIS player. Firefox's real MPRIS service was still present, but the
  fixture asked for a Chromium candidate and got none. Both browser fixtures
  now retain the original browser's key while Watch is active, still requiring
  its real MPRIS object. The focused multi-tab Return retest then passed in
  **both Zen and Chromium**. Across the corrected full run and focused retest,
  all **12 shared scenarios have passing Zen coverage**; this is not a claim
  that the earlier 11/12 run itself passed. No additional product changes were
  needed during this follow-up.
- Cleanup verified across 11 disposable labs: no remaining test processes or
  test native-host registrations. The owner's paused Watch position remained
  237.782631 seconds; shell ping and doctor remained healthy. No owner tabs,
  shell reload, pointer events, monitor switches or store publication occurred.

## Local evidence

Logs are under `$HOME/.cache/omadeck/overnight-2026-09-23/`:

- `zen-baseline.log`, `chromium-baseline.log`: initial real-network baselines.
- `return-navigation-regression.log`, `ended-return-regression.log`: reproduced
  content-script failures before fixes.
- `chromium-stress.log`, `chromium-stress-fixed.log`: exploratory runs; retain
  their fixture and shutdown-readiness qualifications above.
- `chromium-final.log`: 12/12 stress pass plus baseline and cleanup checks.
- `chromium-offline.log`: 2/2 browser-offline/recovery passes.
- `chromium-spa-original-proof.log`: old-extension A/B failure on the corrected fixture.
- `zen-final.log`: stress investigation; inspect final results before summarizing.
- `zen-long-video.log`: same missing-MPRIS observation with a longer clip.
- `zen-unique-host.log`: sequential run with an isolated native-host identity;
  baseline passes, subsequent MPRIS prerequisite still fails.
- `fixed-check.log`: complete 255-test pass.
- `live-panels.json`: 36 live panel/geometry checks and before/after state.
- `doctor.log`: post-test host health.

Follow-up logs are under `$HOME/.cache/omadeck/overnight-2026-09-24/`:

- `chromium-repeat.log`: 14/14 stress pass plus baseline and process-loss checks.
- `zen-repeat.log`: original silent-fixture failure reproduced after idle.
- `firefox-control.log`, `firefox-media.log*.moz_log`: matched stock Firefox
  control and Gecko's inaudible-media diagnostic.
- `zen-private-audio-linked-control.log`: private-audio diagnostic, five cycles pass.
- `zen-corrected-full.log`: first private-audio full run, with the two ambiguous
  scenario failures described above.
- `zen-final-full.log`: 11/12 pass; native-player selection error in the fixture.
- `zen-pinned-source.log`, `chromium-pinned-source.log`: focused multi-tab Return
  retests with the fixture attached to its original browser.
- `chromium-long-source.log`, `chromium-distinct-source.log`: both adjusted
  ownership/startup scenarios passed independently in Chromium.
- `doctor.log`: post-repeat host health.
- `cleanup.json`: scoped process/registration cleanup and preserved owner state.

Each integration log prints its private lab directory and `stress-results.json`.
Test profiles are isolated; media/page logs contain only the public test videos.
Do not publish raw owner desktop diagnostics.

## Repeatable overnight verification

The intended 2 AM follow-up actually arrived at 1:01 AM Pacific (08:01 UTC).
The remaining one-time report was corrected to 15:00 UTC / 8 AM Pacific on
September 24. This is not an ongoing monitor.
Use a private D-Bus configuration **without service activation** so the fixtures
cannot spawn disposable desktop portals. The existing local dependency bundle is
at `/tmp/omadeck-watch-e2e/`; verify it exists before running:

```bash
export NODE_PATH=/tmp/omadeck-watch-e2e/node_modules
export OMADECK_TEST_STRESS=1
export OMADECK_TEST_FIREFOX=/opt/zen-browser-bin/zen-bin
export OMADECK_TEST_GECKODRIVER=/tmp/omadeck-watch-e2e/geckodriver
export OMADECK_TEST_CHROMIUM="$HOME/.cache/ms-playwright/chromium-1234/chrome-linux64/chrome"
dbus-run-session --config-file=/tmp/omadeck-watch-e2e/no-activation-bus.conf -- \
  node tests/manual/watch-firefox-e2e.cjs
dbus-run-session --config-file=/tmp/omadeck-watch-e2e/no-activation-bus.conf -- \
  node tests/manual/watch-chromium-e2e.cjs
```

Run Zen fixtures sequentially to keep resource/timing measurements comparable.
The Firefox/Zen fixture also requires the installed `pipewire`, `pw-dump`,
`pw-cli` and `pw-link` tools for its disposable silent audio graph.
Each now registers a distinct `.test_<pid>` native host and restores/removes it
in `finally`. Early overlapping fixture runs could restore each other's shared
`.test` registration; those two stale test-only manifests were identified,
backed up with the local evidence and removed. The normal owner registrations
were untouched. Never point test extensions at the live
OmaDeck bridge. `OMADECK_TEST_SCENARIO` selects a scenario by name substring;
Chromium also supports `OMADECK_TEST_EXTENSION_REF` for a Git-snapshot comparison.
Do not substitute simulated MPRIS for real discovery to turn a failure into a pass.

## Release and activation gates

### September 24 owner test and rapid-seek follow-up

The owner passed steps 1–5 in normal Zen on the physical Edge: background-tab
handoff, touch/player controls and drawers, updated-timestamp Return, and
closing the original browser tab while watching A, starting B, closing A on the
Edge without affecting B, then transferring B. The reported exception was rapid
forward tapping reusing the last reported playhead. The owner also requested
the circular Now Playing seek icons in Watch mode.

The correction accumulates accepted seeks from the latest pending target,
ignores stale position samples until that target settles, clamps to duration,
and expires an unconfirmed target after four seconds. Immediate Return preserves
the requested target. Watch and Now Playing now share one circular icon component.
Nine focused automated checks passed, including actual offscreen DeckSurface
touch controls and new rapid-seek, stale-report, timeout, and immediate-Return
regressions. The owner subsequently returned playback to Zen and explicitly
approved the shell reload. The reload completed; shell ping and doctor passed,
Watch was idle and available, and the browser bridge reconnected with one
candidate. No matching Watch/icon QML load errors appeared in the bounded
journal check. The rapid-seek correction and icons still need owner acceptance.

Real-network Zen and Chromium both reached 100 seconds after four rapid forward
skips from 60, then 70 after three backward skips. An added immediate Return to
140 seconds failed confirmation in both disposable browsers; Zen also failed
on a second public video. Chromium reported an unready source video afterward.
A separate Chromium control with **no extension or OmaDeck** likewise remained
seeking for all four samples over eight seconds after a direct HTML-video seek
from about four seconds to 140. This narrows the failure but does not establish
its cause or certify long-distance Return. An experimental play-before-seek-wait
change did not fix it and was reverted. Browser-extension source remains unchanged.
The owner has been asked to check a comparable larger jump on the normal profile.

Evidence: `$HOME/.cache/omadeck/rapid-seek-2026-09-24/` contains `zen.log`,
`chromium.log`, `zen-control.log`, `chromium-play-seek.log`, and `browser-only.log`.
The new optional manual scenario retains this failure for further investigation;
it is not reported as a complete passing integration run.

### Outstanding gates

- Keep v0.10.0 draft; no marketplace submission or release publication tonight.
- The overnight evidence commit `f7215ef6fa1d3dfbc08ec5263ecae084ada41a2a`
  passed hosted CI. A later run for the monitor-layout fix failed the existing
  Clock timer hold/cancel test: `slide-away` allowed an extra minute increment
  (1260 seconds versus 1200). See [the failed run](https://github.com/TheAirick/OmaDeck/actions/runs/35985884657).
  This is separate from the passing Watch scenarios and monitor-layout checks;
  its cause remains unconfirmed and needs investigation before release.
- The existing draft package still targets the original release-preparation
  commit `eaafb8d71e25a6fe3e2bae7f0f0b54c771efafbe`. Repackage/re-pin after fixes
  and verification before any release; the draft is not the tested new tree.
- The owner approved a shell reload after reporting the monitor-switcher layout
  issue. Current shell-side fixes are now loaded and health checks passed. The
  temporary browser extension received a separate reload/page refresh during
  the owner's September 24 test. Any subsequent extension fix needs another
  reload/page refresh; shell restart alone does not activate extension changes.
- The owner confirmed normal-profile Zen background-tab handoff, touch controls,
  captions, focused mode, panel navigation, current-timestamp Return, and closing
  the original tab followed by closing the old Edge session and transferring a
  second video. Rapid repeated forward taps exposed reuse of the last reported
  playhead; this correction and circular seek icons are now loaded and await
  acceptance. Do not count the correction as covered by that earlier acceptance.
- Authentication/age restrictions,
  ads, native-player network loss/recovery, lock/suspend and real monitor-input switching are
  not certified by these runs.
- The morning report must distinguish corrected fixture failures from the four
  reproduced product defects fixed earlier, and retain the owner-profile, touch
  and package gates. The original missing-Zen-MPRIS observation was resolved in
  the isolated test environment; it is not an outstanding reproduced product bug.
