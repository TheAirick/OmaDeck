# YouTube Watch mode (optional preview)

Watch here moves a supported YouTube video from Firefox, Zen or Chromium into
OmaDeck near its current timestamp. Touch controls provide play/pause, seek,
captions, focused/fullscreen viewing and Return. The video stays on the left,
with Clock/Weather and Command Center beside it. Volume/System shrink it while
open; notifications and other overlays leave playback running underneath.
The themed border disappears in focused mode.

## Setup

Install OmaDeck normally first. The standard dashboard needs no native build.
Watch mode additionally needs CMake, a C++ compiler, Qt 6 WebEngine development
files and LayerShellQt (Arch packages `base-devel cmake qt6-webengine layer-shell-qt`).
Install those dependencies through your package manager, then run:

```bash
~/.config/omarchy/plugins/pretty.omadeck/scripts/build-watch-host
~/.config/omarchy/plugins/pretty.omadeck/scripts/package-watch-extension
~/.config/omarchy/plugins/pretty.omadeck/scripts/install-watch-native-messaging
```

The unpacked add-ons are written under
`${XDG_CACHE_HOME:-~/.cache}/omadeck/watch-extension/`. Hidden directories such as
`.cache` can be shown in most file pickers with **Ctrl+H**.

### Firefox and Zen

Permanent distribution is being prepared through Mozilla's **unlisted signing**
process. Until its signed XPI is available, the ZIP remains a temporary developer
install. Maintainers: see [signing and release steps](FIREFOX_SIGNING.md).
Firefox 140+ or a compatible Zen build is required for the built-in data consent
prompt.

Open `about:debugging#/runtime/this-firefox`, choose **Load Temporary Add-on**,
and select `firefox/manifest.json` in that folder. The helper registers both
Firefox and Zen native-host locations. Refresh an existing YouTube page afterward.

This is currently a development add-on: it must be loaded again after restarting
the browser. The packaged ZIP is unsigned; a permanent Firefox/Zen installation
requires Mozilla signing, which is not included in the OmaDeck plugin package.
When the signed XPI is released, use `about:addons` → gear menu → **Install
Add-on From File** and select it. Accept the permissions/consent prompt, then
refresh YouTube. The native-host registration remains necessary. Signed installs
will use the configured update feed; it currently advertises no versions.

### Chromium

Open `chrome://extensions`, enable **Developer mode**, choose **Load unpacked**,
and select the `chromium` folder. Copy the extension ID shown there, then run:

```bash
~/.config/omarchy/plugins/pretty.omadeck/scripts/install-watch-native-messaging --chromium-id YOUR_EXTENSION_ID
```

Reload the extension and refresh YouTube. The installer registers Chromium's
user-level native messaging location; other Chromium-derived browsers may use
a different location and have not all been tested.

Once built, return any active Watch session to the browser and run
`omarchy restart shell` to load the new player availability. This briefly reloads
the bar and deck. Watch here appears beneath the YouTube thumbnail.

## Everyday use

- Play a YouTube video, then tap **Watch here**. Its tab may be in the background.
- Tap the video to reveal controls; they hide while playing.
- **Return** seeks the original tab to the latest Edge position and resumes it.
- **× Close** exits without resuming or changing any browser video.
- Closing or navigating the original tab changes Return to **Close**. Another
  video playing in the browser is not the old session's return destination.
- Update the plugin and rebuild the optional host after Qt/platform updates.
  Repackage/reload the add-on and refresh YouTube after extension code updates.

## Limits and privacy

This uses YouTube's embedded player. Videos that disable embedding (errors
101/150), require unavailable authentication, or otherwise reject this player
must remain in the browser. A load failure leaves browser playback untouched.
The native player's profile is temporary and does not reuse browser sign-in
cookies. Handoff starts a new player and can take a few seconds.

The extension loads on YouTube pages to follow Home/search-to-video navigation
without a refresh, and reports only watch pages. It needs `nativeMessaging`.
While enabled, it reports video IDs, playback positions/state and temporary
document identifiers to the local app, including before Watch here is pressed.
The reported video ID identifies a page you visited; Firefox asks consent for
browsing and website activity. It does not read the browser history database or
send cookies. The embedded player makes normal requests to YouTube, and Firefox
checks GitHub for extension updates. See the full
[privacy notice](../browser/watch-extension/PRIVACY.md).

See [verification evidence](WATCH_MODE_TEST_REPORT.md) for tested paths and
remaining physical-device/release acceptance limits.
