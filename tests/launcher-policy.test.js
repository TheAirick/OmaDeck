const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")
const vm = require("node:vm")

const source = fs.readFileSync(path.join(__dirname, "../services/LauncherPolicy.js"), "utf8")
const Policy = vm.runInNewContext(`${source.replace(/^\.pragma library\s*/m, "")}
;({ CATALOG, DEFAULT_IDS, catalog, entryForId, normalizeIds, parseSettings, snapshot, entries, available, add, remove, move })`)

test("launcher settings accept only unique entries from the curated catalog", () => {
  assert.deepEqual(
    Array.from(Policy.parseSettings('{"version":1,"entries":["browser","unknown","browser","lock"]}')),
    ["browser", "lock"],
  )
  assert.equal(Policy.parseSettings('{"version":2,"entries":[]}'), null)
  assert.equal(Policy.parseSettings('{"version":1,"entries":"browser"}'), null)
  assert.deepEqual(
    Array.from(Policy.parseSettings('{"version":1,"entries":["desktop:org.example.App"]}')),
    ["desktop:org.example.App"],
  )
  assert.deepEqual(
    Array.from(Policy.parseSettings('{"version":1,"entries":["desktop:../../bad"]}')),
    [],
  )
})

test("launcher entries support persistent add, remove, and adjacent reordering", () => {
  let ids = Array.from(Policy.DEFAULT_IDS)
  ids = Array.from(Policy.add(ids, "notifications"))
  assert.equal(ids.at(-1), "notifications")
  assert.deepEqual(Array.from(Policy.add(ids, "notifications")), ids)
  ids = Array.from(Policy.move(ids, "notifications", -1))
  assert.equal(ids.at(-2), "notifications")
  ids = Array.from(Policy.remove(ids, "notifications"))
  assert.equal(ids.includes("notifications"), false)
})

test("application and shortcut catalog exposes no user-controlled command vectors", () => {
  const catalog = Policy.catalog()
  assert.ok(catalog.some(entry => entry.kind === "application"))
  assert.ok(catalog.some(entry => entry.kind === "shortcut"))
  for (const entry of catalog) {
    assert.equal(typeof entry.id, "string")
    assert.equal(Object.hasOwn(entry, "command"), false)
  }
})
