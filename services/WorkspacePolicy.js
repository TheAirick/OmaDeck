.pragma library

function address(value) {
  var text = String(value || "").replace(/^0x/, "")
  return /^[0-9a-fA-F]+$/.test(text) && !/^0+$/.test(text) ? "0x" + text.toLowerCase() : ""
}

function workspaceRows(workspaces, windows, focusedId) {
  var ids = [1, 2, 3, 4, 5]
  var byId = ({})
  for (var i = 0; i < workspaces.length; i++) {
    var workspace = workspaces[i]
    if (!Number.isSafeInteger(workspace.id) || workspace.id <= 0) continue
    byId[workspace.id] = workspace
    if (ids.indexOf(workspace.id) === -1) ids.push(workspace.id)
  }
  // Window/workspace events can arrive separately. Preserve live windows
  // before their workspace's creation event has arrived.
  for (var j = 0; j < windows.length; j++) {
    var id = windows[j].workspaceId
    if (Number.isSafeInteger(id) && id > 0 && ids.indexOf(id) === -1) ids.push(id)
  }
  ids.sort(function(a, b) { return a - b })
  return ids.map(function(id) {
    var entries = windows.filter(function(window) { return window.workspaceId === id })
    var workspace = byId[id]
    return {
      id: id,
      monitor: workspace ? workspace.monitor : (entries.length ? entries[0].monitor : ""),
      focused: id === focusedId,
      occupied: entries.length > 0,
      windows: entries
    }
  })
}
