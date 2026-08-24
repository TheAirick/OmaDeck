# OmaDeck

OmaDeck is a touch-native command surface for [Omarchy](https://omarchy.org/)
and Hyprland. It turns a secondary touchscreen into a small tiled desktop for
media, audio, applications, workspaces, monitor inputs, clipboard history, and
live system information.

> [!IMPORTANT]
> OmaDeck is an early, hardware-specific release. It currently targets a
> Corsair Xeneon Edge on `DP-3` and a primary workspace monitor on `DP-1`.
> Monitor selection and launcher editing do not have settings screens yet.

<p align="center">
  <img src="assets/omadeck-demo.gif" alt="OmaDeck retiling drawer demonstration" width="100%">
</p>

[Higher-quality MP4 demo](assets/omadeck-demo-web.mp4)

## What it does

- Retiles the center surface when edge drawers appear instead of covering it.
- Controls MPRIS media with artwork, seeking, and transport controls.
- Mixes PipeWire output, microphone, categories, and individual app streams.
- Focuses an existing Hyprland window before launching another copy.
- Switches workspaces on the primary monitor without moving touch focus there.
- Exposes live CPU, GPU, memory, temperature, network, and storage information.
- Provides a touch task manager with Focus, Close, and confirmed Force Kill.
- Browses native Omarchy clipboard history with text and image previews.
- Summons Omarchy's native network and disk speed tests.
- Follows the active Omarchy theme, typography, borders, gaps, and motion.

## Gallery

### Media and live audio

![Media drawer with now-playing and PipeWire controls](assets/screenshots/media.png)

### System performance

![System performance history charts](assets/screenshots/performance.png)

### Touch launcher

![Bottom application launcher retiling the center layout](assets/screenshots/applications.png)

## Install

Install and enable OmaDeck as a native Omarchy shell service:

```bash
omarchy plugin add https://github.com/TheAirick/OmaDeck.git --enable
```

It starts with `omarchy-shell` at login; no separate autostart service is
required.

Update or remove it with:

```bash
omarchy plugin update pretty.omadeck
omarchy plugin remove pretty.omadeck
```

Read the [setup and interaction guide](docs/USER_GUIDE.md) before installing on
different hardware.

## Current layout

| Edge | Surface |
| --- | --- |
| Left | Media and audio mixer |
| Right | System overview and tools |
| Top | Workspaces |
| Bottom | Application launcher |

The center starts with Clock and Command Center modules. Revealing a drawer
resizes this split tree with the same spatial logic that makes Hyprland feel
coherent.

## Documentation

- [User guide](docs/USER_GUIDE.md)
- [Configuration](docs/CONFIGURATION.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Roadmap](ROADMAP.md)
- [Contributing](CONTRIBUTING.md)

## Development

Clone the repository and link it into the user plugin directory:

```bash
git clone https://github.com/TheAirick/OmaDeck.git "$HOME/Projects/Omadeck"
ln -s "$HOME/Projects/Omadeck" "$HOME/.config/omarchy/plugins/pretty.omadeck"
```

Add `pretty.omadeck` to the top-level `plugins` array in
`~/.config/omarchy/shell.json`, then reload after edits:

```bash
omarchy-shell shell rescanPlugins
```

OmaDeck is licensed under the [MIT License](LICENSE).
