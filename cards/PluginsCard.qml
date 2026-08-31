import QtQuick
import qs.Commons

InfoCard {
  id: card
  title: "Plugins"
  glyph: "󱓓"
  summonId: "omaplug"

  // Live registry counts; update checks stay in the plugin manager (they run
  // git fetches).
  readonly property var counts: {
    var reg = panelRoot && panelRoot.bar && panelRoot.bar.shell
      ? panelRoot.bar.shell.pluginRegistry : null
    if (!reg) return { total: 0, enabled: 0, thirdParty: 0 }
    reg.registryRevision
    var total = 0, enabled = 0, thirdParty = 0
    for (var id in reg.installedPlugins) {
      total++
      if (reg.installedPlugins[id].__isFirstParty !== true) thirdParty++
      if (reg.isEnabled(id)) enabled++
    }
    return { total: total, enabled: enabled, thirdParty: thirdParty }
  }

  Text {
    width: parent.width
    text: card.counts.total + " installed · " + card.counts.enabled + " enabled"
    color: card.fg
    font.family: card.fontName
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
  }

  Text {
    width: parent.width
    text: card.counts.thirdParty + " community, " + (card.counts.total - card.counts.thirdParty) + " built-in"
    color: card.fg
    opacity: 0.6
    font.family: card.fontName
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }
}
