const assert = require("node:assert/strict")
const fs = require("node:fs")
const os = require("node:os")
const path = require("node:path")
const { spawnSync } = require("node:child_process")
const test = require("node:test")
const crypto = require("node:crypto")

// Real Qt/Quickshell pipe transport, but never a clipboard client or live shell.
test("installed Quickshell copies full UTF-8 through stdin, closes EOF, and reports failures", () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "omadeck-clipboard-process-"))
  const repository = path.join(__dirname, "..")
  try {
    const text = "--copy-only 😀\n".repeat(12000) + "exact tail\n"
    const digest = crypto.createHash("md5").update(text).digest("hex")
    fs.writeFileSync(path.join(directory, "expected"), text)
    fs.copyFileSync(path.join(repository, "modules/ClipboardDeletePolicy.js"), path.join(directory, "ClipboardDeletePolicy.js"))
    const source = fs.readFileSync(path.join(repository, "modules/SystemModule.qml"), "utf8")
    const functions = ["copyClipboard", "startClipboardCopy", "finishClipboardCopy"].map(name => {
      const match = source.match(new RegExp("  function " + name + "\\([^]*?\\n  }"))
      assert.ok(match, name)
      return match[0]
    }).join("\n")
    const sink = "import sys,pathlib; data=sys.stdin.buffer.read(); expected=pathlib.Path(sys.argv[1]).read_bytes(); sys.exit(0 if data == expected else 7)"
    // Replace the external boundary only; all production functions and Process
    // signals execute unchanged. Images are not used in this transport fixture.
    const safeFunctions = functions.replace('"/usr/bin/wl-copy", "--type", "text/plain;charset=utf-8"',
      `"/usr/bin/python3", "-c", ${JSON.stringify(sink)}, ${JSON.stringify(path.join(directory, "expected"))}`)
    const processBlock = source.match(/  Process \{\n    id: clipboardCopyProcess[^]*?\n  }/)[0]
      + "\n" + (source.match(/  Timer \{\n    id: clipboardCopyStartTimer[^]*?\n  }/) || [""])[0]
    fs.writeFileSync(path.join(directory, "shell.qml"), `
import QtQuick
import Quickshell
import Quickshell.Io
import "ClipboardDeletePolicy.js" as ClipboardDeletePolicy
Item {
  id: root
  property string clipboardCopyText: ""
  property string clipboardNotice: ""
  property int completed: 0
  property var owner: ({history: [{type: "text", text: ${JSON.stringify(text)}}]})
  function clipboardOwner() { return owner }
  ${safeFunctions}
  ${processBlock}
  Timer { id: refreshTimer }
  Timer { id: noticeTimer; interval: 1; onTriggered: {
    if (root.clipboardNotice !== (root.completed < 2 ? "Copied" : "Copy failed")) {
      console.log("FIXTURE_FAILED"); Qt.quit(); return
    }
    root.completed++
    if (root.completed === 3) { console.log("FIXTURE_PASSED"); Qt.quit(); return }
    if (root.completed === 2) {
      clipboardCopyProcess.command = ["/usr/bin/python3", "-c", "import sys; sys.exit(7)"]
      clipboardCopyProcess.stdinEnabled = true
      clipboardCopyProcess.running = true
    } else root.copyClipboard({type: "text", text: "preview", historyIndex: 0, textDigest: "${digest}"})
  } }
  Timer { interval: 5000; running: true; onTriggered: { console.log("FIXTURE_TIMEOUT"); Qt.quit() } }
  Component.onCompleted: root.copyClipboard({type: "text", text: "preview", historyIndex: 0, textDigest: "${digest}"})
}
`)
    const result = spawnSync("/usr/bin/qs", ["--no-color", "-p", path.join(directory, "shell.qml")], {
      encoding: "utf8", timeout: 10000,
      env: { ...process.env, QT_QPA_PLATFORM: "offscreen", QT_QPA_PLATFORMTHEME: "basic",
        XDG_RUNTIME_DIR: directory, XDG_STATE_HOME: directory, XDG_CACHE_HOME: directory,
        WAYLAND_DISPLAY: "omadeck-nonexistent-test-display", DISPLAY: "" },
    })
    const output = result.stdout + result.stderr
    assert.equal(result.status, 0, output)
    assert.match(output, /FIXTURE_PASSED/)
    assert.doesNotMatch(output, /FIXTURE_FAILED|FIXTURE_TIMEOUT|TypeError|ReferenceError/)
  } finally { fs.rmSync(directory, { recursive: true, force: true }) }
})


