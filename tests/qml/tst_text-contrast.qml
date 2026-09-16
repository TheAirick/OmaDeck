import QtQuick
import QtTest
import qs.Commons
import "../../theme"
import "../../theme/TextContrast.js" as Contrast
import "../../modules" as Modules
import "../../components" as Components

TestCase {
  id: testCase
  name: "TextContrast"
  when: windowShown
  width: 700
  height: 350
  visible: true

  Component {
    id: cardComponent
    Components.DeckCard {
      width: 680; height: 330
      title: "Clock"; subtitle: "Secondary label"
      Modules.ClockModule { anchors.fill: parent; now: new Date(2026, 8, 13, 15, 4) }
    }
  }

  function init() {
    Color.foreground = "#f4f4f5"; Color.muted = "#a1a1aa"
    Color.background = "#18181b"; Color.popups.background = "#18181b"
  }
  function cleanup() { init() }

  function findText(item, text) {
    if (item.text !== undefined && item.text === text) return item
    for (var child of item.children) {
      var result = findText(child, text)
      if (result) return result
    }
    return null
  }

  function test_existingLabelsReactToPaletteChanges() {
    var card = createTemporaryObject(cardComponent, testCase)
    var caption = findText(card, "Secondary label")
    var date = findText(card, "Sun, Sep 13")
    verify(caption !== null && date !== null)
    var original = caption.color.toString()
    for (var palette of [
      { muted: "#333333", foreground: "#bebebe", background: "#121212", panel: "#121212" },
      { muted: "#dddddd", foreground: "#222222", background: "#ffffff", panel: "#ffffff" },
      { muted: "#dddddd", foreground: "#222222", background: "#111111", panel: "#fffaf0" },
      { muted: "#333333", foreground: "#dddddd", background: "#121212", panel: "#80121212" }
    ]) {
      Color.muted = palette.muted; Color.foreground = palette.foreground
      Color.background = palette.background; Color.popups.background = palette.panel
      wait(20)
      compare(card.color, DeckColors.surface)
      compare(card.color.a, 1, "text has a predictable solid backing")
      compare(caption.color, DeckColors.secondaryText)
      compare(date.color, DeckColors.secondaryText)
      verify(Contrast.ratio(date.color, card.color) >= 4.5)
    }
    verify(caption.color.toString() !== original)
    init()
    wait(20)
    compare(caption.color.toString(), original, "reverting a theme restores its readable muted color")
  }
}
