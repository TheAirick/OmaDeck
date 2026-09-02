import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  property string label: ""
  property string status: ""
  property string iconText: ""
  property bool checked: false
  property bool available: true
  signal toggled()

  radius: Style.cornerRadius
  opacity: available ? 1 : 0.46
  color: quickTap.pressed
    ? Style.pressedFillFor(Color.foreground, Color.accent)
    : checked
    ? Style.selectedFillFor(Color.foreground, Color.accent)
    : quickHover.hovered
    ? Style.hoverFillFor(Color.foreground, Color.accent)
    : Style.normalFill
  borderSpec: checked
    ? Border.hyprlandActiveSpec(Color.accent, 2)
    : quickHover.hovered
    ? Border.controlSpec("hover-cursor", Color.foreground, Color.accent, Color.urgent)
    : Border.controlSpec("normal", Color.foreground, Color.accent, Color.urgent)

  Column {
    anchors.centerIn: parent
    width: parent.width - Style.spacing.panelGap * 2
    spacing: Style.spacing.labelGap

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.iconText
      color: root.checked ? Color.accent : Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.displayLarge
    }

    Text {
      width: parent.width
      text: root.label
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      text: root.available ? root.status : "Unavailable"
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
    }
  }

  HoverHandler { id: quickHover }
  TapHandler {
    id: quickTap
    enabled: root.available
    onTapped: root.toggled()
  }
}
