import QtQuick
import "ResponsiveLayout.js" as ResponsiveLayout

Item {
  id: root

  default property alias content: contentHost.data
  property real padding: 0
  property real maximumContentWidth: availableWidth

  readonly property real availableWidth: Math.max(0, width - padding * 2)
  readonly property real availableHeight: Math.max(0, height - padding * 2)
  readonly property real layoutWidth: Math.min(availableWidth, Math.max(0, maximumContentWidth))
  readonly property real naturalWidth: root.visibleNaturalWidth()
  readonly property real naturalHeight: root.visibleNaturalHeight()
  readonly property real fittedWidth: Math.max(layoutWidth, naturalWidth)
  readonly property real contentScale: ResponsiveLayout.fitScale(
    availableWidth, availableHeight, fittedWidth, naturalHeight)

  clip: true

  function visibleNaturalWidth() {
    var result = 0
    for (var i = 0; i < contentHost.children.length; i++) {
      var child = contentHost.children[i]
      if (child.visible) result = Math.max(result, Number(child.implicitWidth || 0))
    }
    return result
  }

  function visibleNaturalHeight() {
    var result = 0
    for (var i = 0; i < contentHost.children.length; i++) {
      var child = contentHost.children[i]
      if (child.visible)
        result = Math.max(result, Number(child.implicitHeight || 0), Number(child.height || 0))
    }
    return result
  }

  Item {
    id: contentHost
    anchors.centerIn: parent
    // Children receive the real viewport width so their Grid/Flow breakpoints
    // run before the measured result is uniformly fitted.
    width: root.layoutWidth
    height: root.naturalHeight
    scale: root.contentScale
    transformOrigin: Item.Center

    Behavior on scale {
      NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }
  }
}
