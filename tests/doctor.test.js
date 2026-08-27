const assert = require("node:assert/strict")
const fs = require("node:fs")
const os = require("node:os")
const path = require("node:path")
const { spawnSync } = require("node:child_process")
const test = require("node:test")

const repositoryRoot = path.join(__dirname, "..")
const doctorPath = process.env.OMADECK_DOCTOR
  || path.join(repositoryRoot, "scripts/omadeck-doctor")

function executable(filePath, contents) {
  fs.writeFileSync(filePath, contents, { mode: 0o755 })
}

function createFixture({
  bridgeActive,
  shellHasOpenFd,
  touchStateFailures = 0,
  inactiveTouchStates = 0,
}) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "omadeck-doctor-"))
  const binDir = path.join(root, "bin")
  const homeDir = path.join(root, "home")
  const inputRoot = path.join(root, "input")
  const procRoot = path.join(root, "proc")
  const pluginDir = path.join(root, "plugin")
  const touchDevice = path.join(inputRoot, "event13")
  const touchStateCount = path.join(root, "touch-state-count")
  const sleepLog = path.join(root, "sleep-log")

  fs.mkdirSync(binDir, { recursive: true })
  fs.mkdirSync(path.join(homeDir, ".local/bin"), { recursive: true })
  fs.mkdirSync(path.join(procRoot, "4242/fd"), { recursive: true })
  fs.mkdirSync(path.join(pluginDir, "native/OmaDeck/Touch"), { recursive: true })
  fs.mkdirSync(path.join(pluginDir, "native/bin"), { recursive: true })
  fs.mkdirSync(inputRoot, { recursive: true })
  fs.writeFileSync(touchDevice, "")
  fs.writeFileSync(path.join(pluginDir, "native/OmaDeck/Touch/libomadecktouchplugin.so"), "")
  executable(path.join(pluginDir, "native/bin/omadeck-tray"), "#!/usr/bin/env bash\nexit 0\n")
  executable(path.join(homeDir, ".local/bin/alienware-to-omarchy"), "#!/usr/bin/env bash\nexit 0\n")
  executable(path.join(homeDir, ".local/bin/alienware-to-mac"), "#!/usr/bin/env bash\nexit 0\n")

  executable(path.join(binDir, "pgrep"), "#!/usr/bin/env bash\n[[ $* == '-x quickshell' ]] || exit 1\nprintf '4242\\n'\n")
  executable(path.join(binDir, "hyprctl"), "#!/usr/bin/env bash\nprintf '%s\\n' '[{\"name\":\"DP-3\"},{\"name\":\"DP-1\"}]'\n")
  executable(path.join(binDir, "udevadm"), "#!/usr/bin/env bash\nprintf 'ID_INPUT_TOUCHSCREEN=1\\nID_MODEL=XENEON\\n'\n")
  executable(path.join(binDir, "sleep"), `#!/usr/bin/env bash\nprintf '%s\\n' "$1" >>'${sleepLog}'\n`)
  executable(path.join(binDir, "omarchy-shell"), `#!/usr/bin/env bash\nif [[ $2 == touchState ]]; then\n  count=0\n  [[ ! -f '${touchStateCount}' ]] || count=$(<'${touchStateCount}')\n  count=$((count + 1))\n  printf '%s' "$count" >'${touchStateCount}'\n  ((count > ${touchStateFailures})) || exit 1\n  if ((count <= ${touchStateFailures + inactiveTouchStates})); then\n    printf '%s\\n' '${JSON.stringify({ active: false, exclusiveGrab: false, devicePath: "", status: "Direct touch not started" })}'\n  else\n    printf '%s\\n' '${JSON.stringify({ active: bridgeActive, exclusiveGrab: bridgeActive, devicePath: touchDevice, status: bridgeActive ? "Isolated direct touch" : "Direct touch not started" })}'\n  fi\nfi\n`)
  for (const name of ["omarchy", "wpctl"])
    executable(path.join(binDir, name), "#!/usr/bin/env bash\nexit 0\n")

  if (shellHasOpenFd)
    fs.symlinkSync(touchDevice, path.join(procRoot, "4242/fd/79"))

  return {
    cleanup: () => fs.rmSync(root, { recursive: true, force: true }),
    env: {
      ...process.env,
      HOME: homeDir,
      OMADECK_INPUT_ROOT: inputRoot,
      OMADECK_PROC_ROOT: procRoot,
      OMADECK_TOUCH_STATE_ATTEMPTS: "4",
      OMADECK_TOUCH_STATE_RETRY_DELAY: "0",
      PATH: `${binDir}:/usr/bin:/bin`,
    },
    pluginDir,
    sleepLog,
    touchDevice,
    touchStateCount,
  }
}

