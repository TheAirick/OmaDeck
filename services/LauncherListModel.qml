import QtQuick

// Keep view delegates and their scroll position alive across catalog refreshes.
// Only scalar snapshots enter the model; it never owns native desktop entries.
ListModel {
  id: root
  property var entries: []
  onEntriesChanged: reconcile()
  function reconcile() {
    var values = entries || []
    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      var found = i
      while (found < count && get(found).entryId !== id) found++
      var json = JSON.stringify(values[i])
      if (found === count) insert(i, {entryId: id, entryJson: json})
      else {
        if (found !== i) move(found, i, 1)
        if (get(i).entryJson !== json) setProperty(i, "entryJson", json)
      }
    }
    if (count > values.length) remove(values.length, count - values.length)
  }
}
