const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const { spawnSync } = require("node:child_process")
const test = require("node:test")

test("Preferences requests and responsive choices behave in real QML", {
  skip: !fs.existsSync("/usr/lib/qt6/bin/qmltestrunner"),
}, () => {
  const result = spawnSync("/usr/lib/qt6/bin/qmltestrunner", [
    "-input", "tests/qml/tst_preferences.qml", "-import", "tests/qml/imports",
  ], {
    cwd: path.join(__dirname, ".."), encoding: "utf8", timeout: 60000,
    env: { ...process.env, QT_QPA_PLATFORM: "offscreen", QSG_RHI_BACKEND: "software" },
  })
  assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`)
  assert.match(result.stdout, /0 failed/)
  assert.doesNotMatch(result.stdout + result.stderr, /QWARN|ReferenceError|TypeError/)
})
