.pragma library

function finiteNonNegative(value) {
  var number = Number(value)
  return isFinite(number) && number >= 0 ? number : 0
}

function fitScale(availableWidth, availableHeight, contentWidth, contentHeight) {
  var width = finiteNonNegative(availableWidth)
  var height = finiteNonNegative(availableHeight)
  var naturalWidth = finiteNonNegative(contentWidth)
  var naturalHeight = finiteNonNegative(contentHeight)

  if (naturalWidth === 0 || naturalHeight === 0) return 1
  return Math.max(0, Math.min(1, width / naturalWidth, height / naturalHeight))
}

function useShortWide(availableWidth, availableHeight, standardHeight, wideWidth) {
  var width = finiteNonNegative(availableWidth)
  var height = finiteNonNegative(availableHeight)
  var stackedHeight = finiteNonNegative(standardHeight)
  var requiredWideWidth = finiteNonNegative(wideWidth)
  return height < stackedHeight && width >= requiredWideWidth
}
