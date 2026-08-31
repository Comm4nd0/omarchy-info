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

test("CARD_OPTIONS drives ALL_CARDS", () => {
  assert.deepStrictEqual(Model.ALL_CARDS, Model.CARD_OPTIONS.map((o) => o.id))
})

test("cardShown: empty selection shows everything", () => {
  assert.strictEqual(Model.cardShown([], "audio"), true)
  assert.strictEqual(Model.cardShown(null, "audio"), true)
  assert.strictEqual(Model.cardShown(["audio"], "audio"), true)
  assert.strictEqual(Model.cardShown(["audio"], "stats"), false)
})

test("toggleCardSelection: first removal materializes the full list", () => {
  const next = Model.toggleCardSelection([], "docker")
  assert.deepStrictEqual(next, Model.ALL_CARDS.filter((c) => c !== "docker"))
})

test("toggleCardSelection: re-checking the full set normalizes to []", () => {
  const withoutDocker = Model.ALL_CARDS.filter((c) => c !== "docker")
  assert.deepStrictEqual(Model.toggleCardSelection(withoutDocker, "docker"), [])
})

test("toggleCardSelection: refuses to empty the selection, keeps custom order", () => {
  assert.deepStrictEqual(Model.toggleCardSelection(["audio"], "audio"), ["audio"])
  assert.deepStrictEqual(Model.toggleCardSelection(["stats", "audio"], "audio"), ["stats"])
  assert.deepStrictEqual(Model.toggleCardSelection(["stats", "audio"], "network"), ["stats", "audio", "network"])
  assert.deepStrictEqual(Model.toggleCardSelection(["audio"], "bogus"), ["audio"])
})

test("masonryLayout: cards drop into the shortest column", () => {
  const res = Model.masonryLayout([100, 40, 30, 50], 2, 10)
  assert.deepStrictEqual(res.positions, [
    { column: 0, y: 0 },
    { column: 1, y: 0 },
    { column: 1, y: 50 },   // col1 at 50 < col0 at 110
    { column: 1, y: 90 }    // col1 at 90 still shortest
  ])
  assert.strictEqual(res.height, 140)  // col1: 40+30+50 + 2 gutters
})

test("masonryLayout: single column stacks in order", () => {
  const res = Model.masonryLayout([10, 20], 1, 5)
  assert.deepStrictEqual(res.positions, [{ column: 0, y: 0 }, { column: 0, y: 15 }])
  assert.strictEqual(res.height, 35)
})

test("gridLayout: rows aligned to the tallest card", () => {
  const res = Model.gridLayout([100, 40, 30, 50], 2, 10)
  assert.deepStrictEqual(res.positions, [
    { column: 0, y: 0 },
    { column: 1, y: 0 },
    { column: 0, y: 110 },
    { column: 1, y: 110 }
  ])
  assert.strictEqual(res.height, 160)
})

test("layout helpers: empty input", () => {
  assert.deepStrictEqual(Model.masonryLayout([], 2, 10), { positions: [], height: 0 })
  assert.deepStrictEqual(Model.gridLayout([], 2, 10), { positions: [], height: 0 })
})

test("flagToggleRows: off-flags invert into checked state", () => {
  const rows = Model.flagToggleRows({
    "screensaver-off": "1", "suspend-off": "0", "crash-capture-off": "0",
    "touchpad-present": "0", "touchpad-disabled": "0",
    "touchscreen-present": "0", "touchscreen-disabled": "0"
  })
  const byKey = Object.fromEntries(rows.map((r) => [r.key, r]))
  assert.strictEqual(byKey.screensaver.checked, false, "flag present means disabled")
  assert.strictEqual(byKey.suspend.checked, true)
  assert.strictEqual(byKey["crash-capture"].checked, true)
  assert.ok(byKey.screensaver.cmd.length > 0)
})

test("flagToggleRows: input devices only listed when present", () => {
  const none = Model.flagToggleRows({
    "screensaver-off": "0", "suspend-off": "0", "crash-capture-off": "0",
    "touchpad-present": "0", "touchpad-disabled": "0"
  })
  assert.ok(!none.some((r) => r.key === "touchpad"))
  const withPad = Model.flagToggleRows({
    "screensaver-off": "0", "suspend-off": "0", "crash-capture-off": "0",
    "touchpad-present": "1", "touchpad-disabled": "1"
  })
  const pad = withPad.find((r) => r.key === "touchpad")
  assert.strictEqual(pad.checked, false, "disabled name file means off")
})

