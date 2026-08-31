import QtQuick
import qs.Commons
import "../Model.js" as Model

InfoCard {
  id: card
  title: "Workspace layouts"
  glyph: "󰆞"
  summonId: "davedes.workspace-restorer"

  readonly property var layouts: panelRoot ? panelRoot.layouts : []

  Text {
    width: parent.width
    visible: card.layouts.length === 0
    text: "No saved layouts"
    color: card.fg
    opacity: 0.6
    font.family: card.fontName
    font.pixelSize: Style.font.bodySmall
  }

  Repeater {
    model: card.layouts.slice(0, 3)
    Item {
      required property var modelData
      width: parent.width
      implicitHeight: nameText.implicitHeight

      Text {
        id: detailText
        text: (modelData.windowCount >= 0 ? modelData.windowCount + " win" : "")
          + (modelData.savedAtMs > 0 ? " · " + Model.formatAge(modelData.savedAtMs, Date.now()) : "")
        color: card.fg
        opacity: 0.6
        font.family: card.fontName
        font.pixelSize: Style.font.caption
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: nameText
        text: modelData.name
        color: card.fg
        font.family: card.fontName
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        anchors.left: parent.left
        anchors.right: detailText.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
