import QtQuick
import qs.Commons

Item {
  id: root

  property string label: ""
  property string description: ""
  property string value: ""
  property var options: []
  signal changed(string value)

  implicitHeight: Math.max(Style.space(68), content.implicitHeight)

  Grid {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: 0
    anchors.rightMargin: 0
    spacing: Style.spacing.panelGap
    columns: root.width >= Style.space(600) ? 2 : 1

    Column {
      width: content.columns === 2 ? content.width * 0.4 : content.width
      spacing: Style.spacing.xs

      Text {
        width: parent.width
        text: root.label
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.subtitle
        font.bold: true
        wrapMode: Text.Wrap
      }

      Text {
        visible: root.description !== ""
        width: parent.width
        text: root.description
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
      }
    }

    Flow {
      id: choiceRow
      width: content.columns === 2 ? content.width * 0.6 - content.spacing : content.width
      spacing: Style.spacing.labelGap

      Repeater {
        model: root.options

        Item {
          id: choiceOption
          required property var modelData
          readonly property bool selected: root.value === modelData.value
          width: Math.min(choiceRow.width, Math.max(Style.space(48),
            optionLabel.implicitWidth + Style.spacing.controlPaddingX * 1.5))
          height: Math.max(Style.space(48), optionLabel.implicitHeight + Style.spacing.controlPaddingY * 2)
          Accessible.role: Accessible.Button
          Accessible.name: modelData.label
          Accessible.checked: selected

          Rectangle {
            anchors.fill: parent
            radius: Style.cornerRadius
            color: optionPointer.pressed
              ? Style.pressedFillFor(Color.foreground, Color.accent)
              : "transparent"

            Behavior on color { ColorAnimation { duration: 100 } }
          }

          Text {
            id: optionLabel
            anchors.centerIn: parent
            width: parent.width - Style.spacing.controlPaddingX * 1.5
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            text: choiceOption.modelData.label
            color: choiceOption.selected ? Color.accent : Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: choiceOption.selected
          }

          Rectangle {
            width: parent.width - Style.spacing.controlPaddingX
            height: Style.space(2)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            color: Color.accent
            opacity: choiceOption.selected ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: 120 } }
          }

          MouseArea {
            id: optionPointer
            anchors.fill: parent
            enabled: root.enabled
            preventStealing: false
            cursorShape: Qt.PointingHandCursor
            onClicked: root.changed(choiceOption.modelData.value)
          }
        }
      }
    }
  }
}
