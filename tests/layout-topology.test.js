const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")

const repositoryRoot = path.join(__dirname, "..")
const splitNodeSource = fs.readFileSync(
  path.join(repositoryRoot, "components/SplitNode.qml"),
  "utf8",
)
const deckSurfaceSource = fs.readFileSync(
  path.join(repositoryRoot, "components/DeckSurface.qml"),
  "utf8",
)

function extractFunction(name, dependencies) {
  const signature = new RegExp(`  function ${name}\\(([^)]*)\\) \\{`, "g")
  const match = signature.exec(splitNodeSource)
  assert.ok(match, `could not locate ${name} in SplitNode.qml`)

  const bodyStart = signature.lastIndex
  let depth = 1
  let bodyEnd = bodyStart
  while (depth > 0 && bodyEnd < splitNodeSource.length) {
    if (splitNodeSource[bodyEnd] === "{") depth++
    if (splitNodeSource[bodyEnd] === "}") depth--
    bodyEnd++
  }
  assert.equal(depth, 0, `could not extract ${name} from SplitNode.qml`)

  const body = splitNodeSource.slice(bodyStart, bodyEnd - 1)
  return Function(...Object.keys(dependencies), `return function ${name}(${match[1]}) {${body}}`)(
    ...Object.values(dependencies),
  )
}

test("a topology revision replaces child component types in both directions", () => {
  const nodes = {
    first: { type: "module", moduleId: "clock" },
  }
  const loadedSources = []
  const root = {
    controller: { nodeAt: nodePath => nodes[nodePath] },
    deck: {},
    shell: {},
    primaryMonitor: "DP-1",
    appearanceController: {},
    weatherController: {},
  }
  const Qt = { resolvedUrl: file => file }
  const loadChild = extractFunction("loadChild", { root, Qt })
  const loader = {
    nodePath: "first",
    setSource: source => loadedSources.push(source),
  }

  loadChild(loader)
  nodes.first = {
    type: "split",
    orientation: "vertical",
    ratio: 0.5,
    first: { type: "module", moduleId: "workspaces" },
    second: { type: "module", moduleId: "command-center" },
  }
  loadChild(loader)
  nodes.first = { type: "module", moduleId: "workspaces" }
  loadChild(loader)

  assert.deepEqual(loadedSources, ["ModuleTile.qml", "SplitNode.qml", "ModuleTile.qml"])
})

test("revision handling is safe before child loaders finish construction", () => {
  const root = {
    controller: { nodeAt: () => ({ type: "module", moduleId: "clock" }) },
  }
  const Qt = { resolvedUrl: file => file }
  const loadChild = extractFunction("loadChild", { root, Qt })

  assert.doesNotThrow(() => loadChild(null))
})

test("every revision reloads both child boundaries", () => {
  assert.match(
    splitNodeSource,
    /function reloadChildren\(\)[\s\S]*loadChild\(firstLoader\)[\s\S]*loadChild\(secondLoader\)/,
  )
  assert.match(splitNodeSource, /onObservedRevisionChanged:\s*root\.reloadChildren\(\)/)
})

test("the validated split root remains explicit", () => {
  assert.match(
    deckSurfaceSource,
    /SplitNode \{[\s\S]*controller:\s*root\.layoutController[\s\S]*path:\s*""/,
  )
  assert.doesNotMatch(deckSurfaceSource, /(?:source|setSource)[^\n]*ModuleTile\.qml/)
})
