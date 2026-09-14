import QtQuick
import qs.Commons
import qs.Ui
import "../theme"
import "../theme/TextContrast.js" as Contrast

BorderSurface {
  id: root
  property var windowRow: ({})
  property bool showReturn: false
  property string actionName: "Show " + (windowRow.appName || "application") + ", " + (windowRow.title || "")
  property int returnWorkspaceId: 0
  property color backingColor: DeckColors.surface
  property string pressedAddress: ""
  signal activated()
  signal returnRequested()

  height: Style.space(62)
  radius: Style.cornerRadius
  color: Contrast.hex(Contrast.composite(rowTap.pressed ? Style.pressedFillFor(Color.foreground, Color.accent)
    : rowHover.hovered ? Style.hoverFillFor(Color.foreground, Color.accent) : root.backingColor, root.backingColor))
  borderSpec: Border.none()

  Item {
    id: mainTarget
    anchors.fill: parent
    anchors.rightMargin: returnButton.visible ? returnButton.width + Style.spacing.controlGap : 0
    Accessible.role: Accessible.Button
    Accessible.name: root.actionName
    Accessible.onPressAction: root.activated()

    Image {
      id: appIcon
      anchors.left: parent.left
      anchors.leftMargin: Style.spacing.controlGap
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(28); height: width
      source: root.windowRow.iconSource || ""
      fillMode: Image.PreserveAspectFit
      visible: status === Image.Ready
    }
    Text {
      anchors.centerIn: appIcon
      visible: !appIcon.visible
      text: "󰀻"
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.iconLarge
    }
    Column {
      anchors.left: appIcon.right
      anchors.leftMargin: Style.spacing.controlGap
      anchors.right: parent.right
      anchors.rightMargin: Style.spacing.controlGap
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spacing.labelGap
      Text {
        width: parent.width
        text: root.windowRow.appName || "Application"
        textFormat: Text.PlainText
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }
      Text {
        width: parent.width
        text: root.windowRow.title || ""
        textFormat: Text.PlainText
        visible: text !== "" && text !== root.windowRow.appName
        color: DeckColors.secondaryTextOn(root.color)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }
    HoverHandler { id: rowHover }
    TapHandler {
      id: rowTap
      onPressedChanged: if (pressed) root.pressedAddress = root.windowRow.address || ""
      onTapped: if (root.pressedAddress && root.pressedAddress === root.windowRow.address) root.activated()
    }
  }

  BorderSurface {
    id: returnButton
    objectName: "returnParkedWindow"
    property string pressedAddress: ""
    visible: root.showReturn
    enabled: root.returnWorkspaceId > 0
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(76); height: Style.space(48)
    radius: Style.cornerRadius
    color: returnTap.pressed ? Style.pressedFillFor(Color.foreground, Color.accent)
      : returnHover.hovered ? Style.hoverFillFor(Color.foreground, Color.accent) : "transparent"
    borderSpec: Border.none()
    Accessible.role: Accessible.Button
    Accessible.name: "Return " + (root.windowRow.appName || "application") + " to workspace " + root.returnWorkspaceId
    Accessible.onPressAction: if (enabled) root.returnRequested()
    Text {
      anchors.centerIn: parent
      text: "Return"
      color: root.returnWorkspaceId > 0 ? Color.foreground : DeckColors.secondaryText
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
    HoverHandler { id: returnHover }
    TapHandler {
      id: returnTap
      onPressedChanged: if (pressed) returnButton.pressedAddress = root.windowRow.address || ""
      onTapped: if (returnButton.pressedAddress && returnButton.pressedAddress === root.windowRow.address) root.returnRequested()
    }
  }
}