for (const missing of ["launcher", "timeout"]) {
  test(`failed clipboard ${missing} start releases text and allows a successful retry`, () => {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), "omadeck-copy-start-"))
    try {
      const source = fs.readFileSync(path.join(__dirname, "../modules/SystemModule.qml"), "utf8")
      fs.copyFileSync(path.join(__dirname, "../modules/ClipboardDeletePolicy.js"), path.join(directory, "ClipboardDeletePolicy.js"))
      const text = "synthetic pending copy".repeat(16000)
      const digest = crypto.createHash("md5").update(text).digest("hex")
      let functions = ["copyClipboard", "startClipboardCopy", "finishClipboardCopy"].map(name =>
        source.match(new RegExp("  function " + name + "\\([^]*?\\n  }"))[0]).join("\n")
      functions = functions.replace('"/usr/bin/wl-copy", "--type", "text/plain;charset=utf-8"',
        '"/usr/bin/python3", "-c", "import sys; sys.stdin.buffer.read()"')
      // Missing env means QProcess FailedToStart; missing timeout means env exits
      // 127. Neither path can ever reach wl-copy or the live shell.
      const missingPath = JSON.stringify(path.join(directory, "nonexistent-" + missing))
      functions = functions.replaceAll(JSON.stringify(missing === "launcher" ? "/usr/bin/env" : "/usr/bin/timeout"),
        `(root.retry ? ${JSON.stringify(missing === "launcher" ? "/usr/bin/env" : "/usr/bin/timeout")} : ${missingPath})`)
      const processBlock = source.match(/  Process \{\n    id: clipboardCopyProcess[^]*?\n  }/)[0]
      const timerBlock = (source.match(/  Timer \{\n    id: clipboardCopyStartTimer[^]*?\n  }/) || [""])[0]
      fs.writeFileSync(path.join(directory, "shell.qml"), `
import QtQuick
import Quickshell
import Quickshell.Io
import "ClipboardDeletePolicy.js" as ClipboardDeletePolicy
Item {
  id: root
  property string clipboardCopyText: ""
  property string clipboardNotice: ""
  property bool retry: false
  property var owner: ({history: [{type: "text", text: ${JSON.stringify(text)}}]})
  function clipboardOwner() { return owner }
  function copy() { copyClipboard({type: "text", text: "preview", historyIndex: 0, textDigest: "${digest}"}) }
  ${functions}
  ${processBlock}
  ${timerBlock}
  Timer { id: refreshTimer }
  Timer { id: noticeTimer; interval: 1; onTriggered: {
    if (root.clipboardNotice !== (root.retry ? "Copied" : "Copy failed") ||
        root.clipboardCopyText !== "" || clipboardCopyProcess.stdinEnabled || clipboardCopyProcess.running) {
      console.log("FIXTURE_FAILED cleanup/status notice=" + root.clipboardNotice + " pending=" + (root.clipboardCopyText.length > 0) + " stdin=" + clipboardCopyProcess.stdinEnabled + " running=" + clipboardCopyProcess.running); Qt.quit(); return
    }
    if (root.retry) { console.log("FIXTURE_PASSED"); Qt.quit(); return }
    root.retry = true
    root.copy()
  } }
  Timer { interval: 2500; running: true; onTriggered: {
    console.log("FIXTURE_FAILED pending=" + (root.clipboardCopyText.length > 0) + " notice=" + root.clipboardNotice)
    Qt.quit()
  } }
  Component.onCompleted: copy()
}
`)
      const result = spawnSync("/usr/bin/qs", ["--no-color", "-p", path.join(directory, "shell.qml")], {
        encoding: "utf8", timeout: 6000,
        env: { ...process.env, QT_QPA_PLATFORM: "offscreen", QT_QPA_PLATFORMTHEME: "basic",
          XDG_RUNTIME_DIR: directory, XDG_STATE_HOME: directory, XDG_CACHE_HOME: directory,
          WAYLAND_DISPLAY: "omadeck-nonexistent-test-display", DISPLAY: "" },
      })
      const output = result.stdout + result.stderr
      assert.equal(result.status, 0, output)
      assert.match(output, /FIXTURE_PASSED/, output)
      assert.doesNotMatch(output, /FIXTURE_FAILED|TypeError|ReferenceError/)
    } finally { fs.rmSync(directory, { recursive: true, force: true }) }
  })
}
