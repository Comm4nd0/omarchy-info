import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../Model.js" as Model

// Quick settings: the control-center toggle grid. Night light, stay-awake and
// do-not-disturb ride the shell's first-party services so their switches move
// live even when the toggle happens elsewhere (bar indicator, keybinding);
// the rest are omarchy flag-file toggles fed by the Panel's probe.
InfoCard {
  id: card
  title: "Settings"
  glyph: "󰒓"

  readonly property var shell: pbar ? pbar.shell : null
  readonly property var nightlightService: shell ? shell.firstPartyServiceFor("omarchy.nightlight") : null
  readonly property var idleService: shell ? shell.firstPartyServiceFor("omarchy.idle") : null
  readonly property var notificationService: shell ? shell.firstPartyServiceFor("omarchy.notifications") : null

  readonly property var liveRows: {
    var rows = []
    if (nightlightService)
      rows.push({ key: "nightlight", label: "Night light", glyph: "󰔎",
        checked: nightlightService.enabled === true })
    if (idleService)
      rows.push({ key: "stay-awake", label: "Stay awake", glyph: "󰅶",
        checked: idleService.stayAwake === true })
    if (notificationService)
      rows.push({ key: "dnd", label: "Do not disturb", glyph: "󰂛",
        checked: notificationService.doNotDisturb === true })
    return rows
  }

  readonly property var rows: liveRows.concat(
    Model.flagToggleRows(panelRoot ? panelRoot.toggleStates : {}))

  Process {
    id: toggleProc
    stdout: StdioCollector { waitForEnd: true }
    // Re-probe as soon as the toggle lands so the switch settles on real
    // state instead of waiting out the poll interval.
    onExited: if (card.panelRoot) card.panelRoot.refreshToggles()
  }

  function activate(row) {
    switch (row.key) {
      case "nightlight":
        nightlightService.setNightlight(!nightlightService.enabled)
        return
      case "stay-awake":
        // Mirrors the bar indicator: setIdleEnabled(true) means allow idle.
        idleService.setIdleEnabled(idleService.stayAwake)
        return
      case "dnd":
        notificationService.setDoNotDisturb(!notificationService.doNotDisturb)
        return
    }
    if (toggleProc.running || !row.cmd) return
    toggleProc.command = row.cmd
    toggleProc.running = true
  }

  Repeater {
    model: card.rows
    Rectangle {
      id: toggleRow
      required property var modelData
      width: parent.width
      implicitHeight: Math.max(rowLabel.implicitHeight, rowSwitch.implicitHeight) + Style.space(4)
      radius: Style.cornerRadius
      color: rowMouse.containsMouse
        ? Qt.rgba(card.fg.r, card.fg.g, card.fg.b, 0.08)
        : "transparent"

      Text {
        id: rowGlyph
        text: toggleRow.modelData.glyph
        color: card.fg
        opacity: toggleRow.modelData.checked ? 1.0 : 0.55
        font.family: card.fontName
        font.pixelSize: Style.font.bodySmall
        anchors.left: parent.left
        anchors.leftMargin: Style.space(4)
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: rowLabel
        text: toggleRow.modelData.label
        color: card.fg
        opacity: toggleRow.modelData.checked ? 1.0 : 0.7
        font.family: card.fontName
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
        anchors.left: rowGlyph.right
        anchors.leftMargin: Style.space(8)
        anchors.right: rowSwitch.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
      }

      ToggleSwitch {
        id: rowSwitch
        checked: toggleRow.modelData.checked
        interactive: false
        cursorRing: false
        trackHeight: 16
        foreground: card.fg
        anchors.right: parent.right
        anchors.rightMargin: Style.space(4)
        anchors.verticalCenter: parent.verticalCenter
      }

      MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.activate(toggleRow.modelData)
      }
    }
  }

  // Theme actions: not toggles, but the setting changes people reach for
  // most. The switcher is another shell overlay, so close this panel first.
  Row {
    width: parent.width
    spacing: Style.space(6)

    readonly property real cellWidth: (width - spacing) / 2

    Repeater {
      model: [
        { label: "󰸌  Theme", action: "switcher" },
        { label: "  Next bg", action: "bg-next" }
      ]
      Rectangle {
        id: actionButton
        required property var modelData
        width: parent.cellWidth
        implicitHeight: actionLabel.implicitHeight + Style.space(10)
        radius: Style.cornerRadius
        color: Qt.rgba(card.fg.r, card.fg.g, card.fg.b, actionMouse.containsMouse ? 0.14 : 0.07)

        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
          id: actionLabel
          text: actionButton.modelData.label
          color: card.fg
          font.family: card.fontName
          font.pixelSize: Style.font.caption
          anchors.centerIn: parent
        }

        MouseArea {
          id: actionMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (actionButton.modelData.action === "switcher") {
              if (card.panelRoot) card.panelRoot.close()
              Quickshell.execDetached(["bash", "-c",
                'theme=$(omarchy-theme-switcher); [[ -n $theme ]] && omarchy-theme-set "$theme"'])
            } else {
              Quickshell.execDetached(["omarchy-theme-bg-next"])
            }
          }
        }
      }
    }
  }
}
