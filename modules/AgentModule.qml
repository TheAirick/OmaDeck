import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null

  Column {
    anchors.fill: parent
    spacing: Style.spacing.panelGap

    Text {
      text: "Agents"
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.title
      font.bold: true
    }

    Text {
      width: parent.width
      text: "Usage, active sessions, and summon controls will live here."
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      wrapMode: Text.WordWrap
    }

    Button {
      text: "Open agent"
      foreground: Color.foreground
      onClicked: Quickshell.execDetached(["omarchy", "agent", "--pick"])
    }
  }
}
