.pragma library

// WCAG relative luminance in sRGB. Return opaque, byte-quantized colors so
// the contrast check describes the color Qt will actually draw.
function composite(color, background) {
  var alpha = color.a === undefined ? 1 : color.a
  return { r: color.r * alpha + background.r * (1 - alpha),
    g: color.g * alpha + background.g * (1 - alpha),
    b: color.b * alpha + background.b * (1 - alpha), a: 1 }
}

function linear(value) {
  return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4)
}

function luminance(color) {
  return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b)
}

function ratio(color, background) {
  var first = luminance(composite(color, background))
  var second = luminance(background)
  return (Math.max(first, second) + 0.05) / (Math.min(first, second) + 0.05)
}

function quantize(color) {
  return { r: Math.round(color.r * 255) / 255, g: Math.round(color.g * 255) / 255,
    b: Math.round(color.b * 255) / 255, a: 1 }
}

function hex(color) {
  function channel(value) { return ("0" + Math.round(value * 255).toString(16)).slice(-2) }
  return "#" + channel(color.r) + channel(color.g) + channel(color.b)
}

function mix(first, second, amount) {
  return quantize({ r: first.r + (second.r - first.r) * amount,
    g: first.g + (second.g - first.g) * amount,
    b: first.b + (second.b - first.b) * amount })
}

function secondary(muted, foreground, background) {
  var minimum = 4.5
  var candidate = quantize(composite(muted, background))
  if (ratio(candidate, background) >= minimum) return hex(candidate)

  // Follow the theme's foreground direction, retaining as much muted tint as
  // possible. If even that foreground is unreadable, use the stronger endpoint.
  var target = quantize(composite(foreground, background))
  if (ratio(target, background) < minimum) {
    var black = { r: 0, g: 0, b: 0, a: 1 }
    var white = { r: 1, g: 1, b: 1, a: 1 }
    target = ratio(black, background) > ratio(white, background) ? black : white
  }
  var low = 0
  var high = 1
  var result = target
  for (var iteration = 0; iteration < 16; iteration++) {
    var amount = (low + high) / 2
    var sample = mix(candidate, target, amount)
    if (ratio(sample, background) >= minimum) {
      result = sample
      high = amount
    } else low = amount
  }
  return hex(result)
}
