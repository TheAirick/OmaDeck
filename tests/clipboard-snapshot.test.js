const assert = require("node:assert/strict")
const childProcess = require("node:child_process")
const fs = require("node:fs")
const os = require("node:os")
const path = require("node:path")
const test = require("node:test")
const crypto = require("node:crypto")

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
    const result = childProcess.spawnSync("/usr/bin/python3", ["-c",
      "import runpy,json; m=runpy.run_path('scripts/system-stats'); print(json.dumps(m['clipboard_snapshot']()))"], {
      cwd: repositoryRoot,
      encoding: "utf8",
      env: { ...process.env, XDG_STATE_HOME: fixtureRoot },
      timeout: 10000,
    })
    assert.equal(result.status, 0, result.stderr)
    return JSON.parse(result.stdout)
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

test("long text keeps a bounded preview with a full-content action identity", () => {
  const text = "synthetic 😀\n".repeat(400) + "distinct tail"
  const [entry] = snapshotFor([{ type: "text", text }])
  assert.ok(entry.text.length <= 4096) // Python's 2048 Unicode code points
  assert.equal(entry.textDigest, crypto.createHash("md5").update(text).digest("hex"))
})

test("malformed Unicode cannot break the snapshot or become a copy identity", () => {
  const entries = snapshotFor([{ type: "text", text: "\ud800" }, { type: "text", text: "valid" }])
  assert.equal(entries.length, 1)
  assert.equal(entries[0].historyIndex, 1)
})
