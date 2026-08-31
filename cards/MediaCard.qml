import QtQuick
import qs.Commons
import qs.Ui

InfoCard {
  id: card
  title: "Now playing"
  summonId: "omarchy.audio"

  // First-party media service (panel root resolves it once per bar injection).
  readonly property var svc: panelRoot ? panelRoot.mediaService : null
  readonly property bool hasMedia: !!(svc && svc.hasMedia)
  readonly property var player: svc ? svc.activePlayer : null
  readonly property bool playing: !!(player && player.isPlaying)

  glyph: playing ? "󰐊" : "󰝚"

  Item {
    width: parent.width
    implicitHeight: Math.max(labels.implicitHeight, playButton.implicitHeight)

    Column {
      id: labels
      anchors.left: parent.left
      anchors.right: playButton.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        width: parent.width
        text: card.hasMedia ? (card.svc.title || "Unknown title") : "Nothing playing"
        color: card.fg
        font.family: card.fontName
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        visible: card.hasMedia && card.svc.artist !== ""
        text: card.hasMedia ? card.svc.artist : ""
        color: card.fg
        opacity: 0.6
        font.family: card.fontName
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    Button {
      id: playButton
      visible: !!(card.player && card.player.canTogglePlaying)
      iconText: card.playing ? "󰏤" : "󰐊"
      iconSize: Style.font.title
      foreground: card.fg
      fontFamily: card.fontName
      bordered: true
      horizontalPadding: Style.spacing.controlPaddingX
      verticalPadding: Style.spacing.controlPaddingY
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      onClicked: if (card.player && card.player.canTogglePlaying) card.player.togglePlaying()
    }
  }
}
