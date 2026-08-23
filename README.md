# OmaDeck

OmaDeck is a touch-native Omarchy command surface for secondary displays. It
translates Hyprland's spatial model—workspaces, tiled windows, split resizing,
special workspaces, and focus-aware launching—into a persistent touch deck.

The first target is the Corsair Xeneon Edge on `DP-3`, paired with a primary
workspace monitor on `DP-1`.

## Design rules

- Omarchy owns color, typography, spacing, borders, and motion.
- Modules behave like tiled windows, not arbitrary dashboard widgets.
- Edge drawers behave like spatial workspaces and push the center canvas.
- Application actions focus an existing window before launching another.
- Every module can eventually be pinned, contextual, drawer-only, or hidden.
- Touch is primary; mouse and keyboard remain valid development fallbacks.

## Development install

OmaDeck is loaded as a third-party `service` plugin by `omarchy-shell`.
During development, link this repository into the user plugin directory:

```bash
ln -s "$HOME/Projects/Omadeck" "$HOME/.config/omarchy/plugins/pretty.omadeck"
```

Then add `pretty.omadeck` to the top-level `plugins` array in
`~/.config/omarchy/shell.json`. Omarchy discovers the linked directory; during
local development, run `omarchy-shell shell rescanPlugins` after edits because
recursive filesystem watching does not follow every symlink target reliably.

## Status

Foundation prototype. The current surface proves:

- DP-3 targeting
- live Omarchy theme tokens
- Hyprland-style gaps and borders
- a split center layout
- four push-reveal edge drawers
- workspace switching on the primary monitor
- Omarchy desktop-entry launching
- native media service access

The next milestone is the persistent split-tree layout model and focus-or-launch
application behavior.
