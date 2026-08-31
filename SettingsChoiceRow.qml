import QtQuick
import qs.Commons

// Label on the left, a segmented set of choices on the right. Stateless:
// bind `current`, act on `picked(value)`.
Item {
  id: row

  property string label: ""
  property var options: []   // [{ value, label }]
  property var current: null
  property color fg: Color.foreground
  property string fontName: ""

  signal picked(var value)

  implicitHeight: segments.implicitHeight

  Text {
    text: row.label
    color: row.fg
    font.family: row.fontName
    font.pixelSize: Style.font.caption
    anchors.left: parent.left
    anchors.leftMargin: Style.space(4)
    anchors.verticalCenter: parent.verticalCenter
  }

  Row {
    id: segments
    spacing: Style.space(4)
    anchors.right: parent.right
    anchors.rightMargin: Style.space(2)
    anchors.verticalCenter: parent.verticalCenter

    Repeater {
      model: row.options
      Rectangle {
        id: segment
        required property var modelData
        readonly property bool selected: segment.modelData.value === row.current
        implicitWidth: Math.max(segLabel.implicitWidth + Style.space(16), Style.space(34))
        implicitHeight: segLabel.implicitHeight + Style.space(8)
        radius: Style.cornerRadius
        color: Qt.rgba(row.fg.r, row.fg.g, row.fg.b,
          selected ? 0.18 : (segMouse.containsMouse ? 0.10 : 0.05))

        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
          id: segLabel
          text: segment.modelData.label
          color: row.fg
          opacity: segment.selected ? 1.0 : 0.65
          font.family: row.fontName
          font.pixelSize: Style.font.caption
          anchors.centerIn: parent
        }

        MouseArea {
          id: segMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: row.picked(segment.modelData.value)
        }
      }
    }
  }
}
