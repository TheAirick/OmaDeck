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
