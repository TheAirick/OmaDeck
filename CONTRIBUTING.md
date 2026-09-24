# Contributing

OmaDeck welcomes focused bug reports, hardware results, documentation fixes,
and small improvements that preserve its design language.

## Before opening an issue

1. Update Omarchy and OmaDeck.
2. Reproduce after `omarchy restart shell`.
3. Check [Troubleshooting](docs/TROUBLESHOOTING.md).
4. Remove clipboard contents, window titles, usernames, and private data from
   screenshots and logs.

Include the OmaDeck commit, Omarchy version, touchscreen model, monitor names,
expected behavior, actual behavior, reproduction steps, and relevant logs.

## Development setup

```bash
git clone https://github.com/TheAirick/OmaDeck.git "$HOME/Projects/Omadeck"
ln -s "$HOME/Projects/Omadeck" "$HOME/.config/omarchy/plugins/pretty.omadeck"
cd "$HOME/Projects/Omadeck"
./scripts/build-native
omarchy-shell shell rescanPlugins
```

Native changes must compile with `scripts/build-native`. Changes to touch
lifecycle behavior should be verified with a controlled device re-enumeration;
tray changes should be checked through the live Omarchy system tray and
`scripts/omadeck-doctor`.

Run `./scripts/check` as an ordinary user for the automated acceptance checks.
It requires Node, Python with `dbus` and PyGObject, D-Bus, jq, Quickshell,
Qt 6 Declarative (including `qmltestrunner`), Qt 6 WebEngine, LayerShellQt, a C++ compiler, CMake, and Git with
the repository history. It uses private homes, a private media bus, offscreen
rendering, and a private native build. The rollback fixture uses the pinned
published snapshot from Git history; shallow checkouts need that history first.
No desktop playback or clipboard is
changed. Missing dependencies or skipped tests fail the command. The CI
workflow documents the corresponding Arch packages. Real touchscreen, lock,
device reconnect, clean-session installation, and upgrade/rollback acceptance
remain separate live gates in `docs/RELEASE_CHECKLIST.md`.

Preserve these project rules:

- Use live Omarchy theme and spacing tokens.
- Treat modules and drawers as a tiling system.
- Keep touch targets generous and affordances honest.
- Prefer native Omarchy, Hyprland, PipeWire, and MPRIS integrations.
- Avoid background daemons when an on-demand helper is sufficient.
- Guard destructive actions and state their consequences.

Keep pull requests scoped, explain testing, and include before/after captures
for UI changes. By contributing, you agree that your work is MIT licensed.
