const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")
const test = require("node:test")
const crypto = require("node:crypto")

const repositoryRoot = path.join(__dirname, "..")

function loadPolicy() {
  const source = fs
    .readFileSync(path.join(repositoryRoot, "modules/ClipboardDeletePolicy.js"), "utf8")
    .replace(/^\.pragma library\s*/m, "")
  const context = { Qt: { md5: text => crypto.createHash("md5").update(text).digest("hex") } }
  vm.runInNewContext(source, context, { filename: "ClipboardDeletePolicy.js" })
  return context
}

function plain(value) {
  return JSON.parse(JSON.stringify(value))
}

test("the selected snapshot index distinguishes duplicate clipboard entries", () => {
  const policy = loadPolicy()
  const duplicate = { type: "text", text: "same" }
  const unrelated = { type: "text", text: "keep me" }
  const selected = { ...duplicate, historyIndex: 2 }

  const result = policy.removeEntry([duplicate, unrelated, duplicate], selected)

  assert.equal(result.ok, true)
  assert.deepEqual(plain(result.history), [duplicate, unrelated])
})

test("a shifted snapshot fails closed instead of deleting another entry", () => {
  const policy = loadPolicy()
  const selected = { type: "text", text: "delete me", historyIndex: 0 }
  const changed = [
    { type: "text", text: "new entry" },
    { type: "text", text: "delete me" },
    { type: "text", text: "keep me" },
  ]

  const result = policy.removeEntry(changed, selected)

  assert.equal(result.ok, false)
  assert.equal(result.reason, "changed")
  assert.deepEqual(plain(result.history), changed)
})

test("entry identity includes image path and mime", () => {
  const policy = loadPolicy()
  const history = [
    { type: "image", path: "/owned/image.png", mime: "image/png" },
    { type: "image", path: "/owned/image.png", mime: "image/webp" },
  ]

  const result = policy.removeEntry(history, {
    type: "image",
    path: "/owned/image.png",
    mime: "image/webp",
    historyIndex: 0,
  })

  assert.equal(result.ok, false)
  assert.deepEqual(plain(result.history), history)
})

test("same-index text identity mismatch fails closed", () => {
  const policy = loadPolicy()
  const history = [{ type: "text", text: "keep me" }]

  const result = policy.removeEntry(history, {
    type: "text",
    text: "delete me",
    historyIndex: 0,
  })

  assert.equal(result.ok, false)
  assert.deepEqual(plain(result.history), history)
})

test("invalid and out-of-range snapshot indices fail closed", () => {
  const policy = loadPolicy()
  const history = [{ type: "text", text: "keep" }]

  for (const historyIndex of [-1, 1, 1.5, "0", null]) {
    const result = policy.removeEntry(history, { type: "text", text: "keep", historyIndex })
    assert.equal(result.ok, false, String(historyIndex))
    assert.deepEqual(plain(result.history), history)
  }
})

test("SystemModule delegates history mutation to the authoritative clipboard owner", () => {
  const source = fs.readFileSync(path.join(repositoryRoot, "modules/SystemModule.qml"), "utf8")

  assert.match(source, /import "ClipboardDeletePolicy\.js" as ClipboardDeletePolicy/)
  assert.match(source, /panelLoaders\["omarchy\.clipboard"\]/)
  assert.match(source, /ClipboardDeletePolicy\.removeEntry\(owner\.history, entry\)/)
  assert.match(source, /id: clipboardHistoryFile/)
  assert.match(source, /blockWrites:\s*true/)
  assert.match(source, /onSaved:\s*root\.clipboardSaveSucceeded = true/)
  assert.match(source, /onSaveFailed:/)
  assert.match(source, /saved = clipboardSaveSucceeded/)
  assert.doesNotMatch(source, /clipboardHistoryFile\.waitForJob\(\)/)
  assert.match(source, /owner\.history = result\.history/)
  assert.doesNotMatch(source, /owner\.saveHistory\(\)/)
  assert.match(source, /visible: root\.clipboardNotice !== ""/)
  assert.match(source, /text: root\.clipboardNotice/)
  assert.doesNotMatch(source, /clipboardDeleteProcess/)
  assert.doesNotMatch(source, /scripts\/clipboard-delete/)
})

test("clipboard deletion never performs eager image-file removal", () => {
  const source = fs.readFileSync(path.join(repositoryRoot, "modules/ClipboardDeletePolicy.js"), "utf8")

  assert.doesNotMatch(source, /\brm\b|unlink|removeFile|exec/)
})

test("deletion resolves long text by full identity, not the shared preview", () => {
  const policy = loadPolicy()
  const text = "x".repeat(4096) + "original"
  const original = { type: "text", text }
  const selected = { type: "text", text: text.slice(0, 2048), historyIndex: 0,
    textDigest: crypto.createHash("md5").update(text).digest("hex") }
  assert.equal(policy.removeEntry([original], selected).ok, true)
  for (const history of [
    [{ type: "text", text: "x".repeat(4096) + "replacement" }],
    [{ type: "text", text: "new" }, original],
    [],
  ]) {
    const result = policy.removeEntry(history, selected)
    assert.equal(result.ok, false)
    assert.deepEqual(plain(result.history), history)
  }
})
