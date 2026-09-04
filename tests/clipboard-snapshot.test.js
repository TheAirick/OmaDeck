const assert = require("node:assert/strict")
const childProcess = require("node:child_process")
const fs = require("node:fs")
const os = require("node:os")
const path = require("node:path")
const test = require("node:test")

const repositoryRoot = path.join(__dirname, "..")

function snapshotFor(history) {
  const fixtureRoot = fs.mkdtempSync(path.join(os.tmpdir(), "omadeck-clipboard-"))
  const stateDirectory = path.join(fixtureRoot, "omarchy")
  fs.mkdirSync(stateDirectory, { recursive: true, mode: 0o700 })
  fs.writeFileSync(
    path.join(stateDirectory, "clipboard-history.json"),
    JSON.stringify(history),
    { mode: 0o600 },
  )

  try {
    const result = childProcess.spawnSync(path.join(repositoryRoot, "scripts/system-stats"), [], {
      cwd: repositoryRoot,
      encoding: "utf8",
      env: { ...process.env, XDG_STATE_HOME: fixtureRoot },
      timeout: 10000,
    })
    assert.equal(result.status, 0, result.stderr)
    return JSON.parse(result.stdout).clipboard
  } finally {
    fs.rmSync(fixtureRoot, { recursive: true, force: true })
  }
}

test("system snapshot reads Omarchy's newest-first clipboard array", () => {
  const clipboard = snapshotFor([
    { type: "text", text: "first fixture" },
    { type: "text", text: "second fixture" },
  ])

  assert.equal(clipboard.length, 2)
  assert.deepEqual(clipboard.map((entry) => entry.historyIndex), [0, 1])
  assert.deepEqual(clipboard.map((entry) => entry.text), ["first fixture", "second fixture"])
})

test("clipboard snapshot rejects stale object schemas and caps cardinality", () => {
  assert.deepEqual(snapshotFor({ 0: { type: "text", text: "legacy" } }), [])

  const history = Array.from({ length: 30 }, (_, index) => ({
    type: "text",
    text: `fixture-${index}`,
  }))
  const clipboard = snapshotFor(history)
  assert.equal(clipboard.length, 20)
  assert.equal(clipboard[19].historyIndex, 19)
})
