import QtQuick
import Quickshell
import Quickshell.Hyprland
import "WorkspacePolicy.js" as Policy

Item {
  id: root
  property var shell: null
  property bool active: true
  property string primaryMonitor: "DP-1"
  readonly property var windowRows: snapshotWindows()
  readonly property int focusedWorkspaceId: {
    var focused = Hyprland.focusedWorkspace
    if (focused && focused.id > 0) return focused.id
    // Moving the mouse onto the deck focuses its named workspace. Keep the
    // numbered selection tied to the primary display's live active workspace.
    var monitors = Hyprland.monitors.values
    for (var i = 0; i < monitors.length; i++) {
      var monitor = monitors[i]
      if (monitor.name === primaryMonitor && monitor.activeWorkspace && monitor.activeWorkspace.id > 0)
        return monitor.activeWorkspace.id
    }
    return 0
  }
  readonly property var workspaces: Policy.workspaceRows(snapshotWorkspaces(), windowRows, focusedWorkspaceId)
  readonly property var parkedWindows: windowRows.filter(function(row) { return row.workspaceName === "special:scratchpad" })
  readonly property bool scratchpadVisible: {
    var monitors = Hyprland.monitors.values
    for (var i = 0; i < monitors.length; i++) {
      var ipc = monitors[i].lastIpcObject || ({})
      if (ipc.specialWorkspace && ipc.specialWorkspace.name === "special:scratchpad") return true
    }
    return false
  }
  readonly property var focusedWindow: windowByAddress(Hyprland.activeToplevel ? Hyprland.activeToplevel.address : "")
  readonly property bool canPark: focusedWindow !== null && focusedWindow.workspaceId > 0
  readonly property int returnWorkspaceId: focusedWorkspaceId
  signal navigated()

  // Reconcile native IPC metadata after mapping/remapping and whenever this
  // view opens. Membership events can precede usable class/workspace metadata.
  function requestRefresh() {
    if (active) refreshDelay.restart()
  }
  onActiveChanged: if (active) requestRefresh()
  Component.onCompleted: requestRefresh()
  Timer {
    id: refreshDelay
    interval: 80
    onTriggered: {
      if (!root.active) return
      Hyprland.refreshToplevels()
      Hyprland.refreshWorkspaces()
      Hyprland.refreshMonitors()
    }
  }
  Connections {
    target: Hyprland
    enabled: root.active
    function onRawEvent(event) {
      if (["openwindow", "closewindow", "movewindow", "movewindowv2",
          "createworkspace", "createworkspacev2", "destroyworkspace", "destroyworkspacev2",
          "monitoradded", "monitoraddedv2", "monitorremoved", "activespecial", "activespecialv2"].indexOf(event.name) !== -1)
        root.requestRefresh()
    }
  }

  function snapshotWorkspaces() {
    return Hyprland.workspaces.values.map(function(workspace) {
      return { id: workspace.id, monitor: workspace.monitor ? workspace.monitor.name : "" }
    })
  }

  function snapshotWindows() {
    // Bind to the native models, but pass only scalar copies to delegates.
    var desktopEntries = DesktopEntries.applications.values
    var values = Hyprland.toplevels.values
    var result = []
    for (var i = 0; i < values.length; i++) {
      var window = values[i]
      var ipc = window.lastIpcObject || ({})
      var key = Policy.address(window.address)
      var workspace = window.workspace
      if (!key || !workspace || ipc.mapped === false) continue
      var appId = String(ipc.class || ipc.initialClass || "")
      var entry = appId ? DesktopEntries.heuristicLookup(appId) : null
      var icon = entry ? String(entry.icon || "") : ""
      var library = shell && "appLibrary" in shell ? shell.appLibrary : null
      var iconSource = library && typeof library.iconSource === "function"
        ? library.iconSource(icon) : Quickshell.iconPath(icon || "application-x-executable", true)
      result.push({
        address: key,
        appName: entry ? String(entry.name || appId) : (appId || "Application"),
        title: String(window.title || ""),
        iconSource: String(iconSource || ""),
        workspaceId: workspace.id,
        workspaceName: workspace.name,
        monitor: window.monitor ? window.monitor.name : ""
      })
    }
    result.sort(function(a, b) { return a.appName.localeCompare(b.appName) || a.address.localeCompare(b.address) })
    return result
  }

  function windowByAddress(value) {
    var key = Policy.address(value)
    for (var i = 0; i < windowRows.length; i++)
      if (windowRows[i].address === key) return windowRows[i]
    return null
  }

  function focusWorkspace(id) {
    if (!Number.isSafeInteger(id) || !workspaces.some(function(row) { return row.id === id })) return false
    Hyprland.dispatch('hl.dsp.focus({ workspace = "' + id + '" })')
    navigated()
    return true
  }

  function focusWindow(address) {
    var row = windowByAddress(address)
    if (!row) return false
    Hyprland.dispatch('hl.dsp.focus({ window = "address:' + row.address + '" })')
    navigated()
    return true
  }

  function parkFocusedWindow() {
    if (!canPark) return false
    Hyprland.dispatch('hl.dsp.window.move({ workspace = "special:scratchpad", follow = false, window = "address:' + focusedWindow.address + '" })')
    return true
  }

  function returnWindow(address) {
    var row = windowByAddress(address)
    if (!row || row.workspaceName !== "special:scratchpad" || returnWorkspaceId <= 0) return false
    Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + returnWorkspaceId + '", follow = false, window = "address:' + row.address + '" })')
    return true
  }

  function toggleScratchpad() {
    if (!parkedWindows.length && !scratchpadVisible) return false
    Hyprland.dispatch('hl.dsp.workspace.toggle_special("scratchpad")')
    // Keep the card available for the next tap to hide it, even when regular
    // workspace/window navigation is configured to dismiss the browser.
    return true
  }
}
