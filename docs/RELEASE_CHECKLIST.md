# v1 release checklist

This is an acceptance checklist, not a claim that v1 has shipped. Record the
candidate commit, installed Omarchy/Quickshell/Qt versions, commands/results,
and tester for each run. Do not mark a live gate complete from mocks or static
source assertions. Keep logs and fixtures free of private clipboard data,
window titles, credentials, and device serial numbers.

## Latest hardening run — 2026-09-04

Tested code: `7ed07db637d20b0b8de2f3607385c8450ae50b4b` on
`codex/preferences-center`; subsequent checklist-only commits do not change code.
Platform: Omarchy 4.0.2-1, Quickshell 0.3.1-1, Qt base 6.11.2-2.

- Baseline `3d4360119b328de155493c7023258d4b4b684fd5` was verified on the
  remote before any hardening edits.
- Fresh independent clone: plugin validation passed; **203 Node tests passed,
  zero failures/skips**; `scripts/build-native` completed its Release build,
  **all 3 CTests**, and installation of both artifacts. The new regression also
  verifies their checksums and starts without `native/bin`.
- Real Quickshell private-home tests verified settings across process recreation,
  failed writes followed by recovery, one overdue-timer notification claim, and
  missing-helper recovery. Clipboard tests used synthetic data and isolated
  process boundaries, never the user's private clipboard.
- Live navigation IPC exercised Preferences, both horizontal drawers, overview,
  and restoration of the prior view. A rescan still rendered stale QML; after
  Erik authorized one shell restart, a screenshot confirmed the new disabled
  legacy Clock-style label and no obvious clipping/overlap. Shell ping returned
  `ok`, doctor reported `Healthy — touchscreen connected`, Hyprland config
  errors were empty, and a bounded warning journal check had no entries.
- This is **not full release acceptance**: the clean-session public installer,
  actual player/stream interactions, human touch acceptance, upgrade/rollback,
  and disruptive hardware tests below remain unchecked. No EQ or audio routing
  changes were made; native build artifacts were installed only in temporary
  test checkouts, not over the live native bridge.

## Hardening follow-up — 2026-09-05

Candidate: uncommitted working-tree changes based on
`adcc1f8817a0bc8b65ec4a083fa8c917a03f9080`, on `codex/preferences-center`.
This entry records implementation and verification, not release acceptance.

- Transport commands target the displayed MPRIS player and respect its current
  capabilities. A private D-Bus integration fixture exercised two real
  Quickshell player objects, exact-target commands, capability changes, and
  both players disappearing without affecting desktop playback.
- The deck resolves the enabled lock implementation through Omarchy's plugin
  registry, including user clones. Missing/locked/unresolved states disable
  interaction. Native tests exercise mouse areas, tap handlers, and a nested
  target item; a gesture cancelled or started while disabled cannot execute
  after re-enabling input.
- System monitoring pauses when its drawer is closed; the mixer output helper
  refreshes only while Volume is open. Failed System updates retain the last
  good snapshot, show its age and a Retry action, and recover after malformed
  output or a failed executable launch. An outer deadline covers the complete
  snapshot helper, including file-lock waits.
- `scripts/check`: **205 tests passed, zero failures/skips**. Native Release
  build and **all three CTests** passed; the native artifacts were installed
  using `scripts/build-native`. An unrelated Clock gesture regression exposed
  by the headless Qt defaults was fixed by matching the tile's long-press
  threshold and checking interaction state at dispatch.
- Live verification included loading the rebuilt bridge, the actual enabled
  lock clone, System and Volume navigation, and visual inspection at the deck's
  current geometry. System timestamps advanced while open and stayed unchanged
  for six seconds while closed. Doctor reported a connected touchscreen, shell
  ping passed, and Hyprland configuration errors were empty. The previous
  closed-drawer view was restored.
- The GitHub Actions workflow and YAML syntax are prepared; hosted CI has not
  run because this candidate has not been pushed. The local Docker socket was
  unavailable to the test user, so no container execution is claimed.
- Still pending: actual locked-session touch acceptance, disruptive USB and
  suspend/recovery checks, clean-session public installation, upgrade/rollback,
  human acceptance, and any authorized commit/push/publication. Do not mark the
  corresponding release gates complete from the isolated fixtures above.