test("flagToggleRows: empty probe output yields no rows", () => {
  assert.deepStrictEqual(Model.flagToggleRows({}), [])
  assert.deepStrictEqual(Model.flagToggleRows(null), [])
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

test("parseDelimitedJson: splits records, skips garbage", () => {
  const out = Model.parseDelimitedJson('===REC\n{"id":"a"}\n===REC\nnot json\n===REC\n{"id":"b"}\n')
  assert.deepStrictEqual(out.map((r) => r.id), ["a", "b"])
  assert.deepStrictEqual(Model.parseDelimitedJson(""), [])
})

test("agentRows: worst limit and token sort", () => {
  const rows = Model.agentRows([
    { id: "claude", name: "Claude Code", tierLabel: "Max 20x", ready: true,
      limits: [{ label: "Session (5-hour)", percent: 0.14 }, { label: "Weekly (7-day)", percent: 0.27 }],
      todayTotalTokens: 49273902 },
    { id: "codex", name: "Codex", limits: [], todayTotalTokens: 100 },
    { bogus: true }
  ])
  assert.strictEqual(rows.length, 2)
  assert.strictEqual(rows[0].id, "claude")
  assert.strictEqual(rows[0].worstPercent, 0.27)
  assert.strictEqual(rows[0].worstLabel, "Weekly (7-day)")
  assert.strictEqual(rows[1].worstPercent, -1)
})

test("formatTokens", () => {
  assert.strictEqual(Model.formatTokens(49273902), "49.3M")
  assert.strictEqual(Model.formatTokens(950), "950")
  assert.strictEqual(Model.formatTokens(1500), "1.5k")
  assert.strictEqual(Model.formatTokens(0), "0")
})

test("parseProfiles: name, mtime, window count", () => {
  const text = '===PROFILE\tStandard layout\t1788092553\n{"timestamp":1,"windows":[{},{},{}]}\n'
    + '===PROFILE\tBroken\t0\nnot json\n'
  const out = Model.parseProfiles(text)
  assert.strictEqual(out.length, 2)
  const std = out.find((p) => p.name === "Standard layout")
  assert.strictEqual(std.windowCount, 3)
  assert.strictEqual(std.savedAtMs, 1788092553000)
  assert.strictEqual(out.find((p) => p.name === "Broken").windowCount, -1)
})

test("formatAge", () => {
  const now = Date.now()
  assert.strictEqual(Model.formatAge(now - 30000, now), "just now")
  assert.strictEqual(Model.formatAge(now - 5 * 60000, now), "5m ago")
  assert.strictEqual(Model.formatAge(now - 3 * 3600000, now), "3h ago")
  assert.strictEqual(Model.formatAge(now - 49 * 3600000, now), "2d ago")
  assert.strictEqual(Model.formatAge(0, now), "")
})

test("upcomingEvents: timed, future, deduped, sorted, capped", () => {
  const now = Date.parse("2026-08-31T10:00:00+01:00")
  const doc = { events: [
    { id: "past", title: "Past", start: "2026-08-31T08:00:00+01:00", dateKey: "2026-08-31" },
    { id: "allday", title: "Holiday", allDay: true, start: "2026-08-31T00:00:00+01:00", dateKey: "2026-08-31" },
    { id: "wl", title: "Office", eventType: "workingLocation", start: "2026-08-31T11:00:00+01:00", dateKey: "2026-08-31" },
    { id: "declined", title: "Nope", responseStatus: "declined", start: "2026-08-31T11:00:00+01:00", dateKey: "2026-08-31" },
    { id: "multi", title: "Conf", start: "2026-08-31T12:00:00+01:00", dateKey: "2026-08-31" },
    { id: "multi", title: "Conf", start: "2026-08-31T12:00:00+01:00", dateKey: "2026-09-01" },
    { id: "b", title: "Later", start: "2026-08-31T11:30:00+01:00", dateKey: "2026-08-31" },
    { id: "c", title: "Tomorrow", start: "2026-09-01T09:00:00+01:00", dateKey: "2026-09-01" },
    { id: "d", title: "Next", start: "2026-09-02T09:00:00+01:00", dateKey: "2026-09-02" }
  ] }
  const out = Model.upcomingEvents(doc, now, 3)
  assert.deepStrictEqual(out.map((e) => e.title), ["Later", "Conf", "Tomorrow"])
  assert.deepStrictEqual(Model.upcomingEvents({}, now, 3), [])
})

test("clampPct bounds values", () => {
  assert.strictEqual(Model.clampPct(-5), 0)
  assert.strictEqual(Model.clampPct(150), 100)
  assert.strictEqual(Model.clampPct("42"), 42)
  assert.strictEqual(Model.clampPct("junk"), 0)
})
