# v1 release checklist

This is an acceptance checklist, not a claim that v1 has shipped. Record the
candidate commit, installed Omarchy/Quickshell/Qt versions, commands/results,
and tester for each run. Do not mark a live gate complete from mocks or static
source assertions. Keep logs and fixtures free of private clipboard data,
window titles, credentials, and device serial numbers.

## Automated gates

- [ ] `git diff --check` passes.
- [ ] `node --test tests/*.test.js tests/*.test.mjs` passes without skipped tests.
- [ ] Native Release build and CTests pass. Use `scripts/build-native` only when
  installing new local artifacts is intended; otherwise use a private CMake
  build directory with `BUILD_TESTING=ON` and run `ctest --output-on-failure`.
- [ ] Clipboard regressions cover long text, identical previews/different full
  values, changed history, failed actions, and original-content fidelity.
- [ ] Media tests cover external/rejected seeks, player and track changes,
  missing duration, and return from optimistic display to authoritative state.
- [ ] Persistence tests cover failed saves, recovery/retry, and reloading the
  stored result. Timer completion must not duplicate after recovery.
- [ ] Helper launch failures leave a visible recoverable state; retries remain
  bounded, including when the executable itself cannot start.
- [ ] Preferences tests exercise constrained geometry with long/many hardware
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
- [ ] `scripts/omadeck-doctor`, shell ping, Hyprland config errors, and a bounded
  journal check agree with the visible result.
- [ ] Erik accepts the final touchscreen behavior; record other hardware results
  separately rather than claiming universal compatibility.

## Publication

- [ ] User-facing docs describe current controls, limits, optional dependencies,
  standard/native modes, and tested platform versions accurately.
- [ ] Relevant tests run in CI or their manual execution evidence is attached
  to the candidate. CI not being configured is not a passing check.
- [ ] Commit and push the accepted candidate; read the exact remote ref back
  and verify its full SHA before reporting success.
- [ ] Publish/tag only with explicit authorization. If tracked on Kanban, add
  card-specific evidence and remaining gates before moving an accepted card
  to done; implementation alone is not release acceptance.