Rollback: restore the prior accepted source, rebuild its native artifacts with
`scripts/build-native`, then reload the shell when unlocked. These changes do
not migrate saved settings or change compositor input mapping.

## Unattended follow-up — 2026-09-05

Same uncommitted candidate and base as above. `scripts/check`: **208 tests
passed, zero failures/skips**, including the private native build and CTests.

- Published snapshot `36578b3ba701db709b69ac6dccb32e61d53e34a0` wrote layout,
  launcher, hardware, appearance, and timer-sound fixtures. The candidate read
  and saved those settings; rolling back to the published controllers preserved
  all JSON values. This is controller/storage compatibility, not full installed
  UI or native ABI rollback acceptance.
- A private D-Bus ran 100 cycles of two real MPRIS players appearing and
  disappearing, with the production Now Playing component recreated each cycle.
  Each cycle verified exact-player commands, capability changes, missing players,
  and a missing media service. After warmup, fixture and Quickshell descriptor
  counts stayed within a two-descriptor band; Quickshell had no helper children.
  This is a bounded stress test, not proof of indefinite uptime or PipeWire safety.
- A real Process/Timer fixture rejected a 512 KiB System response at the 256 KiB
  bound, killed a helper ignoring SIGTERM within the outer deadline, verified
  that helper was gone, retained the last good snapshot, and recovered on retry.
  Another fixture exercised rapid output changes and disappearance while the
  mixer resolver was running; late results were discarded.
- The rehearsal found a timer-sound persistence defect: an identical FileView
  write emits no saved signal. Confirmed disk bytes now make reselecting a saved
  sound succeed. Failed sound saves invalidate the comparison cache before retry.
  Real read-only-file failure/recovery and upgrade/rollback tests cover this fix.
- The installed Omarchy add/validate/enable CLI path cloned public `main` into a
  temporary HOME, validated it without native binaries, and reached the expected
  enable request. Shell IPC was deliberately stubbed; no live installation or
  clean-session rendering is claimed. Resolved SHA was
  `36578b3ba701db709b69ac6dccb32e61d53e34a0`, still older than this candidate.
- A non-disruptive plugin rescan completed; shell ping and doctor passed,
  Hyprland configuration errors were empty, and the bounded shell warning
  journal had no entries. The timer-sound fix was exercised offscreen; no shell
  restart or human touch acceptance is claimed for this follow-up.
- CI dependency/history requirements were reviewed; `fetch-depth: 0` is required
  by the pinned rollback fixture. Hosted/container execution remains pending,
  as do a clean-session installation and human/hardware acceptance. No changes
  were committed, pushed, or published during this follow-up.

Marketplace installation status and the existing request are documented in
[Marketplace installation](MARKETPLACE.md). Do not open a duplicate request or
mark the clean-install, hardware, or publication gates complete from these checks.

## v0.8.0-rc.1 packaging — 2026-09-06

The release notes in `docs/releases/v0.8.0-rc.1.md` cover the full change since
v0.7.2: Preferences and installation, timer/presentation improvements, and all
subsequent hardening. Manifest and weather user-agent versions match the
candidate. `scripts/check` passed **208 tests with no failures or skips** before
packaging, including the clean native build and all three CTests.

This is a prerelease while human touch/lock, device recovery, and clean-session
acceptance remain pending. Hosted CI must pass on the final candidate before
publishing its tag. Keep the stable/default install path on the existing main
branch until the accepted candidate is promoted. Record the final SHA and CI
links in the GitHub release and the existing marketplace request; those external
records avoid self-referential commit hashes in source files.

## v0.8.0 human acceptance — 2026-09-07

Erik reported that all steps in the supplied v0.8 acceptance pass passed on the
Corsair Xeneon Edge, and authorized final automated checks and submission.
The tested candidate was `44c1d2e47f13e75b3ddeb9eabf42d568679de216`.
This records user-reported acceptance of touch/layout, timer, media/audio,
System/Clipboard, Preferences persistence, lock/unlock, USB recovery,
suspend/resume, and fresh-session behavior; it is not an independently observed
repetition or a claim about other hardware. Final packaging changes only the
version metadata and release documentation.

