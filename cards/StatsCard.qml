import QtQuick
import qs.Commons
import "../Model.js" as Model

InfoCard {
  id: card
  title: "System"
  glyph: "󰍛"
  summonId: "omarchy.monitor"

  // Panel root owns the polling; this card just renders panelRoot.stats.
  readonly property var stats: panelRoot ? panelRoot.stats : ({ cpu: -1, ram: null, disks: [] })

  MiniBar {
    label: "CPU"
    valueText: card.stats.cpu >= 0 ? Math.round(card.stats.cpu) + "%" : "—"
    fraction: card.stats.cpu >= 0 ? card.stats.cpu / 100 : 0
    fg: card.fg
    fontName: card.fontName
  }

  MiniBar {
    label: "RAM"
    valueText: card.stats.ram
      ? card.stats.ram.used.toFixed(1) + " / " + card.stats.ram.total.toFixed(1) + " GiB"
      : "—"
    fraction: card.stats.ram ? Model.clampPct(card.stats.ram.pct) / 100 : 0
    fg: card.fg
    fontName: card.fontName
  }

  Repeater {
    model: card.stats.disks ? card.stats.disks.slice(0, 3) : []
    MiniBar {
      required property var modelData
      label: modelData.mount.toUpperCase()
      valueText: modelData.used + " / " + modelData.total + " GiB"
      fraction: Model.clampPct(modelData.pct) / 100
      fg: card.fg
      fontName: card.fontName
    }
  }
}
