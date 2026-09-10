const assert = require("node:assert/strict")
const { spawnSync } = require("node:child_process")
const path = require("node:path")
const test = require("node:test")

test("native touch releases ownership when synchronous lock access is unavailable", () => {
  const result = spawnSync("/usr/lib/qt6/bin/qmltestrunner", [
    "-input", "tests/qml/tst_optional-touch-bridge.qml", "-import", "tests/qml/imports",
  ], {
    cwd: path.join(__dirname, ".."),
    encoding: "utf8",
    timeout: 15000,
    env: { ...process.env, QT_QPA_PLATFORM: "offscreen", QSG_RHI_BACKEND: "software" },
  })
  assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`)
  assert.doesNotMatch(result.stdout + result.stderr, /QWARN|QCRITICAL|QFATAL/)
})