The clean public default-branch installation remains a separate verification:
the install command still resolved to the prior main at the time of acceptance.
Isolated failure injection and controller upgrade/rollback have automated
evidence above; a full installed UI/native rollback is not claimed here.

Final automated validation passed on September 7: `scripts/check` completed
208 tests with zero failures/skips, including its private native Release build
and three CTests. Installed Omarchy manifest validation passed. On Omarchy
4.0.2-1, shell ping returned `ok`; doctor reported healthy with a connected
touchscreen, an active exclusive bridge grab, and matching native artifact
integrity. Hyprland configuration errors were empty and the bounded Quickshell
warning journal had no entries. No disruptive tests were repeated by the agent.
Hosted checks and marketplace analysis are bound to the final published SHA in
the release and submission, rather than a self-referential SHA in this file.

## v0.8.1 release verification — 2026-09-10

The current compatibility patch adds the shared MPRIS fallback and synchronous
native host input guard for Omarchy's restricted plugin API. `scripts/check`
passed 212 tests with zero failures/skips, including a private native Release
build and all three CTests. Guard coverage exercises lock phases, conflicting
publishers, provider unload, deferred QML destruction, and cancellation of
MouseArea/TapHandler contacts. Real MPRIS fixtures exercise exact-player fallback
actions and disappearance. Installed Omarchy manifest validation passed.

Live Omarchy version: `4.0.0.r2083.gd504061-1`. The running surface reports
`inputMode: native`, a present/allowing host input guard, interaction enabled,
and `mediaProvider: mpris` with an active player. Doctor confirms the active
exclusive touchscreen grab and matching native artifact integrity; shell ping
passes, Hyprland configuration errors are empty, and the bounded warning
journal has no entries. This verifies current live state without changing
desktop playback or initiating a lock/reconnect/suspend cycle. The prior v0.8.0
manual acceptance is not claimed as a fresh v0.8.1 hardware test.

The release request authorizes publication of the latest build. Final hosted
CI and marketplace results are linked to its exact SHA in the release PR and
submission. The user-owned lock integration remains optional; standard mode
requires no compilation. Setup documentation now consistently keeps the actual
touchscreen enabled and mapped for compositor fallback.

## v0.9.0 release verification — 2026-09-15

The user requested publication of the accumulated dashboard, workspace,
monitor-switching, notification, audio, timer, and launcher changes after local
use and refinement. This is authorization to release; it does not imply that
all generic v1 acceptance gates below were repeated.

- `scripts/check`: **237 tests passed, zero failures/skips**, including the
  private native Release build and three CTests. The release run is repeated
  after final packaging and is bound to the exact pushed commit through CI.
- Launcher regression testing first reproduced metadata refresh resetting a
  scrolled list to the top, then verified position/delegate retention with the
  stable model. Rendered tests cover wide/compact layouts, bounded swipes,
  search reset, end-of-content bounds, and drag-versus-activation behavior.
- Isolated launcher persistence tests cover migration, recreation, edits, and
  removal without rewriting the old settings. Command tests exercise quoting,
  working folders, terminal arguments, immediate failure, and detached jobs;
  saving/editing never executes a command.
- Live Omarchy `4.0.0.r2131.g86a2e58-1`, Quickshell 0.3.1, Qt 6.11.2: the updated
  launcher was inspected after shell reload; ping returned `ok`, doctor reported
  a healthy connected touchscreen, guarded native touch was active, and
  Hyprland configuration errors were empty. The bounded OmaDeck warning scan
  was empty; unrelated host Bluetooth-plugin teardown warnings are outside this
  release’s evidence.
- No fresh lock/suspend/USB-disconnect cycle or clean-session installation is
  claimed. Broader monitor compatibility, multi-timer support, and workspace
  previews remain outside this release.

Rollback: restore the previous source and rebuild matching optional native
artifacts before reloading. The old layout/launcher files are retained; new
settings stay in separate files, so an old release cannot erase custom commands
or the new dashboard layout. GitHub release notes record exact commit/CI links;
marketplace promotion is tracked separately against that published SHA.

## Automated gates

