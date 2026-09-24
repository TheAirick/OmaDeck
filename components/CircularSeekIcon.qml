import QtQuick
import qs.Commons

Canvas {
  id: seekIcon

  required property bool forward
  property color strokeColor: Color.accent

  width: Style.space(34)
  height: Style.space(34)
  antialiasing: true
  transform: Scale {
    origin.x: seekIcon.width / 2
    origin.y: seekIcon.height / 2
    xScale: seekIcon.forward ? 1 : -1
  }

  onPaint: {
    var context = getContext("2d")
    var centerX = width / 2
    var centerY = height / 2
    var radius = Math.min(width, height) * 0.34
    context.clearRect(0, 0, width, height)
    context.save()
    context.strokeStyle = strokeColor
    context.fillStyle = strokeColor
    context.lineWidth = Style.space(3)
    context.lineCap = "round"
    context.lineJoin = "round"
    context.beginPath()
    context.arc(centerX, centerY, radius, 0, Math.PI * 1.5, false)
    context.stroke()
    context.beginPath()
    context.moveTo(centerX + Style.space(6), centerY - radius)
    context.lineTo(centerX - Style.space(1), centerY - radius - Style.space(4.5))
    context.lineTo(centerX - Style.space(1), centerY - radius + Style.space(4.5))
    context.closePath()
    context.fill()
    context.restore()
  }

  onStrokeColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  Component.onCompleted: requestPaint()
}
