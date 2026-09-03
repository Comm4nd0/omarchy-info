import QtQuick
import qs.Commons

InfoCard {
  id: card
  title: "Weather"
  glyph: "󰖐"
  summonId: "omarchy.weather"

  // "Place · Temp +16°C · Wind ↑19km/h" from omarchy-weather-status.
  readonly property string status: panelRoot ? panelRoot.weatherStatus : ""
  readonly property var parts: status.split("·")

  Text {
    width: parent.width
    text: card.parts.length > 1 ? card.parts.slice(1).join("·").trim() : (card.status || "Fetching…")
    textFormat: Text.PlainText
    color: card.fg
    font.family: card.fontName
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
  }

  Text {
    width: parent.width
    visible: card.parts.length > 1
    text: card.parts[0].trim()
    textFormat: Text.PlainText
    color: card.fg
    opacity: 0.6
    font.family: card.fontName
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }
}
