# OmaDeck Target Host

This repository's primary development target is Erik's local Omarchy Quattro workstation. Treat exact versions below as a dated baseline, not eternal truth; query the live system before version-sensitive implementation or diagnosis.

## Verified Baseline — 2026-08-26

- Omarchy: `4.0.1-1`, stable channel
- Kernel: `7.1.9-arch1-2`
- Hyprland: `0.56.2`
- Quickshell: `0.3.1`
- UWSM: `0.26.7`
- Node: `26.7.0`
- Git: `2.55.0`
- CMake: `4.4.2`
- clang/LLVM: `22.1.8`
- Codex CLI: `0.149.1`

Refresh facts with live commands rather than silently updating this file from memory:

```bash
omarchy version
uname -r
hyprctl version
qs --version
uwsm --version
node --version
git --version
cmake --version
clang --version
```

## Live Integration

- Checkout: `/home/vishdesk/Projects/Omadeck`
- User plugin link: `~/.config/omarchy/plugins/pretty.omadeck` resolves to this checkout.
- Authoritative shell config: `~/.config/omarchy/shell.json`
- Plugin ID: `pretty.omadeck`
- Current target monitor names documented by the project: deck `DP-3`, primary `DP-1`; verify with `hyprctl -j monitors` before relying on them.
- Packaged Omarchy authority: `/usr/share/omarchy/` (read-only)
- User-owned Omarchy code/config: `~/.config/omarchy/`
- User-owned Hyprland config: `~/.config/hypr/`

Useful non-destructive checks:

```bash
omarchy commands --all
omarchy-shell shell ping
hyprctl configerrors
hyprctl -j monitors
hyprctl -j clients
wpctl status
systemctl --user --failed
journalctl --user --since "10 minutes ago"
```

Filter journals narrowly before sharing them. The host carries real clipboard, window, process, device, and user data.

## Runtime Constraints

OmaDeck runs as unsandboxed code inside `omarchy-shell`, the one long-running Quickshell process. A QML lifecycle defect can affect the entire desktop shell. Native outputs depend on the host's current Qt and Quickshell ABI and must be rebuilt after relevant upgrades. The direct touch bridge owns an evdev descriptor and must recover cleanly across USB re-enumeration, suspend, shell restart, and QML-engine replacement without leaking ownership to child processes.

There is an open, unproven host incident involving historical Quickshell SIGSEGVs in PipeWire `PwNode` teardown/model regeneration. Do not attribute it to OmaDeck without reproduction and evidence. Preserve the project's fixed/snapshotted audio presentation model unless a tested replacement proves safe.