- [x] `git diff --check` passes.
- [x] `node --test tests/*.test.js tests/*.test.mjs` passes without skipped tests.
- [x] Native Release build and CTests pass. Use `scripts/build-native` only when
  installing new local artifacts is intended; otherwise use a private CMake
  build directory with `BUILD_TESTING=ON` and run `ctest --output-on-failure`.
- [x] Clipboard regressions cover long text, identical previews/different full
  values, changed history, failed actions, and original-content fidelity.
- [x] Media tests cover external/rejected seeks, player and track changes,
  missing duration, and return from optimistic display to authoritative state.
- [x] Persistence tests cover failed saves, recovery/retry, and reloading the
  stored result. Timer completion must not duplicate after recovery.
- [x] Helper launch failures leave a visible recoverable state; retries remain
  bounded, including when the executable itself cannot start.
- [x] Preferences tests exercise constrained geometry with long/many hardware
  names and distinguish action requests from confirmed persistence.

## Clean installation and upgrade (test session or disposable host)

A new clone is not proof of a successful installed plugin. Use a separate
Omarchy session/host rather than modifying the primary user's plugin registry
or replacing the running checkout without permission.

- [ ] Install the candidate with the supported `omarchy plugin add ... --enable`
  path in a clean test session and record the resolved commit. The published
  one-line command must resolve to the intended release, not an older default
  branch. No compiled plugin or integrity record may be required in standard mode.
- [ ] With missing user settings, select suitable connected displays; configure
  them through Preferences without editing source files.
- [ ] Verify standard compositor-managed touch on the selected display. Native
  touchscreen selection is optional and must be labeled accordingly.
- [ ] Save layout, launcher, hardware, appearance, and timer sound settings;
  reload the plugin and verify the persisted values and visible result.
- [ ] Upgrade from the prior release with saved settings, verify migration or
  compatible loading, and exercise rollback to the saved prior checkout/config.
- [ ] Build and load optional native integration, confirm tray and isolated
  touch work, then verify documented return to standard mode with matching
  compositor input mapping. Do not disable a touchscreen blindly.

## Live functional and touch acceptance

Announce GUI interactions before taking control. Use synthetic clipboard items
and an isolated media fixture where possible. Never interrupt private calls or
playback, overwrite a real clipboard, lock, suspend, or disconnect devices for
a test without permission.

- [ ] Open and close all drawers/overlays; preserve the underlying layout and
  horizontal drawer. Verify gestures, mouse fallback, and full touch targets.
- [ ] Exercise Clock/timer start, pause, resume, cancel, completion, and sound
  preview; confirm the actual notification/chime path at an agreed volume.
- [ ] Exercise Now Playing seeks and transport against a real MPRIS player.
- [ ] Exercise output/mic/category volume and mute with test streams. Device
  removal/reappearance and third-party DSP compatibility are separate tests;
  do not infer them from a responsive slider.
- [ ] Copy/delete synthetic long clipboard entries and verify full restored
  bytes without changing an unrelated history item. Image payload retention
  is intentional and documented.
- [ ] Exercise Preferences handoff to Omarchy menus/panels and return; confirm
  the selected setting actually applies. Test unavailable service feedback.
- [ ] Test read-only settings storage and helper launch failure in an isolated
  session, then restore access and verify recovery without duplicate effects.
- [ ] With approval, test missing deck monitor, USB reconnect, suspend/resume,
  and shell recovery. Confirm bridge ownership is not leaked or duplicated.
- [x] `scripts/omadeck-doctor`, shell ping, Hyprland config errors, and a bounded
  journal check agree with the visible result.
- [ ] Erik accepts the final touchscreen behavior; record other hardware results
  separately rather than claiming universal compatibility.

## Publication

- [x] User-facing docs describe current controls, limits, optional dependencies,
  standard/native modes, and tested platform versions accurately.
- [x] Relevant tests run in CI or their manual execution evidence is attached
  to the candidate. CI not being configured is not a passing check.
- [ ] Commit and push the accepted candidate; read the exact remote ref back
  and verify its full SHA before reporting success.
- [ ] Publish/tag only with explicit authorization. If tracked on Kanban, add
  card-specific evidence and remaining gates before moving an accepted card
  to done; implementation alone is not release acceptance.
