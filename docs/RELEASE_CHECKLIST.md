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
