import QtQuick
import Quickshell.Services.UPower
import qs.Commons

InfoCard {
  id: card
  title: "Battery"
  summonId: "omarchy.power"

  readonly property var device: UPower.displayDevice
  readonly property bool present: !!(device && device.isPresent)
  readonly property real fraction: present && isFinite(device.percentage) ? device.percentage : 0
  readonly property bool discharging: present && UPower.onBattery
  readonly property bool full: present && device.state === UPowerDeviceState.FullyCharged

  glyph: !present ? "󰂑"
    : full ? "󰁹"
    : discharging
      ? (fraction > 0.8 ? "󰂂" : fraction > 0.6 ? "󰂀" : fraction > 0.4 ? "󰁾" : fraction > 0.2 ? "󰁼" : "󰁺")
      : "󰂄"

  readonly property string stateLabel: !present ? "No battery"
    : full ? "Fully charged"
    : discharging ? "On battery" : "Charging"

  MiniBar {
    label: card.stateLabel.toUpperCase()
    valueText: card.present ? Math.round(card.fraction * 100) + "%" : "—"
    fraction: card.fraction
    fg: card.fg
    fontName: card.fontName
  }
}
