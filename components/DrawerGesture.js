function toggleDrawer(currentDrawer, edge) {
  return currentDrawer === edge ? "" : edge
}

function dismissDrawer(currentDrawer, edge) {
  return currentDrawer === edge ? "" : currentDrawer
}

function shouldTrigger(edge, reverse, dx, dy, threshold) {
  var direction = reverse ? -1 : 1

  if (edge === "left") return dx * direction > threshold
  if (edge === "right") return dx * direction < -threshold
  if (edge === "top") return dy * direction > threshold
  if (edge === "bottom") return dy * direction < -threshold
  return false
}

function dismissButtonPosition(edge, width, height, size, leftInset, topInset, rightInset, bottomInset) {
  return {
    x: edge === "left" ? leftInset
      : edge === "right" ? Math.max(leftInset, width - size - rightInset)
      : Math.max(leftInset, (width - size) / 2),
    y: edge === "bottom"
      ? Math.max(topInset, height - size - bottomInset)
      : topInset
  }
}
