// Pure JS logic for OmarchyInfo — no QML types so the whole file runs under
// `node --test tests/` as well as inside the shell.

// One catalog drives the card grid, the in-panel settings editor, and the
// manifest multiselect (kept in step by hand there).
var CARD_OPTIONS = [
  { id: "settings", label: "Quick settings", glyph: "󰒓" },
  { id: "network", label: "Network", glyph: "󰖩" },
  { id: "audio", label: "Audio", glyph: "󰕾" },
  { id: "bluetooth", label: "Bluetooth", glyph: "󰂯" },
  { id: "battery", label: "Battery & power", glyph: "󰁹" },
  { id: "stats", label: "CPU / RAM / Disk", glyph: "󰍛" },
  { id: "docker", label: "Docker containers", glyph: "󰡨" },
  { id: "media", label: "Now playing", glyph: "󰝚" },
  { id: "weather", label: "Weather", glyph: "󰖐" },
  { id: "calendar", label: "Calendar", glyph: "󰃭" },
  { id: "agents", label: "AI agents", glyph: "󱚝" },
  { id: "layouts", label: "Workspace layouts", glyph: "󱂬" },
  { id: "plugins", label: "Plugin manager", glyph: "󱓓" }
]

var ALL_CARDS = []
for (var _i = 0; _i < CARD_OPTIONS.length; _i++) ALL_CARDS.push(CARD_OPTIONS[_i].id)

var CARD_SOURCES = {
  settings: "cards/SettingsCard.qml",
  network: "cards/NetworkCard.qml",
  audio: "cards/AudioCard.qml",
  bluetooth: "cards/BluetoothCard.qml",
  battery: "cards/BatteryCard.qml",
  stats: "cards/StatsCard.qml",
  docker: "cards/DockerCard.qml",
  media: "cards/MediaCard.qml",
  weather: "cards/WeatherCard.qml",
  calendar: "cards/CalendarCard.qml",
  agents: "cards/AgentsCard.qml",
  layouts: "cards/LayoutsCard.qml",
  plugins: "cards/PluginsCard.qml"
}

// Plugins already represented by a curated card. When the card is enabled the
// plugin is dropped from the "other plugins" rows so it isn't listed twice.
var CARD_COVERAGE = {
  settings: [],
  network: ["omarchy.network"],
  audio: ["omarchy.audio"],
  bluetooth: ["omarchy.bluetooth"],
  battery: ["omarchy.power"],
  stats: ["omarchy.monitor", "im0001gt.hw-tooltip"],
  docker: ["io.github.dicemans.docker-vms"],
  media: [],
  weather: ["omarchy.weather"],
  calendar: ["tmn73.calendar", "omarchy.clock"],
  agents: ["omarchy.agents"],
  layouts: ["davedes.workspace-restorer"],
  plugins: ["omaplug"]
}

function cardSource(cardId) {
  return CARD_SOURCES[cardId] || ""
}

// Resolve the user's `cards` multiselect into the cards to actually show.
// Empty selection means "all that apply"; capability flags drop cards whose
// hardware/daemon is absent even when explicitly selected (an empty card is
// noise either way).
function effectiveCards(selected, caps) {
  var wanted = Array.isArray(selected) && selected.length > 0 ? selected : ALL_CARDS
  var out = []
  for (var i = 0; i < wanted.length; i++) {
    var id = String(wanted[i])
    if (CARD_SOURCES[id] === undefined) continue
    if (out.indexOf(id) !== -1) continue
    if (id === "battery" && caps && caps.hasBattery === false) continue
    if (id === "docker" && caps && caps.hasDocker === false) continue
    out.push(id)
  }
  return out
}

// Whether a card is part of the current selection (empty selection = all).
function cardShown(selected, id) {
  return !Array.isArray(selected) || selected.length === 0 || selected.indexOf(id) !== -1
}

// Toggle one card in the `cards` selection. An empty selection means "all",
// so the first removal materializes the current list (preserving any custom
// order). Removing the last card is refused — an empty result would read as
// "all" again — and re-checking the full set normalizes back to [] so cards
// added in future versions stay included by default.
function toggleCardSelection(selected, id) {
  if (ALL_CARDS.indexOf(id) === -1) return selected
  var current = []
  if (Array.isArray(selected) && selected.length > 0) {
    for (var i = 0; i < selected.length; i++) {
      var c = String(selected[i])
      if (ALL_CARDS.indexOf(c) !== -1 && current.indexOf(c) === -1) current.push(c)
    }
  } else {
    current = ALL_CARDS.slice()
  }
  var idx = current.indexOf(id)
  if (idx !== -1) {
    if (current.length === 1) return current
    current.splice(idx, 1)
  } else {
    current.push(id)
    if (current.length === ALL_CARDS.length) return []
  }
  return current
}

