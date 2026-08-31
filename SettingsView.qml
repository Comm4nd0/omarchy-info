import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// In-panel settings editor, opened from the gear in the panel header. Every
// change applies immediately and persists to this widget's inline entry in
// shell.json via panelRoot.persistSettings().
Column {
  id: view

  property var panelRoot: null

  readonly property var pbar: panelRoot ? panelRoot.bar : null
  readonly property color fg: pbar ? pbar.foreground : Color.foreground
  readonly property string fontName: pbar ? pbar.fontFamily : ""

  spacing: Style.space(10)

  // ------------------------------------------------------------------- cards
  PanelSectionHeader {
    text: "CARDS"
    foreground: view.fg
    fontFamily: view.fontName
  }

  Grid {
    width: parent.width
    columns: 2
    columnSpacing: Style.space(10)
    rowSpacing: Style.space(2)

    readonly property real cellWidth: (width - columnSpacing) / 2

    Repeater {
      model: Model.CARD_OPTIONS
      Rectangle {
        id: cardRow
        required property var modelData
        width: parent.cellWidth
        implicitHeight: cardLabel.implicitHeight + Style.space(8)
        radius: Style.cornerRadius
        color: cardMouse.containsMouse
          ? Qt.rgba(view.fg.r, view.fg.g, view.fg.b, 0.08)
          : "transparent"

        readonly property bool shown:
          Model.cardShown(view.panelRoot ? view.panelRoot.setting("cards", []) : [], modelData.id)

        Text {
          id: cardGlyph
          text: cardRow.modelData.glyph
          color: view.fg
          opacity: cardRow.shown ? 1.0 : 0.45
          font.family: view.fontName
          font.pixelSize: Style.font.bodySmall
          anchors.left: parent.left
          anchors.leftMargin: Style.space(4)
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          id: cardLabel
          text: cardRow.modelData.label
          color: view.fg
          opacity: cardRow.shown ? 1.0 : 0.6
          font.family: view.fontName
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          anchors.left: cardGlyph.right
          anchors.leftMargin: Style.space(8)
          anchors.right: cardSwitch.left
          anchors.rightMargin: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter
        }

        ToggleSwitch {
          id: cardSwitch
          checked: cardRow.shown
          interactive: false
          cursorRing: false
          trackHeight: 14
          foreground: view.fg
          anchors.right: parent.right
          anchors.rightMargin: Style.space(2)
          anchors.verticalCenter: parent.verticalCenter
        }

        MouseArea {
          id: cardMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: view.panelRoot.persistSettings({
            cards: Model.toggleCardSelection(view.panelRoot.setting("cards", []), cardRow.modelData.id)
          })
        }
      }
    }
  }

  // ------------------------------------------------------------------ layout
  PanelSectionHeader {
    text: "LAYOUT"
    foreground: view.fg
    fontFamily: view.fontName
  }

  SettingsChoiceRow {
    width: parent.width
    label: "Style"
    options: [
      { value: "masonry", label: "Masonry" },
      { value: "grid", label: "Grid" }
    ]
    current: view.panelRoot ? view.panelRoot.layoutMode : "masonry"
    fg: view.fg
    fontName: view.fontName
    onPicked: function(value) { view.panelRoot.persistSettings({ layoutMode: value }) }
  }

  SettingsChoiceRow {
    width: parent.width
    label: "Columns"
    options: [
      { value: 1, label: "1" },
      { value: 2, label: "2" },
      { value: 3, label: "3" }
    ]
    current: view.panelRoot ? view.panelRoot.gridColumns : 2
    fg: view.fg
    fontName: view.fontName
    onPicked: function(value) { view.panelRoot.persistSettings({ columns: value }) }
  }

  Item {
    width: parent.width
    implicitHeight: widthSlider.implicitHeight

    Text {
      id: widthLabel
      text: "Width"
      color: view.fg
      font.family: view.fontName
      font.pixelSize: Style.font.caption
      anchors.left: parent.left
      anchors.leftMargin: Style.space(4)
      anchors.verticalCenter: parent.verticalCenter
    }

    PanelSlider {
      id: widthSlider
      bar: view.pbar
      anchors.left: widthLabel.right
      anchors.leftMargin: Style.space(10)
      anchors.right: widthValue.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      minimum: 380
      maximum: 900
      step: 20
      value: view.panelRoot ? view.panelRoot.panelWidthPx : 560
      onMoved: function(v) { view.panelRoot.persistSettings({ panelWidthPx: Math.round(v) }) }
    }

    Text {
      id: widthValue
      text: (view.panelRoot ? view.panelRoot.panelWidthPx : 560) + "px"
      color: view.fg
      opacity: 0.6
      font.family: view.fontName
      font.pixelSize: Style.font.caption
      anchors.right: parent.right
      anchors.rightMargin: Style.space(4)
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  // ---------------------------------------------------------------- behavior
  Rectangle {
    id: pluginsRow
    width: parent.width
    implicitHeight: pluginsLabel.implicitHeight + Style.space(8)
    radius: Style.cornerRadius
    color: pluginsMouse.containsMouse
      ? Qt.rgba(view.fg.r, view.fg.g, view.fg.b, 0.08)
      : "transparent"

    readonly property bool on: view.panelRoot ? view.panelRoot.showOtherPlugins : true

    Text {
      id: pluginsLabel
      text: "List other bar plugins below the cards"
      color: view.fg
      opacity: pluginsRow.on ? 1.0 : 0.6
      font.family: view.fontName
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
      anchors.left: parent.left
      anchors.leftMargin: Style.space(4)
      anchors.right: pluginsSwitch.left
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
    }

    ToggleSwitch {
      id: pluginsSwitch
      checked: pluginsRow.on
      interactive: false
      cursorRing: false
      trackHeight: 14
      foreground: view.fg
      anchors.right: parent.right
      anchors.rightMargin: Style.space(2)
      anchors.verticalCenter: parent.verticalCenter
    }

    MouseArea {
      id: pluginsMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: view.panelRoot.persistSettings({ showOtherPlugins: !pluginsRow.on })
    }
  }
}
