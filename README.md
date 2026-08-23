# OmaDeck

OmaDeck is a touch-native Omarchy command surface for secondary displays. It
translates Hyprland's spatial model—workspaces, tiled windows, split resizing,
special workspaces, and focus-aware launching—into a persistent touch deck.

The first target is the Corsair Xeneon Edge on `DP-3`, paired with a primary
workspace monitor on `DP-1`.

## Design rules

- Omarchy owns color, typography, spacing, borders, and motion.
- Modules behave like tiled windows, not arbitrary dashboard widgets.
- Edge modules join the tiling region and resize the center canvas.
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
- four retiling edge reveals: Media and Agents on the customizable sides,
  Workspaces on top, and Applications on the bottom
- workspace switching on the primary monitor
- Omarchy desktop-entry launching
- native media service access

## Layout state

OmaDeck stores the active split tree at:

```text
~/.config/omadeck/layout.json
```

The tree uses the same basic model as a tiling compositor: split nodes contain
an orientation, ratio, and two children; leaf nodes contain modules. Changes
are written atomically and survive shell restarts.

Long-press a module to enter edit mode. In edit mode, drag modules onto one
another (or tap a source and destination) to swap them, and drag the highlighted
dividers to resize neighboring modules.

Application buttons inspect Hyprland's live client list before launching. A
matching running window is focused by address, which moves the primary monitor
to its workspace; a new application is launched only when no match exists.
