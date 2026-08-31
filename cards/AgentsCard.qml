import QtQuick
import qs.Commons
import "../Model.js" as Model

InfoCard {
  id: card
  title: "Agents"
  glyph: "󱚝"
  summonId: "omarchy.agents"

  readonly property var agents: panelRoot ? panelRoot.agents : []

  Text {
    width: parent.width
    visible: card.agents.length === 0
    text: "No usage data"
    color: card.fg
    opacity: 0.6
    font.family: card.fontName
    font.pixelSize: Style.font.bodySmall
  }

  Repeater {
    model: card.agents.slice(0, 3)
    MiniBar {
      required property var modelData
      label: (modelData.name + (modelData.tierLabel !== "" ? " · " + modelData.tierLabel : "")).toUpperCase()
      valueText: (modelData.worstPercent >= 0 ? Math.round(modelData.worstPercent * 100) + "%" : "—")
        + " · " + Model.formatTokens(modelData.todayTokens) + " today"
      fraction: Math.max(0, modelData.worstPercent)
      fg: card.fg
      fontName: card.fontName
    }
  }
}
