pragma Singleton
import QtQuick

QtObject {
  function flat(color, width) {
    return { color: color, widths: { top: width, right: width, bottom: width, left: width } }
  }
  function none() { return flat("transparent", 0) }
  function controlSpec(section, foreground, accent, urgent) { return flat(foreground, 1) }
  function hyprlandActiveSpec(color, width) { return flat(color, width) }
  function surfaceSpec(section, token, color, width) { return flat(color, width) }
  function top(spec) { return spec.widths.top }
  function right(spec) { return spec.widths.right }
  function bottom(spec) { return spec.widths.bottom }
  function left(spec) { return spec.widths.left }
  function canUseNative(spec) { return true }
  function color(spec) { return spec.color }
  function uniformWidth(spec) { return spec.widths.top }
}