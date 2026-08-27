# OmaDeck Agent Guide

## Purpose

OmaDeck (`pretty.omadeck`) is Erik Holum's touch-native command surface for Omarchy Quattro. It is a keep-loaded service inside Omarchy's single long-running Quickshell process, not a web app or standalone daemon. It targets a Corsair Xeneon Edge touchscreen and integrates directly with Hyprland, PipeWire, MPRIS, Omarchy services, and input devices.

Read this file before editing. Then read the documents relevant to the task:

- `docs/ARCHITECTURE.md` — runtime structure and native integrations
- `docs/CONFIGURATION.md` — monitor, touch, and user configuration
- `docs/TROUBLESHOOTING.md` — known failure modes and diagnostics
- `CONTRIBUTING.md` — design and verification expectations
- `.agents/project/omarchy-host.md` — live target and platform authority

## Authority

1. Current repository code, tests, build scripts, and Git state.
2. Reproduced behavior on the live Omarchy host.
3. User-owned live plugin/config under `~/.config/omarchy/` and `~/.config/hypr/`.
4. Installed Omarchy source and official guides under `/usr/share/omarchy/`, matched to the installed version.
5. Official version-matched Quickshell, Qt, Hyprland, Arch, and component documentation.

Never modify `/usr/share/omarchy/`. Never assume packaged defaults deep-merge into `~/.config/omarchy/shell.json`.

## Repository Map

- `manifest.json` — plugin metadata; ID is `pretty.omadeck`, kind is `service`, `keepLoaded` is true.
- `Service.qml` — screen selection and persistent service ownership.
- `components/DeckSurface.qml` — layer surface, drawers, IPC, and tiling bounds.
- `components/` — reusable visual and interaction primitives.
- `modules/` — launcher, media, audio, workspaces, system, monitor, clock, and command-center surfaces.
- `services/LayoutController.qml` — validated atomic layout persistence.
- `services/AppearanceController.qml` — validated atomic Clock/Weather presentation persistence.
- `services/WeatherController.qml` — provider refresh and normalized weather state.
- `scripts/` — small on-demand bridges, native build, tray launcher, and diagnostics.
- `native/` — Qt 6 C++ touch bridge, QML plugin, and system-tray application.
- `docs/` — user, configuration, architecture, and troubleshooting authority.

Generated `native/build/`, `native/bin/`, QML caches, logs, and the native plugin binary are not source and must not be committed.

## Working Tree Safety

Always run `git status --short --branch` before edits. Preserve Erik's unrelated changes and untracked files. Do not delete or rewrite `.worktrees/`, `IDEA.md`, generated state, branches, or worktrees unless the task explicitly requires it. Use an isolated worktree for parallel editing agents. Do not commit, push, publish, tag, or open a PR unless requested.

## Kanban Closeout

A coding card is not done merely because its implementation or tests are done. Close it out in the same workflow once all of the following are true:

1. The scoped behavior is implemented and every named acceptance criterion has been exercised.
2. Relevant automated tests and live checks pass, and Erik has accepted the result when human acceptance is required.
3. The accepted change is committed and pushed to the authoritative remote branch, and the remote commit SHA is verified.
4. The card receives one final context entry containing the full commit SHA, the card-specific result, tests and live verification, acceptance state, and any remaining risk or rollback path.
5. Only then is the card moved to `done`; read it back afterward to verify the final status and context.

When one commit resolves multiple cards, close every resolved card separately and give each its own card-specific final context. Never leave accepted, merged work in `ready`, `running`, or `review`.

## Engineering Rules

- Use live Omarchy `Color`, `Style`, `Border`, spacing, typography, and motion tokens.
- Treat the center and four drawers as one tiling system; drawers reserve animated geometry rather than overlaying content.
- Keep touch targets generous, states legible, and destructive affordances honest and confirmed.
- Prefer native Omarchy, Quickshell, Hyprland, PipeWire, MPRIS, and system integrations over duplicate daemons or polling layers.
- Keep helpers small, bounded, quoted, and failure-aware. Avoid background daemons when an on-demand helper suffices.
- OmaDeck executes inside the long-running shell: prevent leaked processes, file descriptors, signal handlers, model references, and stale QML ownership across rescan or crash recovery.
- Be especially careful with Quickshell PipeWire model lifetimes. Do not regenerate repeaters from `PwNode` removal while Quickshell is unbinding nodes; snapshot or stabilize models before presentation.
- Preserve privacy. Diagnostics intended for sharing must exclude clipboard contents, window titles, usernames, tokens, and private data.
- Re-check live APIs and installed versions rather than coding from generic QML or Linux recollection.

## Build and Validation

Use the repository scripts as authority:

```bash
./scripts/build-native
./scripts/omadeck-doctor
```

`scripts/build-native` configures a Release CMake build and produces:

- `native/OmaDeck/Touch/libomadecktouchplugin.so`
- `native/bin/omadeck-tray`

For QML/plugin edits in the linked checkout, rescan without changing plugin installation state:

```bash
omarchy-shell shell rescanPlugins
omarchy-shell shell ping
```

Do not restart the shell merely as a substitute for understanding a defect. Restart only when required for the behavior under test and report the visible interruption first.

Before completion, select checks that exercise the changed layer:

- QML/JavaScript: repository tests if present, plugin rescan, shell ping, bounded user journal, and actual UI/IPC behavior.
- Native C++: `./scripts/build-native`, relevant CTest targets if present, linkage/load behavior, and the real tray/touch path.
- Hyprland integration: inspect monitors/clients/workspaces through JSON IPC and verify the resulting behavior; check `hyprctl configerrors` after config changes.
- PipeWire/MPRIS: inspect live graph/capabilities and exercise node/player appearance, disappearance, and recovery.
- Touch lifecycle: controlled device re-enumeration or suspend/crash recovery only when Erik authorizes the disruptive test.
- Documentation/config: verify commands against the installed Omarchy version. Omarchy 4.0.1 has no `omarchy debug` route; use supported version, shell, Hyprland, systemd, and journal diagnostics instead.

Finish with `git diff --check`, the narrowest relevant tests, and a diff review. “Built successfully” is not sufficient when the acceptance criterion is live behavior.
