# OmaDeck Watch companion

This archive contains the optional companion for OmaDeck v0.10.0. It needs an
installed OmaDeck plugin, its built native Watch player and a registered native
messaging host. A browser extension alone cannot show video on OmaDeck.

Setup: https://github.com/TheAirick/OmaDeck/blob/main/docs/WATCH_MODE.md

Firefox/Zen: unsigned development package; load manifest.json through
about:debugging > This Firefox > Load Temporary Add-on. This lasts until browser
restart. Permanent installation requires Mozilla signing.

Chromium: extract the archive and use Load unpacked in chrome://extensions with
Developer mode enabled. Register the displayed extension ID using the helper.

Only YouTube watch pages are matched. The only extension permission is nativeMessaging.
YouTube videos that disable embedding cannot play in the current Watch player.
