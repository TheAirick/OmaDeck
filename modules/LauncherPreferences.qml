import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import qs.Commons
import qs.Ui
import "../components"
import "../services"
import "../services/LauncherPolicy.js" as Policy
import "../theme"

Item {
  id: root
  property var controller: null
  property var shell: null
  property Item inputHost: root
  property bool active: false
  property string page: "pinned"
  property string query: ""
  property string selectedId: ""
  property string editingId: ""
  property var draft: ({ name: "", command: "", directory: "", terminal: false, iconId: "terminal" })
  property string notice: ""
  property string inputField: ""
  property bool removeArmed: false
  readonly property bool typing: active && inputField !== ""
  readonly property int revision: controller ? controller.revision : 0
  readonly property var rows: {
    var change = revision
    if (!controller) return []
    var values = page === "apps" ? catalog.entries.concat(controller.availableEntries().filter(function(entry) { return entry.kind === "shortcut" })) : controller.entries()
    var indexed = ({})
    for (var i = 0; i < catalog.entries.length; i++) indexed[catalog.entries[i].id] = catalog.entries[i]
    var filter = query.trim().toLowerCase()
    return values.map(function(entry) { return indexed[entry.id] || entry }).filter(function(entry) {
      return !filter || (entry.name + " " + (entry.description || "") + " " + entry.id).toLowerCase().indexOf(filter) !== -1
    })
  }
  readonly property var selected: {
    for (var i = 0; i < rows.length; i++) if (rows[i].id === selectedId) return rows[i]
    return null
  }
  readonly property bool ready: !!controller && controller.loaded !== false
  LauncherCatalog { id: catalog; shell: root.shell }
  LauncherListModel { id: appModel; entries: root.rows }
  function browseApps() { page = "apps"; query = ""; notice = ""; removeArmed = false; catalog.refresh() }
  function beginCommand(entry) {
    editingId = entry ? entry.id : ""
    draft = entry ? Object.assign({}, entry) : {name: "", command: "", directory: "", terminal: false, iconId: "terminal"}
    page = "custom"; notice = ""; removeArmed = false
  }
  function setDraft(key, value) { var next = Object.assign({}, draft); next[key] = value; draft = next }
  function editField(key) { inputField = key }
  function finishText(value) {
    if (inputField === "query") query = value
    else setDraft(inputField, value)
    inputField = ""
  }
  function saveCommand() {
    if (!ready) return
    var error = controller.saveCommand(draft, editingId)
    if (error) { notice = error; return }
    selectedId = editingId || controller.entryIds[controller.entryIds.length - 1]
    page = "pinned"; query = ""; notice = ""; editingId = ""
  }
  function choose(entry) { selectedId = entry.id; removeArmed = false; notice = "" }
  function pinSelected() {
    if (!ready || !selected) return
    if (controller.entryIds.length >= Policy.MAX_ENTRIES) { notice = "Remove a button before adding another."; return }
    controller.add(selected.id)
    notice = "Added to Applications"
  }
  function removeSelected() {
    if (!ready || !selected) return
    controller.remove(selected.id); selectedId = ""; removeArmed = false
  }
  onActiveChanged: if (!active) { inputField = ""; removeArmed = false }
  function resetScroll() { appList.cancelFlick(); appList.positionViewAtBeginning(); commandForm.cancelFlick(); commandForm.contentY = 0 }
  onPageChanged: { query = ""; removeArmed = false; notice = ""; Qt.callLater(resetScroll) }
  onQueryChanged: Qt.callLater(resetScroll)

  LauncherTextEntry {
    parent: root.inputHost
    anchors.fill: parent
    z: 50
    visible: root.typing
    label: ({name: "Button name", command: "Command or script", directory: "Working folder", query: "Search applications"})[root.inputField] || ""
    value: root.inputField === "query" ? root.query : String(root.draft[root.inputField] || "")
    limit: root.inputField === "name" ? 64 : root.inputField === "directory" ? 1024 : 4096
    onAccepted: value => root.finishText(value)
    onCancelled: root.inputField = ""
  }
  Column {
    anchors.fill: parent
    spacing: Style.spacing.controlGap
    enabled: root.active && !root.typing
    Row {
      id: navigation
      width: parent.width; height: Style.space(48)
      spacing: Style.spacing.controlGap
      Button { text: "Buttons"; height: parent.height; bordered: false; selected: root.page === "pinned"; onClicked: { root.page = "pinned"; root.query = "" } }
      Button { objectName: "launcherBrowseApps"; text: "Add app"; height: parent.height; bordered: false; selected: root.page === "apps"; onClicked: root.browseApps() }
      Button { objectName: "launcherNewCommand"; text: "New command"; height: parent.height; bordered: false; selected: root.page === "custom"; onClicked: root.beginCommand(null) }
      Button { objectName: "launcherSearch"; visible: root.page !== "custom"; text: root.query ? "Search: " + root.query : "Search"; width: Math.min(Style.space(260), Math.max(Style.space(90), navigation.width - x)); height: parent.height; bordered: false; onClicked: root.editField("query") }
    }
    Text {
      width: parent.width
      visible: text !== ""
      text: root.notice || (root.controller && root.controller.saveError ? "Changes aren’t saved. Tap Retry." : root.controller && root.controller.savePending ? "Saving…" : "")
      textFormat: Text.PlainText
      color: root.controller && root.controller.saveError ? Color.urgent : DeckColors.secondaryText
      font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap
    }
    Button {
      visible: !!(root.controller && root.controller.saveError)
      height: Style.space(48); text: "Retry"; bordered: false
      onClicked: root.controller.persist()
    }
    Item {
      width: parent.width; height: Math.max(0, parent.height - y)
      visible: root.page !== "custom"
      GridView {
        id: appList
        objectName: "launcherCatalogList"
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        anchors.bottom: selectionBar.top; anchors.bottomMargin: Style.spacing.controlGap
        cellWidth: width / Math.max(1, Math.floor(width / Style.space(280)))
        cellHeight: Style.space(72)
        clip: true; model: appModel
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds; boundsMovement: Flickable.StopAtBounds
        maximumFlickVelocity: Math.max(Style.space(320), height * 2.5)
        flickDeceleration: Style.space(3000)
        Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
        delegate: Item {
          required property string entryJson
          readonly property var modelData: JSON.parse(entryJson)
          objectName: "launcherChoice-" + modelData.id
          width: appList.cellWidth; height: appList.cellHeight
          Rectangle { anchors.fill: parent; anchors.rightMargin: Style.spacing.controlGap; color: appTap.pressed ? Style.pressedFill : "transparent" }
          Rectangle { width: 2; height: parent.height - Style.spacing.controlGap * 2; y: Style.spacing.controlGap; color: Color.accent; visible: root.selectedId === modelData.id }
          Image {
            id: appIcon
            x: Style.spacing.controlPaddingX; anchors.verticalCenter: parent.verticalCenter
            width: Style.space(32); height: width; source: String(modelData.iconSource || ""); fillMode: Image.PreserveAspectFit
          }
          Text {
            anchors.centerIn: appIcon; visible: appIcon.status !== Image.Ready
            text: modelData.iconText || "󰀻"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge
          }
          Column {
            x: appIcon.x + appIcon.width + Style.spacing.controlGap; width: parent.width - x - Style.spacing.controlPaddingX * 2
            anchors.verticalCenter: parent.verticalCenter; spacing: Style.spacing.labelGap
            Text { width: parent.width; text: modelData.name; textFormat: Text.PlainText; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; elide: Text.ElideRight }
            Text {
              width: parent.width
              text: modelData.kind === "command" ? (modelData.terminal ? "Command · terminal" : "Command") : modelData.description || (modelData.kind === "shortcut" ? "OmaDeck action" : modelData.desktopId)
              textFormat: Text.PlainText; color: DeckColors.secondaryText; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight
            }
          }
          TapHandler { id: appTap; onTapped: root.choose(modelData) }
        }
        Text {
          anchors.centerIn: parent; width: parent.width; horizontalAlignment: Text.AlignHCenter
          visible: root.rows.length === 0
          text: root.query ? "No matching apps or buttons" : "Add an app or create a command button"
          color: DeckColors.secondaryText; font.family: Style.font.family; font.pixelSize: Style.font.body; wrapMode: Text.Wrap
        }
      }
      Item {
        id: selectionBar
        objectName: "launcherSelectionBar"
        readonly property bool stacked: width < Style.space(700)
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: Style.space(stacked ? 80 : 56)
        Rectangle { width: parent.width; height: 1; color: Color.foreground; opacity: 0.12 }
        Text {
          objectName: "launcherSelectionLabel"
          x: Style.spacing.controlPaddingX; y: selectionBar.stacked ? Style.spacing.labelGap : (parent.height - height) / 2
          width: Math.max(0, parent.width - x - (selectionBar.stacked ? 0 : selectionActions.width + Style.spacing.controlGap))
          text: root.selected ? root.selected.name : root.page === "apps" ? "Select an app to add" : "Select a button to arrange or remove"
          textFormat: Text.PlainText; color: root.selected ? Color.foreground : DeckColors.secondaryText
          font.family: Style.font.family; font.pixelSize: Style.font.body; elide: Text.ElideRight
        }
        Row {
          id: selectionActions
          objectName: "launcherSelectionActions"
          anchors.right: parent.right; anchors.bottom: parent.bottom
          height: Style.space(48); spacing: Style.spacing.controlGap
          Button {
            objectName: "launcherPinSelected"
            visible: root.page === "apps" && !!root.selected
            enabled: root.ready && root.controller.entryIds.indexOf(root.selectedId) === -1
            text: enabled ? "Add to Applications" : "Already added"; height: parent.height; bordered: false
            onClicked: root.pinSelected()
          }
          Button {
            objectName: "launcherEditCommand"
            visible: root.page === "pinned" && !!root.selected && root.selected.kind === "command"
            text: "Edit command"; height: parent.height; bordered: false; onClicked: root.beginCommand(root.selected)
          }
          Button {
            objectName: "launcherMoveEarlier"
            visible: root.page === "pinned" && !!root.selected && !root.removeArmed
            iconText: "󰁍"; Accessible.name: "Move earlier"; width: Style.space(48); height: parent.height; bordered: false
            enabled: root.ready && root.controller.entryIds.indexOf(root.selectedId) > 0
            onClicked: root.controller.move(root.selectedId, -1)
          }
          Button {
            objectName: "launcherMoveLater"
            visible: root.page === "pinned" && !!root.selected && !root.removeArmed
            iconText: "󰁔"; Accessible.name: "Move later"; width: Style.space(48); height: parent.height; bordered: false
            enabled: root.ready && root.controller.entryIds.indexOf(root.selectedId) < root.controller.entryIds.length - 1
            onClicked: root.controller.move(root.selectedId, 1)
          }
          Button {
            objectName: "launcherRemoveSelected"
            visible: root.page === "pinned" && !!root.selected
            text: root.removeArmed ? "Confirm remove" : "Remove button"; foreground: Color.urgent; height: parent.height; bordered: false
            onClicked: { if (root.removeArmed) root.removeSelected(); else root.removeArmed = true }
          }
          Button { visible: root.removeArmed; text: "Keep button"; height: parent.height; bordered: false; onClicked: root.removeArmed = false }
        }
      }
    }
    Flickable {
      id: commandForm
      objectName: "launcherCommandForm"
      visible: root.page === "custom"
      width: parent.width; height: Math.max(0, parent.height - y)
      contentWidth: width; contentHeight: form.implicitHeight
      clip: true; boundsBehavior: Flickable.StopAtBounds; boundsMovement: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick
      maximumFlickVelocity: Math.max(Style.space(320), height * 2.5)
      flickDeceleration: Style.space(3000)
      Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
      Column {
        id: form
        width: parent.width; spacing: Style.spacing.controlGap
        Text { width: parent.width; text: "Save a command to run with one tap. Saving doesn’t run it."; color: DeckColors.secondaryText; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap }
        Repeater {
          model: [ {key: "name", label: "Name", placeholder: "e.g. Backup files"}, {key: "command", label: "Command or script", placeholder: "e.g. bash ~/Scripts/backup.sh"}, {key: "directory", label: "Working folder", placeholder: "Home folder (default)"} ]
          PreferenceAction {
            required property var modelData
            objectName: "launcherField-" + modelData.key
            width: form.width; label: modelData.label
            description: String(root.draft[modelData.key] || modelData.placeholder)
            actionText: "Edit"; iconText: modelData.key === "directory" ? "󰉋" : "󰏫"
            onClicked: root.editField(modelData.key)
          }
        }
        PreferenceToggle {
          objectName: "launcherRunInTerminal"
          width: parent.width; height: Style.space(64)
          label: "Run in a terminal"; description: "For interactive commands or scripts with text output"
          checked: root.draft.terminal === true
          onClicked: root.setDraft("terminal", !checked)
        }
        Text { text: "Icon"; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body }
        Flow {
          width: parent.width; spacing: Style.spacing.controlGap
          Repeater {
            model: Policy.ICONS
            Button {
              required property var modelData
              width: Style.space(56); height: Style.space(48)
              iconText: modelData.glyph; Accessible.name: modelData.label; selected: root.draft.iconId === modelData.id; bordered: false
              onClicked: root.setDraft("iconId", modelData.id)
            }
          }
        }
        Row {
          width: parent.width; spacing: Style.spacing.controlGap
          Button { objectName: "launcherSaveCommand"; text: "Save button"; height: Style.space(48); enabled: root.ready; onClicked: root.saveCommand() }
          Button { text: "Cancel"; height: Style.space(48); bordered: false; onClicked: root.page = "pinned" }
        }
      }
    }
  }
}
