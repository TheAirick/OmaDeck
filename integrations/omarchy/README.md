# Independent touch on capability-scoped Omarchy hosts

The native bridge reads only the configured touchscreen and delivers pointer
events directly to OmaDeck. Game mouse capture, workspace focus, and desktop
pointer position do not participate in this route. Deck input must still stop
synchronously at lock request, throughout lock/recovery, and on provider loss.

Newer Omarchy hosts keep their authentication services private. The optional
`HostInputGuard` integration shares only a boolean through native process-local
state. It does not expose the lock service, its QML context, passwords, PAM
objects, or any unlock operation. No polling, helper process, or daemon is used.

Build with `./scripts/build-native`. In the **enabled user-owned lock clone's**
`Service.qml`, inside its root `Item`, add the following optional loader. Back up
that file first; never edit the packaged lock under `/usr/share/omarchy`. Install
only while unlocked, then restart the shell to load the native library and the
keep-loaded lock service. The restart briefly interrupts shell panels.

```qml
  // BEGIN OmaDeck independent touch guard
  Loader {
    id: omadeckInputGuard
    source: "file://" + Quickshell.env("HOME")
      + "/.config/omarchy/plugins/pretty.omadeck/integrations/omarchy/NativeInputGuard.qml"
    onLoaded: item.blocked = Qt.binding(function() {
      return root.locked || !root.strandedLockResolved || root.strandedLock
    })
  }
  // END OmaDeck independent touch guard
```

The loader must stay optional: a missing/incompatible native module produces a
loader error without preventing the parent lock service from loading. The native
publisher starts blocked before its binding is installed. No publisher,
incomplete construction, or more than one publisher denies native input.
OmaDeck falls back to compositor routing when the provider is absent. Keep the
actual touchscreen enabled and mapped to the deck output in Hyprland so fallback
remains usable; keep its separate mouse-emulation endpoint disabled. While the
native bridge is active, its exclusive grab prevents duplicate delivery.

Verify with `omarchy-shell pretty.omadeck touchState`: `mode: native`,
`hostInputGuardAvailable: true`, `hostInputAllowed: true`, and `active: true`
while unlocked. During lock, the guard must deny interaction and cancel any
contact already in progress. A new contact is required after unlocking.

Acceptance requires physical taps and drags during actual captured gameplay,
normal desktop use, and lock/unlock. Confirm game focus and mouse position remain
unchanged. Automated tests cover all guard phases, provider load/unload,
conflicting providers, and MouseArea/TapHandler cancellation; they do not replace
the hardware check.

To remove the integration, remove only the marked loader block and restart the
shell while unlocked. Compositor touch resumes with its known game-capture
limitation. The lock plugin does not depend on OmaDeck remaining installed.
