// Pure JS logic for OmarchyInfo — no QML types so the whole file runs under
// `node --test tests/` as well as inside the shell.

var ALL_CARDS = ["network", "audio", "bluetooth", "battery", "stats", "docker", "media"]

var CARD_SOURCES = {
  network: "cards/NetworkCard.qml",
  audio: "cards/AudioCard.qml",
  bluetooth: "cards/BluetoothCard.qml",
  battery: "cards/BatteryCard.qml",
  stats: "cards/StatsCard.qml",
  docker: "cards/DockerCard.qml",
  media: "cards/MediaCard.qml"
}

// Plugins already represented by a curated card. When the card is enabled the
// plugin is dropped from the "other plugins" rows so it isn't listed twice.
var CARD_COVERAGE = {
  network: ["omarchy.network"],
  audio: ["omarchy.audio"],
  bluetooth: ["omarchy.bluetooth"],
  battery: ["omarchy.power"],
  stats: ["omarchy.monitor", "im0001gt.hw-tooltip"],
  docker: ["io.github.dicemans.docker-vms"],
  media: []
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

function clampPct(v) {
  var n = Number(v)
  if (!isFinite(n)) return 0
  return Math.max(0, Math.min(100, n))
}

if (typeof module !== "undefined") {
  module.exports = {
    ALL_CARDS: ALL_CARDS,
    CARD_COVERAGE: CARD_COVERAGE,
    cardSource: cardSource,
    effectiveCards: effectiveCards,
    otherPluginRows: otherPluginRows,
    parseStats: parseStats,
    parseDockerPs: parseDockerPs,
    parseKeyValue: parseKeyValue,
    clampPct: clampPct
  }
}
