import assert from "node:assert/strict"
import fs from "node:fs"
import vm from "node:vm"
import test from "node:test"

function loadPolicy() {
  const source = fs
    .readFileSync(new URL("../services/HardwarePolicy.js", import.meta.url), "utf8")
    .replace(/^\.pragma library\s*/m, "")
  const context = {}
  vm.runInNewContext(source, context, { filename: "HardwarePolicy.js" })
  return context
}

test("hardware settings accept bounded monitor and direct-touch identities", () => {
  const policy = loadPolicy()
  const parsed = policy.parseSettings(JSON.stringify({
    version: 1,
    targetScreen: "DP-3",
    primaryMonitor: "DP-1",
    touchDeviceNames: ["WCH.CN", "xeneon", "WCH.CN"],
  }))

  assert.equal(parsed.targetScreen, "DP-3")
  assert.equal(parsed.primaryMonitor, "DP-1")
  assert.deepEqual(Array.from(parsed.touchDeviceNames), ["WCH.CN", "xeneon"])
})

test("invalid hardware persistence fails closed", () => {
  const policy = loadPolicy()
  const oversized = "x".repeat(161)
  for (const raw of [
    "not json",
    "{}",
    JSON.stringify({ version: 2, targetScreen: "DP-3", primaryMonitor: "DP-1", touchDeviceNames: ["XENEON"] }),
    JSON.stringify({ version: 1, targetScreen: "", primaryMonitor: "DP-1", touchDeviceNames: ["XENEON"] }),
    JSON.stringify({ version: 1, targetScreen: "DP-3", primaryMonitor: "DP-1", touchDeviceNames: [] }),
    JSON.stringify({ version: 1, targetScreen: "DP-3", primaryMonitor: "DP-1", touchDeviceNames: [oversized] }),
    JSON.stringify({ version: 1, targetScreen: "DP-3\nBAD", primaryMonitor: "DP-1", touchDeviceNames: ["XENEON"] }),
  ]) assert.equal(policy.parseSettings(raw), null)
})

test("hardware choices require exact detected values and match configured touch substrings", () => {
  const policy = loadPolicy()

  assert.equal(policy.includesExact(["DP-1", "DP-3"], "DP-3"), true)
  assert.equal(policy.includesExact(["DP-1", "DP-3"], "dp-3"), false)
  assert.equal(
    policy.touchSelection(["WCH.CN", "XENEON"], ["ELAN Touch", "wch.cn TouchScreen"]),
    "wch.cn TouchScreen",
  )
  assert.equal(policy.touchSelection(["XENEON"], ["ELAN Touch"]), "")

  const qtStyleList = { 0: "wch.cn TouchScreen", length: 1 }
  assert.equal(policy.includesExact(qtStyleList, "wch.cn TouchScreen"), true)
  assert.equal(policy.touchSelection(["WCH.CN"], qtStyleList), "wch.cn TouchScreen")
})

test("first run prefers the known deck and otherwise selects a connected secondary", () => {
  const policy = loadPolicy()

  assert.deepEqual(
    JSON.parse(JSON.stringify(policy.initialSnapshot(["DP-1", "DP-3"]))),
    {
      version: 1,
      targetScreen: "DP-3",
      primaryMonitor: "DP-1",
      touchDeviceNames: ["WCH.CN", "XENEON"],
    },
  )
  assert.equal(policy.initialSnapshot(["DP-1", "HDMI-A-1"]).targetScreen, "HDMI-A-1")
  assert.equal(policy.initialSnapshot(["eDP-1"]).targetScreen, "eDP-1")
  assert.equal(policy.initialSnapshot([]).targetScreen, "DP-3")
})