// Masonry placement: each card lands in the currently shortest column, which
// closes the vertical gaps a row-aligned grid leaves under short cards.
// heights in, {positions: [{column, y}], height} out — pure math so the QML
// side only assigns x/y.
function masonryLayout(heights, columns, gutter) {
  columns = Math.max(1, Math.floor(columns) || 1)
  gutter = Number(gutter) || 0
  var colH = []
  for (var c = 0; c < columns; c++) colH.push(0)
  var positions = []
  for (var i = 0; i < heights.length; i++) {
    var best = 0
    for (var c2 = 1; c2 < columns; c2++) {
      if (colH[c2] < colH[best] - 0.5) best = c2
    }
    positions.push({ column: best, y: colH[best] })
    colH[best] += Number(heights[i]) + gutter
  }
  var total = 0
  for (var c3 = 0; c3 < columns; c3++) total = Math.max(total, colH[c3])
  return { positions: positions, height: Math.max(0, total - gutter) }
}

// Row-aligned placement: classic grid, each row as tall as its tallest card.
function gridLayout(heights, columns, gutter) {
  columns = Math.max(1, Math.floor(columns) || 1)
  gutter = Number(gutter) || 0
  var positions = []
  var y = 0
  for (var i = 0; i < heights.length; i += columns) {
    var rowH = 0
    for (var j = i; j < Math.min(i + columns, heights.length); j++) {
      positions.push({ column: j - i, y: y })
      rowH = Math.max(rowH, Number(heights[j]))
    }
    y += rowH + gutter
  }
  return { positions: positions, height: Math.max(0, y - gutter) }
}

// Rows for enabled bar-widget plugins not already covered by a curated card.
// isEnabledFn keeps registry logic out of here (and mockable in tests).
function otherPluginRows(installedPlugins, enabledCards, selfId, isEnabledFn) {
  var covered = {}
  for (var i = 0; i < enabledCards.length; i++) {
    var ids = CARD_COVERAGE[enabledCards[i]] || []
    for (var j = 0; j < ids.length; j++) covered[ids[j]] = true
  }
  covered[selfId] = true
  var rows = []
  for (var id in installedPlugins) {
    var m = installedPlugins[id]
    if (!m || !Array.isArray(m.kinds) || m.kinds.indexOf("bar-widget") === -1) continue
    if (covered[id]) continue
    if (isEnabledFn && !isEnabledFn(id)) continue
    var bw = m.barWidget || {}
    rows.push({
      id: id,
      displayName: String(bw.displayName || m.name || id),
      category: String(bw.category || "")
    })
  }
  rows.sort(function(a, b) { return a.displayName.localeCompare(b.displayName) })
  return rows
}

// Flag-file backed quick-settings toggles. Omarchy stores these as "-off"
// flag files under ~/.local/state/omarchy/toggles/, so a present flag means
// the feature is disabled. The crash-capture row goes through its wrapper
// because that also stops/starts the watcher unit.
var FLAG_TOGGLES = [
  { key: "screensaver", label: "Screensaver", glyph: "󱄄",
    stateKey: "screensaver-off", cmd: ["omarchy-toggle", "screensaver-off"] },
  { key: "suspend", label: "Suspend in menu", glyph: "󰒲",
    stateKey: "suspend-off", cmd: ["omarchy-toggle", "suspend-off"] },
  { key: "crash-capture", label: "Crash capture", glyph: "󱚡",
    stateKey: "crash-capture-off", cmd: ["omarchy-toggle-crash-capture"] }
]

var INPUT_TOGGLES = [
  { key: "touchpad", label: "Touchpad", glyph: "󰟸", cmd: ["omarchy-toggle-touchpad", "toggle"] },
  { key: "touchscreen", label: "Touchscreen", glyph: "󰝁", cmd: ["omarchy-toggle-touchscreen", "toggle"] }
]

// Quick-settings rows for the toggles the shell has no live service for,
// derived from the probe's key/value output (parseKeyValue). Rows whose
// state key is absent are dropped — the probe hasn't reported yet. Input
// devices additionally require a `<kind>-present` report so a desktop
// without a touchpad never shows a dead switch.
function flagToggleRows(kv) {
  kv = kv || {}
  var rows = []
  for (var i = 0; i < FLAG_TOGGLES.length; i++) {
    var t = FLAG_TOGGLES[i]
    if (kv[t.stateKey] === undefined) continue
    rows.push({ key: t.key, label: t.label, glyph: t.glyph, checked: kv[t.stateKey] !== "1", cmd: t.cmd })
  }
  for (var j = 0; j < INPUT_TOGGLES.length; j++) {
    var d = INPUT_TOGGLES[j]
    if (kv[d.key + "-present"] !== "1") continue
    rows.push({ key: d.key, label: d.label, glyph: d.glyph, checked: kv[d.key + "-disabled"] !== "1", cmd: d.cmd })
  }
  return rows
}

