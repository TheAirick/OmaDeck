import QtQuick
import Quickshell

Item {
  id: root
  property var shell: null
  property var sourceEntries: DesktopEntries.applications.values
  property int revision: 0
  readonly property var entries: {
    var change = revision
    var values = sourceEntries || [], rows = []
    var library = shell && shell.appLibrary ? shell.appLibrary : null
    // Snapshot metadata only. Include apps omitted from Omarchy's menu filter;
    // Quickshell owns discovery, desktop-file precedence and lifecycle.
    for (var i = 0; i < values.length; i++) {
      var value = values[i], id = String(value.id || "")
      if (!id || id.indexOf("/") !== -1) continue
      var name = String(value.name || id)
      var icon = String(value.icon || "")
      rows.push({ id: "desktop:" + id, kind: "desktop", desktopId: id, name: name,
        description: String(value.genericName || value.comment || ""), iconText: "󰀻",
        iconSource: library ? String(library.iconSource(icon) || "") : icon.charAt(0) === "/" ? "file://" + icon : Quickshell.iconPath(icon, true),
        classes: value.startupClass ? [String(value.startupClass), id] : [id] })
    }
    rows.sort(function(a, b) { return a.name.localeCompare(b.name) })
    return rows
  }
  function refresh() {
    if (shell && shell.appLibrary && typeof shell.appLibrary.refreshIcons === "function") shell.appLibrary.refreshIcons()
    revision++
  }
  Connections {
    target: root.shell && root.shell.appLibrary ? root.shell.appLibrary : null
    ignoreUnknownSignals: true
    function onAppsChanged() { root.revision++ }
    function onIconIndexChanged() { root.revision++ }
  }
}
