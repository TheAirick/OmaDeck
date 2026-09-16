import QtQuick
import Quickshell
import qs.Commons
import "../theme"
import qs.Ui
import "../services"

Item {
  id: root

  property var shell: null
  property var deck: null
  property var controller: null
  property string pluginDir: ""
  property string primaryMonitor: "DP-1"
  property bool editing: false
  property bool catalogOpen: false
  property string selectedId: ""
  property int appLibraryRevision: 0
  readonly property string launcherScript: root.pluginDir + "/scripts/focus-or-launch"
  readonly property int controllerRevision: controller ? controller.revision : 0
  readonly property var entries: {
    var revision = root.controllerRevision
    var appsRevision = root.appLibraryRevision
    var catalogEntries = appCatalog.entries
    if (!controller) return []
    return catalogOpen ? root.availableEntries() : root.pinnedEntries()
  }
  readonly property int selectedIndex: {
    for (var index = 0; index < entries.length; index++)
      if (entries[index].id === selectedId) return index
    return -1
  }

  signal backRequested()

  LauncherCatalog { id: appCatalog; shell: root.shell }
  LauncherListModel { id: launcherModel; entries: root.entries }
  function installedEntries() { return appCatalog.entries }

  function pinnedEntries() {
    var stored = controller ? controller.entries() : []
    var installed = installedEntries()
    var byId = ({})
    for (var index = 0; index < installed.length; index++) byId[installed[index].id] = installed[index]
    return stored.map(function(entry) { return entry.kind === "desktop" && byId[entry.id] ? byId[entry.id] : entry })
  }

  function availableEntries() {
    var result = controller ? controller.availableEntries() : []
    var selected = controller && Array.isArray(controller.entryIds) ? controller.entryIds : []
    var installed = installedEntries()
    for (var index = 0; index < installed.length; index++)
      if (selected.indexOf(installed[index].id) === -1) result.push(installed[index])
    return result
  }

  function focusOrLaunch(app) {
    Quickshell.execDetached([
      launcherScript,
      app.desktopId,
      primaryMonitor,
      (app.classes || [app.desktopId]).join(",")
    ])
  }

  function invoke(entry) {
    if (!entry) return
    if (entry.kind === "command") { if (controller) controller.runCommand(entry.id); return }
    if (entry.kind === "application" || entry.kind === "desktop") {
      focusOrLaunch(entry)
      return
    }
    if (!deck) return
    if (entry.action === "notifications") deck.openOverlay("notifications")
    else if (entry.action === "overview") deck.openOverlay("overview")
    else if (entry.action === "clipboard") deck.showSystemSection("clipboard")
    else if (entry.action === "performance") deck.showSystemSection("performance")
    else if (entry.action === "lock") Quickshell.execDetached([
      "/usr/bin/env", "PATH=/usr/bin:/usr/share/omarchy/bin",
      "/usr/bin/timeout", "--signal=TERM", "--kill-after=1s", "10s",
      "/usr/bin/omarchy-system-lock"
    ])
  }

  function activate(entry) {
    if (!entry) return
    if (catalogOpen) {
      controller.add(entry.id)
      return
    }
    if (editing) {
      selectedId = entry.id
      return
    }
    invoke(entry)
  }

  function beginEditing(id) {
    catalogOpen = false
    editing = true
    selectedId = String(id || "")
  }

  function finishEditing() {
    editing = false
    selectedId = ""
  }

  function removeSelected() {
    if (!controller || !selectedId) return
    controller.remove(selectedId)
    selectedId = ""
  }

  function moveSelected(delta) {
    if (!controller || !selectedId) return
    controller.move(selectedId, delta)
  }

  Row {
    id: pageHeader
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: Style.space(48)
    spacing: Style.spacing.controlGap

    Button {
      objectName: "launcherBackControl"
      width: Style.space(74)
      height: parent.height
      text: root.catalogOpen ? "Apps" : "Home"
      iconText: "󰅁"
      bordered: false
      tooltipText: root.catalogOpen ? "Return to applications" : "Return to Command Center"
      onClicked: {
        if (root.catalogOpen) root.catalogOpen = false
        else root.backRequested()
      }
    }

    Text {
      width: parent.width - x - pageActions.width - Style.spacing.controlGap
      anchors.verticalCenter: parent.verticalCenter
      text: root.catalogOpen ? "Add applications & shortcuts"
        : root.editing ? "Select an item to arrange" : "Applications"
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.subtitle
      font.bold: true
      elide: Text.ElideRight
    }

    Row {
      id: pageActions
      height: parent.height
      spacing: Style.spacing.controlGap

      Button {
        objectName: "launcherAddControl"
        visible: !root.catalogOpen && !root.editing
        width: Style.space(84)
        height: parent.height
        text: "Add"
        iconText: "󰐕"
        bordered: false
        tooltipText: "Add an application or shortcut"
        onClicked: {
          if (root.deck && typeof root.deck.editLauncher === "function") root.deck.editLauncher(true)
          else { root.catalogOpen = true; root.selectedId = ""; appCatalog.refresh() }
        }
      }

      Button {
        objectName: "launcherEditControl"
        visible: !root.catalogOpen
        width: Style.space(92)
        height: parent.height
        text: root.editing ? "Done" : "Edit"
        iconText: root.editing ? "󰄬" : "󰏫"
        selected: root.editing
        bordered: false
        tooltipText: root.editing ? "Finish arranging" : "Arrange applications"
        onClicked: { if (root.deck && typeof root.deck.editLauncher === "function") root.deck.editLauncher(false); else if (root.editing) root.finishEditing(); else root.beginEditing("") }
      }
    }
  }

  GridView {
    id: launcherGrid
    objectName: "launcherGrid"
    anchors.top: pageHeader.bottom
    anchors.topMargin: Style.spacing.panelGap
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: editToolbar.visible ? editToolbar.top : actionNotice.top
    anchors.bottomMargin: editToolbar.visible ? Style.spacing.controlGap : 0
    cellWidth: Math.max(Style.space(116), width / Math.max(1, Math.floor(width / Style.space(138))))
    cellHeight: Style.space(82)
    clip: true
    model: launcherModel
    boundsBehavior: Flickable.StopAtBounds; boundsMovement: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    maximumFlickVelocity: Math.max(Style.space(320), height * 2.5)
    flickDeceleration: Style.space(3000)

    delegate: Item {
      id: launcherCell
      required property string entryJson
      readonly property var modelData: JSON.parse(entryJson)
      width: launcherGrid.cellWidth
      height: launcherGrid.cellHeight

      Rectangle {
        id: launcherButton
        objectName: "launcherEntry-" + launcherCell.modelData.id
        anchors.fill: parent
        anchors.margins: Style.spacing.controlGap / 2
        color: launcherTap.pressed ? Style.pressedFill : "transparent"
        radius: Style.cornerRadius
        border.width: root.selectedId === launcherCell.modelData.id ? 2 : 0
        border.color: Color.accent

        Column {
          anchors.centerIn: parent
          width: parent.width - Style.spacing.panelGap * 2
          spacing: Style.spacing.labelGap

          Text {
            visible: !launcherIcon.visible
            anchors.horizontalCenter: parent.horizontalCenter
            text: launcherCell.modelData.iconText
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.displayLarge
          }

          Image {
            id: launcherIcon
            visible: String(launcherCell.modelData.iconSource || "") !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            width: Style.space(32)
            height: Style.space(32)
            source: String(launcherCell.modelData.iconSource || "")
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
          }

          Text {
            width: parent.width
            text: launcherCell.modelData.name
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
          }
        }

        TapHandler {
          id: launcherTap
          onTapped: root.activate(launcherCell.modelData)
        }
      }
    }

    Text {
      anchors.centerIn: parent
      visible: root.entries.length === 0
      text: root.catalogOpen ? "Everything is already pinned" : "Tap Add to pin an application or shortcut"
      color: DeckColors.secondaryText
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
  }

  Text {
    id: actionNotice
    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
    height: text ? implicitHeight + Style.spacing.controlGap : 0
    text: root.controller ? String(root.controller.actionNotice || "") : ""
    color: DeckColors.secondaryText; font.family: Style.font.family; font.pixelSize: Style.font.caption
    wrapMode: Text.Wrap; textFormat: Text.PlainText
  }

  Row {
    id: editToolbar
    objectName: "launcherEditToolbar"
    visible: root.editing
    enabled: root.selectedIndex >= 0
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: Style.space(52)
    spacing: Style.spacing.controlGap

    Button {
      width: (parent.width - parent.spacing * 2) / 3
      height: parent.height
      text: "Move left"
      iconText: "󰁍"
      bordered: false
      enabled: root.selectedIndex > 0
      onClicked: root.moveSelected(-1)
    }
    Button {
      width: (parent.width - parent.spacing * 2) / 3
      height: parent.height
      text: "Remove"
      iconText: "󰅖"
      bordered: false
      foreground: Color.urgent
      enabled: root.selectedIndex >= 0
      onClicked: root.removeSelected()
    }
    Button {
      width: (parent.width - parent.spacing * 2) / 3
      height: parent.height
      text: "Move right"
      iconText: "󰁔"
      bordered: false
      enabled: root.selectedIndex >= 0 && root.selectedIndex < root.entries.length - 1
      onClicked: root.moveSelected(1)
    }
  }

  Connections {
    target: root.shell && "appLibrary" in root.shell ? root.shell.appLibrary : null
    function onAppsChanged() { root.appLibraryRevision++ }
  }
}
