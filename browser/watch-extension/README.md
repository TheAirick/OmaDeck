# OmaDeck Watch companion

This archive contains the optional companion for OmaDeck v0.10.0. It needs an
installed OmaDeck plugin, its built native Watch player and a registered native
messaging host. A browser extension alone cannot show video on OmaDeck.

Setup: https://github.com/TheAirick/OmaDeck/blob/main/docs/WATCH_MODE.md

Firefox/Zen: the ZIP is an unsigned submission/development package. Permanent
installation requires the separately distributed Mozilla-signed XPI. Install
that file through about:addons > gear menu > Install Add-on From File.
Firefox 140+ (or a compatible Zen build) is required. Until a signed XPI is
available, load manifest.json through about:debugging > This Firefox > Load
Temporary Add-on; this lasts until browser restart.

Chromium: extract the archive and use Load unpacked in chrome://extensions with
Developer mode enabled. Register the displayed extension ID using the helper.

The extension loads on YouTube pages and reports only valid watch pages.
The only API permission is nativeMessaging. Firefox also asks consent to share
browsing and website activity with the local app. See PRIVACY.md for the exact
data flow, including reports made before Watch here is pressed.
YouTube videos that disable embedding cannot play in the current Watch player.