// Parse the token stream from bin/omarchy-info-stats:
//   cpu <pct>
//   ram <usedGiB> <totalGiB> <pct>
//   disk <mount> <usedG> <totalG> <pct>
function parseStats(text) {
  var out = { cpu: -1, ram: null, disks: [] }
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var parts = lines[i].trim().split(/\s+/)
    if (parts.length < 2) continue
    if (parts[0] === "cpu") {
      var v = Number(parts[1])
      if (isFinite(v)) out.cpu = v
    } else if (parts[0] === "ram" && parts.length >= 4) {
      out.ram = { used: Number(parts[1]), total: Number(parts[2]), pct: Number(parts[3]) }
    } else if (parts[0] === "disk" && parts.length >= 5) {
      out.disks.push({
        mount: parts[1],
        used: Number(parts[2]),
        total: Number(parts[3]),
        pct: Number(parts[4])
      })
    }
  }
  return out
}

// Parse `docker ps -a --format '{{.Names}}\t{{.State}}\t{{.Status}}'`.
function parseDockerPs(text) {
  var rows = []
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (line === "") continue
    var parts = line.split("\t")
    if (parts.length < 2) continue
    rows.push({
      name: parts[0],
      state: parts[1],
      status: parts.length > 2 ? parts[2] : ""
    })
  }
  rows.sort(function(a, b) {
    if (a.state === "running" && b.state !== "running") return -1
    if (b.state === "running" && a.state !== "running") return 1
    return a.name.localeCompare(b.name)
  })
  return rows
}

// Parse tab-separated key/value lines (`omarchy-network-status --verbose`).
function parseKeyValue(text) {
  var out = {}
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var idx = lines[i].indexOf("\t")
    if (idx <= 0) continue
    out[lines[i].substring(0, idx)] = lines[i].substring(idx + 1).trim()
  }
  return out
}

// Split a "===REC"-delimited stream of JSON documents into parsed objects,
// dropping records that fail to parse.
function parseDelimitedJson(text) {
  var out = []
  var chunks = String(text || "").split(/^===REC.*$/m)
  for (var i = 0; i < chunks.length; i++) {
    var chunk = chunks[i].trim()
    if (chunk === "") continue
    try {
      var obj = JSON.parse(chunk)
      if (obj && typeof obj === "object") out.push(obj)
    } catch (e) { /* skip malformed record */ }
  }
  return out
}

// Agent usage records (~/.local/state/omarchy/agents/usage/*.json) into
// compact rows for the agents card. `percent` in the records is 0..1.
function agentRows(records) {
  var rows = []
  for (var i = 0; i < records.length; i++) {
    var r = records[i]
    if (!r || !r.id) continue
    var worst = null
    var limits = Array.isArray(r.limits) ? r.limits : []
    for (var j = 0; j < limits.length; j++) {
      var l = limits[j]
      if (!l || !isFinite(Number(l.percent))) continue
      if (worst === null || Number(l.percent) > worst.percent)
        worst = { percent: Number(l.percent), label: String(l.label || "") }
    }
    rows.push({
      id: String(r.id),
      name: String(r.name || r.id),
      tierLabel: String(r.tierLabel || ""),
      ready: r.ready === true,
      worstPercent: worst ? Math.max(0, Math.min(1, worst.percent)) : -1,
      worstLabel: worst ? worst.label : "",
      todayTokens: isFinite(Number(r.todayTotalTokens)) ? Number(r.todayTotalTokens) : 0
    })
  }
  rows.sort(function(a, b) { return b.todayTokens - a.todayTokens })
  return rows
}

function formatTokens(n) {
  n = Number(n)
  if (!isFinite(n) || n <= 0) return "0"
  if (n >= 1e9) return (n / 1e9).toFixed(1) + "B"
  if (n >= 1e6) return (n / 1e6).toFixed(1) + "M"
  if (n >= 1e3) return (n / 1e3).toFixed(1) + "k"
  return String(Math.round(n))
}

// Workspace-restorer profiles from a stream of
//   ===PROFILE\t<name>\t<mtime-epoch-seconds>
// header lines each followed by the profile's JSON body.
function parseProfiles(text) {
  var out = []
  var lines = String(text || "").split("\n")
  var current = null
  var body = []
  function flush() {
    if (!current) return
    var windowCount = -1
    try {
      var doc = JSON.parse(body.join("\n"))
      if (doc && Array.isArray(doc.windows)) windowCount = doc.windows.length
    } catch (e) { /* count stays unknown */ }
    out.push({ name: current.name, savedAtMs: current.savedAtMs, windowCount: windowCount })
  }
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].indexOf("===PROFILE\t") === 0) {
      flush()
      var parts = lines[i].split("\t")
      current = {
        name: String(parts[1] || "unnamed"),
        savedAtMs: isFinite(Number(parts[2])) ? Number(parts[2]) * 1000 : 0
      }
      body = []
    } else if (current) {
      body.push(lines[i])
    }
  }
  flush()
  out.sort(function(a, b) { return a.name.localeCompare(b.name) })
  return out
}

