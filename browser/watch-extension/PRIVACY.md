# OmaDeck Watch privacy notice

OmaDeck Watch connects YouTube playback in your browser to the OmaDeck app on
your own computer. Installing and enabling the extension permits the local
sharing described here. Disable or remove it in your browser's add-on manager
to stop that sharing.

## What is shared, when, and why

While enabled, the extension reports eligible YouTube watch pages to OmaDeck,
including before you press **Watch here**. These reports contain the video's
11-character identifier, current playback time and playing/paused state. They
let OmaDeck offer Watch here and return playback to the right position. Reports
are refreshed as playback changes; this is not limited to the initial click.

Messages also contain temporary document/request numbers, document-closed
notifications, command success/failure and a Firefox/Chromium routing label.
These coordinate the handoff with the correct browser and page. They are not
account identifiers or analytics. Page visibility is used inside the extension
to select eligible playback; it is not included in the native candidate report.

The extension runs on www.youtube.com and m.youtube.com so navigation from Home
or search to a video works without reloading. It only reports valid watch-page
video IDs. It does not send search terms, other URL parameters, page text,
thumbnails, video/audio bytes, cookies, passwords or browser history records.
The reported video ID nevertheless identifies a page you visited: Firefox
therefore declares **Browsing activity** and **Website activity** at installation.

## Where it goes

The extension sends these messages through Firefox/Chromium native messaging
to `pretty.omadeck.watch`, then through an owner-only local Unix socket to
OmaDeck. It has no analytics endpoint, advertising service or developer-operated
server. The extension and relay do not write a viewing-history database or log
message payloads; current handoff state is held in memory.

When you choose Watch here, OmaDeck opens YouTube's embedded player. That player
contacts YouTube/Google with the selected video and normal playback requests,
including your IP address. YouTube's own privacy practices apply. Its temporary
player profile does not reuse the browser's sign-in cookies.

Firefox also checks the extension's update feed on GitHub and downloads offered
signed updates there. GitHub receives normal web request information, such as
your IP address; video IDs and playback state are not added to update requests.

## Contact

Questions or reports: https://github.com/TheAirick/OmaDeck/issues
Do not include private video URLs or browser data in public reports.
