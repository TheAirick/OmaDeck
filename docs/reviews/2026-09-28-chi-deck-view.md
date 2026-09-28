# Chi deck view prototype — 2026-09-28

Erik asked for Watch to show Chi's real tab video instead of a second YouTube
player. For a Chi source, **Watch here** now asks Chi (`pip-place`) to put its
own PiP presentation in OmaDeck's Watch rectangle on DP-3. OmaDeck keeps its
overlay layer, transparent hole and touch controls; the controls send guarded
Chi media actions and the timeline follows Chi's media reports. No Watch host
process, embed, second player or position hand-off is involved.

Agreed rules: a video is in one place at a time. Return (`pip-release`) goes
back into the tab when you are still on it, otherwise to ordinary PiP so the
current window is not disturbed; a paused video stays paused. Close pauses
first. Chi taking the video back (Escape, sidebar, navigation) ends Watch.
A shelved tab or a Chi refusal falls back to the existing embedded player.
Drawer and focus changes move the Chi window. The saved PiP spot is untouched.

Chi counterpart: `pip-place` / `pip-release` on Chi `main` (`f584c78`; see its
`docs/media.md`), installed in the live session on 2026-09-28.

Verification (private Chi daemon, profile, config and socket; private offscreen
Quickshell harness; local test video with a silent audio track on DP-3):

- Chi `cargo test --workspace --locked` passes, including 5 new placement tests.
- OmaDeck `scripts/check`: 259 passed, 0 skipped, with 3 new deck QML tests.
- Live journey, 14/14: placement at the exact rectangle, timeline follows,
  pause/seek/play, drawer resize, focused mode, Return to tab, playback continues,
  selecting another tab leaves the deck alone, Return then goes to ordinary PiP,
  Chi taking the video back ends Watch, Close pauses and releases.
- Erik's `~/.config/chi/pip.json` was unchanged; his Chi daemon and desktop shell
  were not restarted, rescanned or touched.

Not yet done: a real YouTube run, touch on the
Edge, Erik's acceptance. WebKit pauses muted autoplay videos after presentation
changes (seen with the first fixture only). If OmaDeck vanishes mid-Watch, the
video stays parked on DP-3 until its tab is selected in Chi.