function runDoctor(fixture, ...args) {
  return spawnSync("bash", [doctorPath, ...args, "--plugin-dir", fixture.pluginDir], {
    encoding: "utf8",
    env: fixture.env,
  })
}

test("doctor reports an IPC-confirmed active exclusive grab", t => {
  const fixture = createFixture({ bridgeActive: true, shellHasOpenFd: true })
  t.after(fixture.cleanup)

  const result = runDoctor(fixture)

  assert.equal(result.status, 0, result.stdout + result.stderr)
  assert.match(result.stdout, /active exclusive grab/)
  assert.match(result.stdout, new RegExp(fixture.touchDevice.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")))
  assert.match(result.stdout, /Overall: healthy/)
})

test("doctor distinguishes an open shell descriptor from an active bridge grab", t => {
  const fixture = createFixture({ bridgeActive: false, shellHasOpenFd: true })
  t.after(fixture.cleanup)

  const result = runDoctor(fixture)

  assert.equal(result.status, 1, result.stdout + result.stderr)
  assert.match(result.stdout, /open by Quickshell/)
  assert.match(result.stdout, /does not report an active exclusive grab/)
  assert.match(result.stdout, /Overall: attention required/)
})

test("summary output remains tray-compatible while failures exit nonzero", t => {
  const fixture = createFixture({ bridgeActive: false, shellHasOpenFd: false })
  t.after(fixture.cleanup)

  const result = runDoctor(fixture, "--summary")

  assert.equal(result.status, 1, result.stdout + result.stderr)
  assert.equal(result.stdout, "Attention — 1 health issue\n")
})

test("doctor tolerates a brief post-rescan IPC registration gap", t => {
  const fixture = createFixture({
    bridgeActive: true,
    shellHasOpenFd: true,
    touchStateFailures: 2,
  })
  t.after(fixture.cleanup)

  const result = runDoctor(fixture, "--summary")

  assert.equal(result.status, 0, result.stdout + result.stderr)
  assert.equal(result.stdout, "Healthy — touchscreen connected\n")
})

test("doctor retries a registered bridge that is not active yet", t => {
  const fixture = createFixture({
    bridgeActive: true,
    shellHasOpenFd: true,
    inactiveTouchStates: 2,
  })
  t.after(fixture.cleanup)

  const result = runDoctor(fixture, "--summary")

  assert.equal(result.status, 0, result.stdout + result.stderr)
  assert.equal(result.stdout, "Healthy — touchscreen connected\n")
})

test("doctor clamps retry overrides to a short bounded probe", t => {
  const fixture = createFixture({ bridgeActive: false, shellHasOpenFd: true })
  t.after(fixture.cleanup)
  fixture.env.OMADECK_TOUCH_STATE_ATTEMPTS = "999"
  fixture.env.OMADECK_TOUCH_STATE_RETRY_DELAY = "999"

  const result = runDoctor(fixture, "--summary")

  assert.equal(result.status, 1, result.stdout + result.stderr)
  assert.equal(fs.readFileSync(fixture.touchStateCount, "utf8"), "10")
  const delays = fs.readFileSync(fixture.sleepLog, "utf8").trim().split("\n")
  assert.equal(delays.length, 9)
  assert.deepEqual(new Set(delays), new Set(["0.1"]))
})

test("DeckSurface exposes the native bridge state over read-only IPC", () => {
  const source = fs.readFileSync(path.join(repositoryRoot, "components/DeckSurface.qml"), "utf8")

  assert.match(source, /function touchState\(\): string/)
  assert.match(source, /active: directTouch\.active/)
  assert.match(source, /exclusiveGrab: directTouch\.active/)
  assert.match(source, /devicePath: directTouch\.devicePath/)
  assert.match(source, /status: directTouch\.status/)
})
