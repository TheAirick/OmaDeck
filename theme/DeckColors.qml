pragma Singleton
import QtQuick
import qs.Commons
import "TextContrast.js" as Contrast

QtObject {
  // OmaDeck's solid panel backing also makes translucent popup palettes
  // predictable: wallpaper or artwork cannot wash out a readable text color.
  readonly property color surface: Contrast.hex(Contrast.composite(Color.popups.background, Color.background))
  readonly property color secondaryText: secondaryTextOn(surface)

  function secondaryTextOn(background) {
    var backing = Contrast.composite(background, surface)
    return Contrast.secondary(Color.muted, Color.foreground, backing)
  }
}
