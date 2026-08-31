import QtQuick
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

InfoCard {
  id: card
  title: "Audio"
  summonId: "omarchy.audio"

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property real vol: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

  glyph: muted ? "󰝟" : (vol > 0.5 ? "󰕾" : (vol > 0 ? "󰖀" : "󰕿"))

  PwObjectTracker { objects: card.sink ? [card.sink] : [] }

  Text {
    width: parent.width
    text: card.sink ? (card.sink.description || card.sink.name || "Output") : "No output device"
    color: card.fg
    opacity: 0.75
    font.family: card.fontName
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }

  Item {
    width: parent.width
    implicitHeight: slider.implicitHeight

    PanelSlider {
      id: slider
      bar: card.pbar
      anchors.left: parent.left
      anchors.right: pctText.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      minimum: 0
      maximum: 1
      step: 0.05
      value: card.vol
      opacity: card.muted ? 0.5 : 1.0
      enabled: !!card.sink

      onMoved: function(v) {
        if (card.sink && card.sink.audio) {
          card.sink.audio.muted = false
          card.sink.audio.volume = v
        }
      }
      onRightClicked: {
        if (card.sink && card.sink.audio) card.sink.audio.muted = !card.sink.audio.muted
      }
    }

    Text {
      id: pctText
      text: card.muted ? "MUTE" : Math.round(card.vol * 100) + "%"
      color: card.fg
      font.family: card.fontName
      font.pixelSize: Style.font.caption
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
    }
  }
}
