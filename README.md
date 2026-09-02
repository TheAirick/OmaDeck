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

- Keeps Now Playing, Clock/Weather, and Command Center mounted as the permanent
  dashboard while horizontal drawers reserve animated edge geometry.
- Layers Notifications and Overview above the dashboard without collapsing or
  dismissing an open Volume or System drawer.
- Responsively simplifies dense modules while space is constrained, restoring
  their selected detail as panels expand.
- Controls MPRIS media with artwork, seeking, and transport controls.
- Mixes PipeWire output, microphone, categories, and individual app streams.
- Focuses an existing Hyprland window before launching another copy.
- Switches workspaces on the primary monitor without moving touch focus there.
- Exposes live CPU, GPU, memory, temperature, network, and storage information.
- Provides a touch task manager with Focus, Close, and confirmed Force Kill.
- Browses native Omarchy clipboard history with text and image previews.
- Summons Omarchy's native network and disk speed tests.
- Publishes a mouse-accessible system-tray control center and health report.
- Reconnects its isolated touchscreen automatically after USB, suspend, or
  Quickshell recovery cycles without leaking ownership into child processes.
- Adds current weather, aligned stats, and a multi-day forecast to the clock,
  using Omarchy's location, condition glyphs, and providers.
- Saves touch-configurable clock, weather, detail, visibility, and unit choices.
- Follows the active Omarchy theme, typography, borders, gaps, and motion.

## Gallery

### Media and live audio

![Media drawer with now-playing and PipeWire controls](assets/screenshots/media.png)

### System performance

![System performance history charts](assets/screenshots/performance.png)

### Touch launcher

![Bottom application launcher retiling the center layout](assets/screenshots/applications.png)

## Install

OmaDeck includes a small native touch bridge and system-tray controller. Add the
plugin without enabling it, build those components, then enable the service:

```bash
omarchy plugin add https://github.com/TheAirick/OmaDeck.git --yes
~/.config/omarchy/plugins/pretty.omadeck/scripts/build-native
omarchy plugin enable pretty.omadeck
```

It starts with `omarchy-shell` at login; no separate autostart service is
required. Building requires CMake, a C++ compiler, Python 3, and the Qt 6
development packages used by Omarchy and Quickshell. Native outputs are built
and tested in a fresh private directory, verified, and atomically installed
into the plugin checkout; generated binaries and their integrity record remain
local to that checkout.

After an update, rebuild before restarting the shell:

```bash
omarchy plugin disable pretty.omadeck
omarchy plugin update pretty.omadeck
~/.config/omarchy/plugins/pretty.omadeck/scripts/build-native
omarchy plugin enable pretty.omadeck
```

Remove it with:

```bash
omarchy plugin remove pretty.omadeck
```

Read the [setup and interaction guide](docs/USER_GUIDE.md) before installing on
different hardware.

## Current layout

| Position | Surface |
| --- | --- |
| Static left | Now Playing |
| Center | Clock/Weather and Command Center |
| Left swipe | Volume mixer |
| Right swipe | System overview and tools |
| Pull down | Notifications and quick controls overlay |
| Pull up | Workspaces and scratchpad Overview overlay |

Tap the dashboard Clock to set or control one countdown; its normal date line becomes the
remaining-time status while the wall clock stays primary. Clock and weather
appearance remains available from the OmaDeck taskbar icon. The Applications
button opens an editable launcher inside Command Center. Horizontal drawers
resize the dashboard through one shared animated boundary; vertical gestures
leave its geometry and drawer state untouched.

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
`~/.config/omarchy/shell.json`, build the native components, then reload after
edits:

```bash
./scripts/build-native
omarchy-shell shell rescanPlugins
```

OmaDeck is licensed under the [MIT License](LICENSE).
