const test = require("node:test")
const assert = require("node:assert")
const Model = require("../Model.js")

test("effectiveCards: empty selection means all applicable", () => {
  const all = Model.effectiveCards([], { hasBattery: true, hasDocker: true })
  assert.deepStrictEqual(all, Model.ALL_CARDS)
})

test("effectiveCards: capability flags drop battery and docker", () => {
  const cards = Model.effectiveCards([], { hasBattery: false, hasDocker: false })
  assert.ok(!cards.includes("battery"))
  assert.ok(!cards.includes("docker"))
  assert.ok(cards.includes("audio"))
})

test("effectiveCards: explicit selection is honored, unknown ids dropped", () => {
  const cards = Model.effectiveCards(["stats", "nope", "audio", "stats"], { hasBattery: true, hasDocker: true })
  assert.deepStrictEqual(cards, ["stats", "audio"])
})

test("effectiveCards: explicitly selected docker still hidden when unavailable", () => {
  const cards = Model.effectiveCards(["docker", "audio"], { hasDocker: false })
  assert.deepStrictEqual(cards, ["audio"])
})

test("cardSource maps every card id to a file", () => {
  for (const id of Model.ALL_CARDS) {
    assert.match(Model.cardSource(id), /^cards\/[A-Za-z]+\.qml$/)
  }
  assert.strictEqual(Model.cardSource("bogus"), "")
})

const REGISTRY = {
  "omarchy.network": { kinds: ["bar-widget"], name: "Network", barWidget: { displayName: "Network", category: "System" } },
  "omarchy.clock": { kinds: ["bar-widget"], name: "Clock", barWidget: { displayName: "Clock", category: "Time" } },
  "tmn73.calendar": { kinds: ["bar-widget"], name: "Calendar", barWidget: { displayName: "Calendar", category: "Time" } },
  "im0001gt.hw-tooltip": { kinds: ["bar-widget"], name: "HW Tooltip", barWidget: { displayName: "HW Tooltip" } },
  "omarchy.media": { kinds: ["service", "bar-widget"], name: "Media" },
  "bobbynicholas.omaland": { kinds: ["overlay"], name: "Omaland" },
  "marco.omarchy-info": { kinds: ["bar-widget"], name: "OmarchyInfo", barWidget: { displayName: "OmarchyInfo" } },
  "disabled.widget": { kinds: ["bar-widget"], name: "Disabled" }
}
const isEnabled = (id) => id !== "disabled.widget"

test("otherPluginRows: excludes covered, self, non-bar-widget and disabled", () => {
  const rows = Model.otherPluginRows(REGISTRY, ["network", "stats"], "marco.omarchy-info", isEnabled)
  const ids = rows.map((r) => r.id)
  assert.ok(!ids.includes("omarchy.network"), "covered by network card")
  assert.ok(!ids.includes("im0001gt.hw-tooltip"), "covered by stats card")
  assert.ok(!ids.includes("marco.omarchy-info"), "self")
  assert.ok(!ids.includes("bobbynicholas.omaland"), "not a bar widget")
  assert.ok(!ids.includes("disabled.widget"), "disabled")
  assert.ok(ids.includes("omarchy.clock"))
  assert.ok(ids.includes("tmn73.calendar"))
})

test("otherPluginRows: uncovered card ids appear when their card is off", () => {
  const rows = Model.otherPluginRows(REGISTRY, ["stats"], "marco.omarchy-info", isEnabled)
  assert.ok(rows.map((r) => r.id).includes("omarchy.network"))
})

test("otherPluginRows: sorted by display name with fallbacks", () => {
  const rows = Model.otherPluginRows(REGISTRY, [], "marco.omarchy-info", isEnabled)
  const names = rows.map((r) => r.displayName)
  assert.deepStrictEqual(names, [...names].sort((a, b) => a.localeCompare(b)))
  const media = rows.find((r) => r.id === "omarchy.media")
  assert.strictEqual(media.displayName, "Media", "falls back to manifest name")
})

test("parseStats: parses the helper token stream", () => {
  const out = Model.parseStats("cpu 42\nram 12.3 62.5 20\ndisk / 265 1906 14\ndisk /boot 1 2 15\njunk\n")
  assert.strictEqual(out.cpu, 42)
  assert.deepStrictEqual(out.ram, { used: 12.3, total: 62.5, pct: 20 })
  assert.strictEqual(out.disks.length, 2)
  assert.deepStrictEqual(out.disks[1], { mount: "/boot", used: 1, total: 2, pct: 15 })
})

test("parseStats: empty and garbage input", () => {
  assert.deepStrictEqual(Model.parseStats(""), { cpu: -1, ram: null, disks: [] })
  assert.deepStrictEqual(Model.parseStats("cpu notanumber"), { cpu: -1, ram: null, disks: [] })
})

test("parseDockerPs: running containers sort first, then by name", () => {
  const rows = Model.parseDockerPs("zeta\trunning\tUp 2 hours\nalpha\texited\tExited (0)\nbeta\trunning\tUp 5 minutes\n")
  assert.deepStrictEqual(rows.map((r) => r.name), ["beta", "zeta", "alpha"])
  assert.strictEqual(rows[0].state, "running")
  assert.strictEqual(rows[2].status, "Exited (0)")
})

test("parseKeyValue: tab-separated pairs", () => {
  const out = Model.parseKeyValue("iface\teno1\nip\t192.168.1.21\ntype\tethernet\nbroken line\n")
  assert.strictEqual(out.iface, "eno1")
  assert.strictEqual(out.type, "ethernet")
  assert.strictEqual(out["broken line"], undefined)
})

test("clampPct bounds values", () => {
  assert.strictEqual(Model.clampPct(-5), 0)
  assert.strictEqual(Model.clampPct(150), 100)
  assert.strictEqual(Model.clampPct("42"), 42)
  assert.strictEqual(Model.clampPct("junk"), 0)
})
