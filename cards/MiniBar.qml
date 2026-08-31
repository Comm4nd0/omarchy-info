import QtQuick
import qs.Commons

// Labeled mini progress bar: "LABEL         value" above a thin track.
Column {
  id: root

  property string label: ""
  property string valueText: ""
  property real fraction: 0   // 0..1
  property color fg: Color.foreground
  property string fontName: ""

  width: parent ? parent.width : implicitWidth
  spacing: Style.space(3)

  Item {
    width: parent.width
    implicitHeight: labelText.implicitHeight

    Text {
      id: labelText
      text: root.label
      color: root.fg
      opacity: 0.6
      font.family: root.fontName
      font.pixelSize: Style.font.caption
      font.letterSpacing: 0.8
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      text: root.valueText
      color: root.fg
      font.family: root.fontName
      font.pixelSize: Style.font.caption
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  Item {
    width: parent.width
    implicitHeight: Style.space(5)

    Rectangle {
      id: track
      anchors.fill: parent
      radius: height / 2
      color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
    }

    Rectangle {
      anchors.left: track.left
      anchors.verticalCenter: track.verticalCenter
      height: track.height
      radius: track.radius
      color: root.fg
      width: Math.max(track.height, track.width * Math.max(0, Math.min(1, root.fraction)))

      Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    }
  }
}
