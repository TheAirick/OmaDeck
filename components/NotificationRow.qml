import QtQuick
import qs.Commons
import "../theme"

Item {
  id: root
  property var entry: ({})
  property string iconSource: ""
  property string timeText: ""
  property bool selected: false
  property string entryKey: ""
  property string pressedKey: ""
  signal activated()
  implicitHeight: Style.space(116)
  Accessible.role: Accessible.Button
  Accessible.name: (entry.app || "Notification") + ": " + (entry.summary || "")
  Accessible.selected: selected
  Accessible.onPressAction: if (enabled) activated()

  Rectangle {
    anchors.fill: parent
    color: rowTap.pressed ? Style.pressedFillFor(Color.foreground, Color.accent) : "transparent"
    radius: Style.cornerRadius
  }
  Rectangle {
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(3)
    height: parent.height - Style.spacing.panelGap * 2
    radius: width / 2
    color: Color.accent
    visible: root.selected
  }
  Image {
    id: appIcon
    x: Style.spacing.controlPaddingX
    y: Style.spacing.controlGap
    width: Style.space(26); height: width
    source: root.iconSource
    fillMode: Image.PreserveAspectFit
    visible: status === Image.Ready
  }
  Text {
    anchors.centerIn: appIcon
    visible: !appIcon.visible
    text: root.entry.glyph || "󰂚"
    color: root.entry.urgency === 2 ? Color.urgent : Color.accent
    font.family: Style.font.family
    font.pixelSize: Style.font.iconLarge
  }
  Column {
    x: appIcon.x + appIcon.width + Style.spacing.controlGap
    y: Style.spacing.controlGap
    width: Math.max(0, parent.width - x - Style.spacing.controlPaddingX)
    spacing: Style.spacing.labelGap
    Row {
      width: parent.width
      spacing: Style.spacing.controlGap
      Text {
        width: Math.max(0, parent.width - rowTime.implicitWidth - parent.spacing)
        text: root.entry.app || "Notification"
        textFormat: Text.PlainText
        color: DeckColors.secondaryText
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
      Text {
        id: rowTime
        text: root.timeText
        color: DeckColors.secondaryText
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
    Text {
      width: parent.width
      text: root.entry.summary || "Notification"
      textFormat: Text.PlainText
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
      maximumLineCount: 2
      wrapMode: Text.Wrap
      elide: Text.ElideRight
    }
    Text {
      width: parent.width
      text: root.entry.body || ""
      textFormat: Text.PlainText
      color: DeckColors.secondaryText
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
      maximumLineCount: 1
    }
  }
  Rectangle {
    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
    anchors.leftMargin: Style.spacing.controlPaddingX
    anchors.rightMargin: Style.spacing.controlPaddingX
    height: 1
    color: Color.foreground
    opacity: 0.08
  }
  TapHandler {
    id: rowTap
    enabled: root.enabled
    onPressedChanged: if (pressed) root.pressedKey = root.entryKey
    onTapped: if (root.pressedKey === root.entryKey) root.activated()
  }
}
