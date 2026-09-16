import QtQuick
import qs.Commons
import qs.Ui
import "../theme"

Item {
  id: root
  property string label: ""
  property string value: ""
  property int limit: 4096
  property bool symbols: false
  property bool shift: false
  signal accepted(string value)
  signal cancelled()
  readonly property var keyRows: symbols ? ["1234567890", "!@#$%&*()_", "-+=[]{};:", "'\"/\\.,?~|"] : ["1234567890", "qwertyuiop", "asdfghjkl", "zxcvbnm"]
  function insertText(value) {
    if (editor.selectedText) editor.remove(editor.selectionStart, editor.selectionEnd)
    editor.insert(editor.cursorPosition, value)
    editor.forceActiveFocus()
  }
  onVisibleChanged: if (visible) { editor.text = value; symbols = false; shift = false; editor.forceActiveFocus() }
  Rectangle { anchors.fill: parent; color: DeckColors.surface }
  // Sibling touch handlers must not see typing taps.
  MouseArea { anchors.fill: parent; onPressed: mouse => mouse.accepted = true }
  Column {
    anchors.fill: parent
    spacing: Style.spacing.controlGap
    Item {
      width: parent.width; height: Style.space(48)
      Button { text: "Cancel"; height: parent.height; bordered: false; onClicked: root.cancelled() }
      Text { anchors.centerIn: parent; text: root.label; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.subtitle }
      Button { anchors.right: parent.right; text: "Done"; height: parent.height; bordered: false; onClicked: root.accepted(editor.text) }
    }
    Rectangle {
      width: parent.width; height: Style.space(48)
      color: Style.normalFill
      border.width: 1; border.color: Color.accent
      TextInput {
        id: editor
        objectName: "launcherTextInput"
        anchors.fill: parent; anchors.margins: Style.spacing.controlGap
        text: root.value; maximumLength: root.limit
        color: Color.foreground; selectionColor: Color.accent; selectedTextColor: Color.background
        font.family: Style.font.family; font.pixelSize: Style.font.body
        verticalAlignment: TextInput.AlignVCenter
        clip: true; selectByMouse: true
        Accessible.name: root.label
        onAccepted: root.accepted(text)
        Keys.onEscapePressed: root.cancelled()
      }
    }
    Row {
      width: parent.width
      height: Math.max(Style.space(192), parent.height - y)
      spacing: Style.spacing.controlGap
      Column {
        width: parent.width - sideKeys.width - parent.spacing
        height: parent.height
        spacing: Style.spacing.labelGap
        Repeater {
          model: root.keyRows
          Row {
            required property string modelData
            width: parent.width
            height: (parent.height - parent.spacing * 3) / 4
            spacing: Style.spacing.labelGap
            Repeater {
              model: modelData.split("")
              Button {
                required property string modelData
                objectName: "launcherKey:" + modelData
                width: (parent.width - parent.spacing * 9) / 10
                height: parent.height
                text: root.shift ? modelData.toUpperCase() : modelData
                onClicked: root.insertText(text)
              }
            }
          }
        }
      }
      Column {
        id: sideKeys
        width: Math.min(Style.space(240), parent.width * 0.22); height: parent.height
        spacing: Style.spacing.labelGap
        Button {
          width: parent.width; height: (parent.height - parent.spacing * 3) / 4
          text: "⌫"; Accessible.name: "Backspace"
          onClicked: { if (editor.selectedText) editor.remove(editor.selectionStart, editor.selectionEnd); else if (editor.cursorPosition > 0) editor.remove(editor.cursorPosition - 1, editor.cursorPosition) }
        }
        Row {
          width: parent.width; height: (parent.height - parent.spacing * 3) / 4; spacing: Style.spacing.labelGap
          Button { width: (parent.width - parent.spacing) / 2; height: parent.height; text: root.symbols ? "ABC" : "#+="; onClicked: root.symbols = !root.symbols }
          Button { width: (parent.width - parent.spacing) / 2; height: parent.height; text: "Shift"; selected: root.shift; onClicked: root.shift = !root.shift }
        }
        Button { width: parent.width; height: (parent.height - parent.spacing * 3) / 4; text: "Space"; onClicked: root.insertText(" ") }
        Button { width: parent.width; height: (parent.height - parent.spacing * 3) / 4; text: "Paste"; onClicked: editor.paste() }
      }
    }
  }
}
