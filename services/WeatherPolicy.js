.pragma library

function canRefresh(enabled, pluginDir) {
  return enabled === true && String(pluginDir || "") !== ""
}

function canHandleTrigger(enabled, trigger, pluginDir) {
  return ["startup", "manual", "location", "retry", "periodic"].indexOf(String(trigger || "")) !== -1
    && canRefresh(enabled, pluginDir)
}

function nextGeneration(generation) {
  return Number(generation || 0) + 1
}

function acceptsResult(enabled, requestGeneration, currentGeneration) {
  return enabled === true && requestGeneration === currentGeneration
}
