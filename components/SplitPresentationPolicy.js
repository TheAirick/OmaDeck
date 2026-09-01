.pragma library

function effectiveRatio(horizontal, firstModuleId, secondModuleId, savedRatio) {
  if (!horizontal) return savedRatio
  if (firstModuleId === "clock" && secondModuleId === "command-center")
    return Math.max(0.5, savedRatio)
  if (firstModuleId === "command-center" && secondModuleId === "clock")
    return Math.min(0.5, savedRatio)
  return savedRatio
}
