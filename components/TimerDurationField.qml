import QtQuick
import qs.Commons

Rectangle {
  id: root

  property int value: 0
  property int maximum: 59
  property string segment: "minutes"
  property string accessibleName: "Minutes"
  property bool selected: false

  signal chosen()
  signal edited(int value)

  width: 52
  height: 48
  color: "transparent"
  border.width: 0

  function padded(value) {
    var normalized = Math.max(0, Math.min(maximum, Math.floor(Number(value) || 0)))
    return normalized < 10 ? "0" + normalized : String(normalized)
  }

  function commit() {
    var parsed = Number(editor.text)
    if (!isFinite(parsed)) parsed = 0
    parsed = Math.max(0, Math.min(maximum, Math.floor(parsed)))
    edited(parsed)
    editor.text = padded(parsed)
  }

  // Button taps do not take focus from a Qt TextInput. Always refresh the
  // visible digits when the presenter changes the selected segment.
  onValueChanged: editor.text = padded(value)

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: root.selected ? 2 : 1
    color: root.selected ? Color.accent : Color.muted
    opacity: root.selected ? 1 : 0.55
  }

  TextInput {
    id: editor
    objectName: root.segment + "TimerField"
    anchors.fill: parent
    text: root.padded(root.value)
    color: Color.foreground
    selectionColor: Color.accent
    selectedTextColor: Color.background
    horizontalAlignment: TextInput.AlignHCenter
    verticalAlignment: TextInput.AlignVCenter
    font.family: Style.font.family
    font.pixelSize: Style.font.title
    font.bold: true
    maximumLength: 2
    validator: IntValidator { bottom: 0; top: root.maximum }
    inputMethodHints: Qt.ImhDigitsOnly
    Accessible.role: Accessible.EditableText
    Accessible.name: root.accessibleName + " timer value"

    onActiveFocusChanged: {
      if (activeFocus) {
        root.chosen()
        selectAll()
      } else root.commit()
    }
    onAccepted: {
      root.commit()
      focus = false
    }
  }

  TapHandler {
    onTapped: {
      root.chosen()
      editor.forceActiveFocus()
      editor.selectAll()
    }
  }
}
