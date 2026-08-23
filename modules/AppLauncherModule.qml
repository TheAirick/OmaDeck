import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property string primaryMonitor: "DP-1"
  property string launcherScript: Quickshell.env("HOME") + "/Projects/Omadeck/scripts/focus-or-launch"
  property var favorites: [
    { id: "com.mitchellh.ghostty", name: "Terminal", icon: "com.mitchellh.ghostty", classes: ["com.mitchellh.ghostty"] },
    { id: "chromium", name: "Browser", icon: "chromium", classes: ["chromium", "google-chrome", "zen"] },
    { id: "org.gnome.Nautilus", name: "Files", icon: "org.gnome.Nautilus", classes: ["org.gnome.nautilus", "nautilus"] },
    { id: "discord", name: "Discord", icon: "discord", classes: ["discord", "vesktop"] },
    { id: "obsidian", name: "Obsidian", icon: "obsidian", classes: ["md.obsidian.obsidian", "obsidian"] },
    { id: "omawrite", name: "Omawrite", icon: "omawrite", classes: ["omawrite"] }
  ]

  function normalize(value) {
    return String(value || "").trim().toLowerCase().replace(/\.desktop$/, "")
  }

  function matches(client, app) {
    var candidates = [client.class, client.initialClass].map(normalize)
    var aliases = app.classes || [app.id]
    for (var i = 0; i < candidates.length; i++) {
      for (var j = 0; j < aliases.length; j++) {
        var alias = normalize(aliases[j])
        if (candidates[i] === alias || candidates[i].endsWith("." + alias)) return true
      }
    }
    return false
  }

  function focusOrLaunch(app) {
    Quickshell.execDetached([
      launcherScript,
      app.id,
      primaryMonitor,
      (app.classes || [app.id]).join(",")
    ])
  }

  Column {
    anchors.fill: parent
    spacing: Style.spacing.controlGap

    Text {
      text: "Applications"
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.title
      font.bold: true
    }

    Item {
      width: parent.width
      height: parent.height - y

      Row {
        anchors.centerIn: parent
        spacing: Style.spacing.panelGap

        Repeater {
          model: root.favorites

          BorderSurface {
            id: launcherButton
            required property var modelData

            width: Style.space(128)
            height: Style.space(68)
            color: launcherTap.pressed ? Style.pressedFill : (launcherHover.hovered ? Style.hoverFill : Style.normalFill)
            radius: Style.cornerRadius
            borderSpec: Border.controlSpec(launcherHover.hovered ? "hover" : "normal", Color.foreground, Color.accent, Color.urgent)

            Column {
              anchors.centerIn: parent
              spacing: Style.spacing.labelGap

              Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Style.space(28)
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
            TapHandler { id: launcherTap; onTapped: root.focusOrLaunch(launcherButton.modelData) }
          }
        }
      }
    }
  }
}
