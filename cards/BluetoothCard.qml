import QtQuick
import Quickshell.Bluetooth
import qs.Commons

InfoCard {
  id: card
  title: "Bluetooth"
  summonId: "omarchy.bluetooth"

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
  readonly property var connectedDevices: {
    var out = []
    for (var i = 0; i < devices.length; i++)
      if (devices[i] && devices[i].connected) out.push(devices[i])
    return out
  }
  readonly property bool on: !!(adapter && adapter.enabled)

  glyph: !adapter ? "󰂲" : (!on ? "󰂲" : (connectedDevices.length > 0 ? "󰂱" : "󰂯"))

  Text {
    width: parent.width
    text: !card.adapter ? "No adapter"
      : !card.on ? "Turned off"
      : card.connectedDevices.length === 0 ? "On · nothing connected"
      : card.connectedDevices.length + " connected"
    color: card.fg
    font.family: card.fontName
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
  }

  Text {
    width: parent.width
    visible: card.connectedDevices.length > 0
    text: {
      var names = []
      for (var i = 0; i < Math.min(3, card.connectedDevices.length); i++)
        names.push(card.connectedDevices[i].name || card.connectedDevices[i].address)
      return names.join(", ")
    }
    color: card.fg
    opacity: 0.6
    font.family: card.fontName
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }
}
