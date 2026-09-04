const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")
const crypto = require("node:crypto")
const test = require("node:test")
const childProcess = require("node:child_process")
const os = require("node:os")
const root = path.join(__dirname, "..")

function harness(text) {
  const policy = { Qt: { md5: value => crypto.createHash("md5").update(value).digest("hex") } }
  vm.runInNewContext(fs.readFileSync(path.join(root, "modules/ClipboardDeletePolicy.js"), "utf8").replace(/^\.pragma library\s*/, ""), policy)
  const source = fs.readFileSync(path.join(root, "modules/SystemModule.qml"), "utf8")
  const owner = { history: [{ type: "text", text }] }
  const sent = []
  const context = { ClipboardDeletePolicy: policy, clipboardNotice: "", clipboardCopyText: "",
    clipboardCopyProcess: { running: false, stdinEnabled: false, write: value => sent.push(value) },
    clipboardOwner: () => owner, noticeTimer: { restart() {} }, refreshTimer: { restart() {} },
    Quickshell: { execDetached: command => sent.push(command) } }
  context.root = context
  for (const name of ["copyClipboard", "startClipboardCopy", "finishClipboardCopy"]) {
    const match = source.match(new RegExp("  function " + name + "\\([^]*?\\n  }"))
    if (match) vm.runInNewContext(match[0], context)
  }
  return { context, owner, sent }
}

function snapshot(text) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "omadeck-copy-"))
  try {
    fs.mkdirSync(path.join(directory, "omarchy"), { mode: 0o700 })
    fs.writeFileSync(path.join(directory, "omarchy/clipboard-history.json"), JSON.stringify([{ type: "text", text }]), { mode: 0o600 })
    const result = childProcess.spawnSync("/usr/bin/python3", ["-c", "import runpy,json; m=runpy.run_path('scripts/system-stats'); print(json.dumps(m['clipboard_snapshot']()))"],
      { cwd: root, encoding: "utf8", env: { ...process.env, XDG_STATE_HOME: directory } })
    assert.equal(result.status, 0, result.stderr)
    return JSON.parse(result.stdout)[0]
  } finally { fs.rmSync(directory, { recursive: true, force: true }) }
}

test("copy delivers original long Unicode text, never preview or later history", () => {
  const text = "--history-index 😀\n".repeat(9000) + "original tail\n"
  const entry = snapshot(text)
  const { context, owner, sent } = harness(text)
  context.copyClipboard(entry)
  assert.equal(context.clipboardCopyProcess.running, true)
  assert.equal(context.clipboardCopyProcess.stdinEnabled, true)
  assert.notEqual(context.clipboardNotice, "Copied")
  owner.history[0] = { type: "text", text: "replacement after click" }
  context.startClipboardCopy()
  assert.equal(context.clipboardCopyProcess.stdinEnabled, false)
  assert.deepEqual(sent, [text])
  assert.ok(context.clipboardCopyProcess.command.includes("/usr/bin/wl-copy"))
  context.finishClipboardCopy(0, 0)
  assert.equal(context.clipboardNotice, "Copied")
  assert.equal(context.clipboardCopyText, "")
})

test("failed copies never claim success and stale selections never launch", () => {
  for (const [code, status] of [[1, 0], [124, 0], [0, 1]]) {
    const { context } = harness("original")
    context.finishClipboardCopy(code, status)
    assert.equal(context.clipboardNotice, "Copy failed")
  }
  const { context, sent } = harness("replacement")
  context.copyClipboard(snapshot("original"))
  assert.equal(context.clipboardCopyProcess.running, false)
  assert.deepEqual(sent, [])
  assert.notEqual(context.clipboardNotice, "Copied")
})

test("image copy propagates wl-copy failure instead of helper's success exit", () => {
  const { context, owner } = harness("")
  const image = { type: "image", path: "/synthetic/image ' name.png", mime: "image/png" }
  owner.history = [image]
  context.copyClipboard({ ...image, historyIndex: 0 })
  const command = context.clipboardCopyProcess.command
  assert.ok(command.includes('exec /usr/bin/wl-copy --type "$1" < "$2"'))
  assert.deepEqual(Array.from(command.slice(-2)), [image.mime, image.path])
})
