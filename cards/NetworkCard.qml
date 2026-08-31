import QtQuick
import qs.Commons

InfoCard {
  id: card
  title: "Network"
  summonId: "omarchy.network"

  // Panel root polls `omarchy-network-status --verbose` while open.
  readonly property var info: panelRoot ? panelRoot.netInfo : ({})
  readonly property bool wifi: info.type === "wifi"
  readonly property bool connected: !!info.iface

  glyph: !connected ? "󰤮" : (wifi ? "󰤨" : "󰈀")

  Text {
    width: parent.width
    text: !card.connected ? "Disconnected"
      : (card.wifi ? (card.info.ssid || card.info.iface) : (card.info.iface || ""))
    color: card.fg
    font.family: card.fontName
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
  }

  Text {
    width: parent.width
    visible: card.connected
    text: {
      var bits = []
      if (card.info.ip) bits.push(card.info.ip)
      if (card.wifi && card.info.signal) bits.push(card.info.signal + "%")
      else if (card.info.speed) bits.push(card.info.speed + " Mb/s")
      if (card.info.internet_ping_ms) bits.push(Math.round(Number(card.info.internet_ping_ms)) + " ms")
      return bits.join("  ·  ")
    }
    color: card.fg
    opacity: 0.6
    font.family: card.fontName
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }
}
