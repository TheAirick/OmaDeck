import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property string primaryMonitor: "DP-1"
  property var favorites: [
    { id: "com.mitchellh.ghostty", name: "Terminal", icon: "com.mitchellh.ghostty" },
    { id: "chromium", name: "Browser", icon: "chromium" },
    { id: "org.gnome.Nautilus", name: "Files", icon: "org.gnome.Nautilus" },
    { id: "discord", name: "Discord", icon: "discord" },
    { id: "obsidian", name: "Obsidian", icon: "obsidian" },
    { id: "omawrite", name: "Omawrite", icon: "omawrite" }
  ]

  function launch(app) {
    // The foundation delegates desktop-entry resolution to Omarchy. The next
    // layer adds Hyprland client matching so running apps focus their existing
    // workspace before falling back to launch.
    if (shell && shell.appLibrary) shell.appLibrary.launch(app.id, app.name)
    else Quickshell.execDetached(["uwsm-app", "--", "gtk-launch", app.id + ".desktop"])
  }

  Column {
    anchors.fill: parent
    spacing: Style.spacing.panelGap

    Text {
      text: "Applications"
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.title
      font.bold: true
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Style.spacing.panelGap

      Repeater {
        model: root.favorites

        BorderSurface {
          id: launcherButton
          required property var modelData

          width: Style.space(128)
          height: Style.space(94)
          color: launcherTap.pressed ? Style.pressedFill : (launcherHover.hovered ? Style.hoverFill : Style.normalFill)
          radius: Style.cornerRadius
          borderSpec: Border.controlSpec(launcherHover.hovered ? "hover" : "normal", Color.foreground, Color.accent, Color.urgent)

          Column {
            anchors.centerIn: parent
            spacing: Style.spacing.labelGap

            Image {
              anchors.horizontalCenter: parent.horizontalCenter
              width: Style.space(38)
              height: width
              source: Quickshell.iconPath(launcherButton.modelData.icon, true)
              fillMode: Image.PreserveAspectFit
              asynchronous: true
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: launcherButton.modelData.name
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }
          }

          HoverHandler { id: launcherHover }
          TapHandler { id: launcherTap; onTapped: root.launch(launcherButton.modelData) }
        }
      }
    }
  }
}
