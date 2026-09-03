import QtQuick
import qs.Commons
import "../Model.js" as Model

InfoCard {
  id: card
  title: "Calendar"
  glyph: "󰃭"
  summonId: "tmn73.calendar"

  property real nowMs: Date.now()
  readonly property var events: panelRoot
    ? Model.upcomingEvents(panelRoot.calendarDoc, nowMs, 3) : []
  readonly property string todayKey: Qt.formatDate(new Date(), "yyyy-MM-dd")

  // Keep countdown-ish labels honest while the panel sits open.
  Timer { interval: 30000; running: card.visible; repeat: true; onTriggered: card.nowMs = Date.now() }

  Text {
    width: parent.width
    visible: card.events.length === 0
    text: "No upcoming events"
    color: card.fg
    opacity: 0.6
    font.family: card.fontName
    font.pixelSize: Style.font.bodySmall
  }

  Repeater {
    model: card.events
    Item {
      required property var modelData
      width: parent.width
      implicitHeight: titleText.implicitHeight

      Text {
        id: whenText
        text: modelData.dateKey === card.todayKey
          ? Qt.formatTime(new Date(modelData.startMs), "HH:mm")
          : Qt.formatDateTime(new Date(modelData.startMs), "ddd HH:mm")
        color: card.fg
        opacity: 0.6
        font.family: card.fontName
        font.pixelSize: Style.font.caption
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: titleText
        text: modelData.title
        textFormat: Text.PlainText
        color: card.fg
        font.family: card.fontName
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        anchors.left: parent.left
        anchors.right: whenText.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
