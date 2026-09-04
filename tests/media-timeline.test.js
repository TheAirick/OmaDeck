const assert = require("node:assert/strict")
const { spawnSync } = require("node:child_process")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")

const runner = "/usr/lib/qt6/bin/qmltestrunner"
test("offscreen media timeline reconciles player reports and bounded seek holds", {
  skip: !fs.existsSync(runner),
}, () => {
  const result = spawnSync(runner, [
    "-input", "tests/qml/tst_media-timeline.qml", "-import", "tests/qml/imports",
  ], {
    cwd: path.join(__dirname, ".."),
    encoding: "utf8",
    timeout: 15000,
    env: { ...process.env, QT_QPA_PLATFORM: "offscreen", QSG_RHI_BACKEND: "software" },
  })
  assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`)
  assert.match(result.stdout, /0 failed/)
  assert.doesNotMatch(result.stdout + result.stderr, /QWARN|QCRITICAL|QFATAL/)
})
