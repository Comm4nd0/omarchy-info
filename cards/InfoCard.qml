import QtQuick
import qs.Commons

// Shared chrome for one control-center card: rounded tile, glyph + title
// header, optional "open the real popout" chevron. Card bodies land in the
// default `content` slot below the header.
Rectangle {
  id: card

  property var panelRoot: null   // the OmarchyInfo Panel root, injected by its Loader
  property string cardId: ""
  property string title: ""
  property string glyph: ""
  property string summonId: ""   // clicking the header summons this plugin's popout
  default property alias content: body.data

  readonly property var pbar: panelRoot ? panelRoot.bar : null
  readonly property color fg: pbar ? pbar.foreground : Color.foreground
  readonly property string fontName: pbar ? pbar.fontFamily : ""
  readonly property bool summonable: summonId !== "" && panelRoot !== null

  radius: Style.cornerRadius
  color: Qt.rgba(fg.r, fg.g, fg.b, headerMouse.containsMouse && summonable ? 0.1 : 0.06)
  implicitHeight: inner.implicitHeight + Style.space(24)

  Behavior on color { ColorAnimation { duration: 120 } }

  Column {
    id: inner
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(12)
    spacing: Style.space(8)

    Item {
      width: parent.width
      implicitHeight: Math.max(glyphText.implicitHeight, titleText.implicitHeight)

      Text {
        id: glyphText
        text: card.glyph
        color: card.fg
        font.family: card.fontName
        font.pixelSize: Style.font.title
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: titleText
        text: card.title
        color: card.fg
        font.family: card.fontName
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        font.letterSpacing: 0.8
        elide: Text.ElideRight
        anchors.left: glyphText.right
        anchors.leftMargin: Style.space(8)
        anchors.right: chevron.visible ? chevron.left : parent.right
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: chevron
        visible: card.summonable
        text: "›"   // ›
        color: card.fg
        opacity: headerMouse.containsMouse ? 1.0 : 0.45
        font.family: card.fontName
        font.pixelSize: Style.font.title
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
      }

      MouseArea {
        id: headerMouse
        anchors.fill: parent
        hoverEnabled: card.summonable
        cursorShape: card.summonable ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: card.summonable
        onClicked: card.panelRoot.summonPlugin(card.summonId)
      }
    }

    Column {
      id: body
      width: parent.width
      spacing: Style.space(6)
    }
  }
}
