# Troubleshooting

## OmaDeck does not appear

Confirm the plugin is enabled in `~/.config/omarchy/shell.json` and that
`targetScreen` matches `hyprctl monitors`, then run `omarchy restart shell`.
For a linked checkout, run `omarchy-shell shell rescanPlugins`.

## Touch affects the wrong monitor

The touchscreen is mapped by Hyprland, not QML. Compare `hyprctl devices` with
`hyprctl monitors` and map the touch device to OmaDeck's output.

## Applications open on the deck

Confirm `primaryMonitor` names a connected output. OmaDeck launches through a
workspace-bound Hyprland rule so placement does not depend on cursor position.

## A launcher opens another copy

Inspect the live class with `hyprctl clients`, then add it to the launcher's
`classes` array in `modules/AppLauncherModule.qml`.

## Media metadata or seeking is unavailable

OmaDeck uses MPRIS. Some web players omit artwork, duration, or seek support,
and metadata can briefly reset when tracks change. Missing capabilities are
hidden or disabled rather than emulated.

## Audio sources are missing

Confirm the application is actively producing audio with `wpctl status`.
Stream categories are inferred from metadata and may fall back to Other.

## GPU or temperature values are blank

NVIDIA readings require `nvidia-smi`; CPU temperature requires a sensor exposed
by `sensors` as `Tctl`. Other System features continue working without them.

## Monitor input switching fails

Run the configured script directly and inspect its exit code. Input switching
is monitor-specific and the scripts are not shipped by OmaDeck.

## Diagnostics

```bash
journalctl --user --since "10 minutes ago" | grep -i omadeck
omarchy debug --no-sudo --print
```

Reports should include the OmaDeck commit, Omarchy version, monitor names,
logs, and reproduction steps. Remove private clipboard text and window titles.