function formatAge(ms, nowMs) {
  if (!isFinite(ms) || ms <= 0) return ""
  var d = Math.max(0, nowMs - ms)
  var mins = Math.floor(d / 60000)
  if (mins < 1) return "just now"
  if (mins < 60) return mins + "m ago"
  var hours = Math.floor(mins / 60)
  if (hours < 24) return hours + "h ago"
  return Math.floor(hours / 24) + "d ago"
}

// Upcoming timed events from the calendar-sync document
// (~/.local/state/omarchy/calendar-events.json). Multi-day events are
// pre-expanded per day and all-day entries carry no useful time, so mirror
// the calendar plugin: timed events only, starting from now.
function upcomingEvents(doc, nowMs, limit) {
  var events = doc && Array.isArray(doc.events) ? doc.events : []
  var out = []
  var seen = {}
  for (var i = 0; i < events.length; i++) {
    var e = events[i]
    if (!e || e.allDay === true) continue
    if (e.eventType === "workingLocation") continue
    if (e.responseStatus === "declined") continue
    var startMs = Date.parse(e.start)
    if (!isFinite(startMs) || isNaN(startMs)) continue
    if (startMs < nowMs) continue
    if (seen[e.id]) continue   // multi-day expansion shares ids
    seen[e.id] = true
    out.push({ title: String(e.title || "Untitled"), startMs: startMs, dateKey: String(e.dateKey || "") })
  }
  out.sort(function(a, b) { return a.startMs - b.startMs })
  return out.slice(0, Math.max(1, limit || 3))
}

// Keybinding hint for the panel header. The bind lives in the user's own
// hypr config (hyprctl compiles lua binds to opaque __lua args, so the files
// are the only place the command string survives); the probe greps
// ~/.config/hypr for the toggle command and this parses the first real bind
// line, in either syntax:
//   o.bind("SUPER + I", "OmarchyInfo", "omarchy-shell shell toggle <id>")
//   bindd = SUPER, I, OmarchyInfo, exec, omarchy-shell shell toggle <id>
// Returns "" when nothing parseable is bound — the header just omits the hint.
function parseShortcutHint(text, moduleId) {
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (line === "" || line.indexOf("--") === 0 || line.indexOf("#") === 0) continue
    if (line.indexOf("toggle " + moduleId) === -1) continue
    var lua = line.match(/\bbind\(\s*"([^"]+)"/)
    if (lua) return formatKeyCombo(lua[1].split("+"))
    var conf = line.match(/^bind[a-z]*\s*=\s*([^,]*),([^,]+),/)
    if (conf) return formatKeyCombo(conf[1].trim().split(/\s+/).concat(conf[2].trim()))
  }
  return ""
}

// "SUPER" -> "Super", "i" -> "I"; mixed-case tokens (XF86…) pass through.
// A $variable can't be resolved here, so the whole combo is dropped rather
// than shown half-wrong.
function formatKeyCombo(parts) {
  var out = []
  for (var i = 0; i < parts.length; i++) {
    var p = String(parts[i]).trim()
    if (p === "") continue
    if (p.indexOf("$") !== -1) return ""
    out.push(p === p.toUpperCase() || p === p.toLowerCase()
      ? p.charAt(0).toUpperCase() + p.substring(1).toLowerCase()
      : p)
  }
  return out.join(" + ")
}

function clampPct(v) {
  var n = Number(v)
  if (!isFinite(n)) return 0
  return Math.max(0, Math.min(100, n))
}

if (typeof module !== "undefined") {
  module.exports = {
    ALL_CARDS: ALL_CARDS,
    CARD_OPTIONS: CARD_OPTIONS,
    CARD_COVERAGE: CARD_COVERAGE,
    cardSource: cardSource,
    effectiveCards: effectiveCards,
    cardShown: cardShown,
    toggleCardSelection: toggleCardSelection,
    masonryLayout: masonryLayout,
    gridLayout: gridLayout,
    flagToggleRows: flagToggleRows,
    otherPluginRows: otherPluginRows,
    parseStats: parseStats,
    parseDockerPs: parseDockerPs,
    parseKeyValue: parseKeyValue,
    parseDelimitedJson: parseDelimitedJson,
    agentRows: agentRows,
    formatTokens: formatTokens,
    parseProfiles: parseProfiles,
    formatAge: formatAge,
    upcomingEvents: upcomingEvents,
    parseShortcutHint: parseShortcutHint,
    clampPct: clampPct
  }
}
