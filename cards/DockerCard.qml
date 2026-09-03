import QtQuick
import qs.Commons

InfoCard {
  id: card
  title: "Docker"
  glyph: "󰡨"
  summonId: panelRoot && panelRoot.hasDockerVmsPlugin ? "io.github.dicemans.docker-vms" : ""

  // Panel root polls `docker ps -a` while open.
  readonly property var containers: panelRoot ? panelRoot.containers : []
  readonly property int runningCount: {
    var n = 0
    for (var i = 0; i < containers.length; i++)
      if (containers[i].state === "running") n++
    return n
  }

  Text {
    width: parent.width
    text: card.containers.length === 0
      ? "No containers"
      : card.runningCount + " running · " + card.containers.length + " total"
    color: card.fg
    font.family: card.fontName
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
  }

  Repeater {
    model: card.containers.slice(0, 3)
    Item {
      required property var modelData
      width: parent.width
      implicitHeight: nameText.implicitHeight

      Rectangle {
        id: dot
        width: Style.space(6)
        height: width
        radius: width / 2
        color: modelData.state === "running" ? card.fg : Qt.rgba(card.fg.r, card.fg.g, card.fg.b, 0.3)
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: nameText
        text: modelData.name
        textFormat: Text.PlainText
        color: card.fg
        opacity: modelData.state === "running" ? 0.85 : 0.5
        font.family: card.fontName
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        anchors.left: dot.right
        anchors.leftMargin: Style.space(8)
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
