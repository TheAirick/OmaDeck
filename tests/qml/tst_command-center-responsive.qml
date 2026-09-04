import QtQuick
import QtTest
import "../../modules" as Modules

TestCase {
  id: testCase
  name: "CommandCenterResponsive"
  when: windowShown

  width: 700
  height: 500
  visible: true

  function rectIn(item, ancestor) {
    var origin = item.mapToItem(ancestor, 0, 0)
    var corner = item.mapToItem(ancestor, item.width, item.height)
    return {
      x: Math.min(origin.x, corner.x),
      y: Math.min(origin.y, corner.y),
      width: Math.abs(corner.x - origin.x),
      height: Math.abs(corner.y - origin.y)
    }
  }

  function test_narrowDrawerReservationKeepsLargeButtons() {
    var module = createTemporaryObject(commandCenterComponent, testCase, {
      width: 230,
      height: 390,
      deck: deckStub
    })
    verify(module !== null)
    wait(1)

    compare(module.columnCount, 2)
    compare(module.contentScale, 1)
    var hint = findChild(module, "commandCenterInteractionHint")
    verify(hint !== null)
    compare(hint.visible, false, "footer hint stays hidden in the drawer-constrained layout")
    for (var index = 0; index < 6; index++) {
      var edge = ["left", "right", "top", "bottom", "page", "preferences"][index]
      var button = findChild(module, "drawerButton:" + edge)
      verify(button !== null, edge)
      var bounds = rectIn(button, module)
      verify(bounds.width >= 72, edge + " width " + bounds.width)
      verify(bounds.height >= 92, edge + " height " + bounds.height)
      verify(bounds.x >= -0.5 && bounds.y >= -0.5, edge + " origin")
      verify(bounds.x + bounds.width <= module.width + 0.5, edge + " right")
      verify(bounds.y + bounds.height <= module.height + 0.5, edge + " bottom")
    }

    var monitor = findChild(module, "monitorInputModule")
    verify(monitor !== null)
    compare(monitor.height, 76)
    grabImage(module).save("/tmp/omadeck-command-center-narrow.png")
  }

  function test_roomyLayoutKeepsGestureHint() {
    var module = createTemporaryObject(commandCenterComponent, testCase, {
      width: 700,
      height: 500,
      deck: deckStub
    })
    verify(module !== null)
    wait(1)

    compare(module.columnCount, 3)
    var hint = findChild(module, "commandCenterInteractionHint")
    verify(hint !== null)
    compare(hint.visible, true)
  }

  QtObject {
    id: deckStub
    property string commandCenterPage: "home"
    function toggleDrawer(edge) {}
    function openOverlay(name) {}
    function setCommandCenterPage(page) { commandCenterPage = page }
  }

  Component {
    id: commandCenterComponent
    Modules.CommandCenterModule {}
  }
}
