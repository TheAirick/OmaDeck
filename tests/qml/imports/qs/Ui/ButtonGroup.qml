import QtQuick
import qs.Commons

Row {
  id: root

  property var options: []
  property string value: ""
  property color background: Color.background
  signal changed(string value)

  spacing: Style.spacing.md

  Repeater {
    model: root.options

    Button {
      required property var modelData
      text: modelData && typeof modelData === "object" ? String(modelData.label) : String(modelData)
      selected: (modelData && typeof modelData === "object" ? String(modelData.value) : String(modelData)) === root.value
      onClicked: root.changed(modelData && typeof modelData === "object"
        ? String(modelData.value) : String(modelData))
    }
  }
}
