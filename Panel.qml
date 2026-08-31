import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui
import "Model.js" as Model

// OmarchyInfo: one bar icon opening a control-center dropdown that aggregates
// what the rest of the bar knows — curated cards for the common data sources,
// plus a row per remaining bar plugin that summons its real popout.
//
// The Panel base supplies the IPC target, so
//   omarchy-shell shell toggle marco.omarchy-info
// is bindable to a key with nothing extra here.
Panel {
  id: root
  moduleName: "marco.omarchy-info"
  ipcTarget: "marco.omarchy-info"

  // ---------------------------------------------------------------- settings
  readonly property int refreshMs: Math.max(1, Number(setting("refreshIntervalSec", 3))) * 1000
  readonly property bool showOtherPlugins: setting("showOtherPlugins", true) === true
  readonly property int panelWidthPx: Math.max(380, Number(setting("panelWidthPx", 560)))
  readonly property int gridColumns: Math.max(1, Math.min(3, Number(setting("columns", 2))))
  readonly property string layoutMode: setting("layoutMode", "masonry") === "grid" ? "grid" : "masonry"

  // In-panel settings editor, toggled by the gear in the header.
  property bool settingsOpen: false

  // Merge changed values into this widget's inline shell.json entry. Applied
  // locally first so the panel redraws on the click itself; the write comes
  // back through the bar as the same value (inline settings changes patch
  // running widgets in place, so the open panel survives).
  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]
    root.settings = entry
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(root.moduleName, entry)
  }

  // ------------------------------------------------------------ capabilities
  readonly property bool hasBattery: {
    var d = UPower.displayDevice
    return !!(d && d.isPresent)
  }
  property bool dockerAvailable: true

  readonly property var enabledCards: Model.effectiveCards(setting("cards", []), {
    hasBattery: root.hasBattery,
    hasDocker: root.dockerAvailable
  })

  // ------------------------------------------------------------ shared state
  property var stats: ({ cpu: -1, ram: null, disks: [] })
  property var netInfo: ({})
  property var containers: []
  property string weatherStatus: ""
  property real weatherFetchedMs: 0
  property var agents: []
  property var layouts: []
  property var calendarDoc: ({})
  property var toggleStates: ({})

  readonly property var mediaService: bar && bar.shell
    ? bar.shell.firstPartyServiceFor("omarchy.media") : null

  readonly property bool hasDockerVmsPlugin: {
    var reg = bar && bar.shell ? bar.shell.pluginRegistry : null
    if (!reg) return false
    reg.registryRevision
    return !!reg.installedPlugins["io.github.dicemans.docker-vms"]
      && reg.isEnabled("io.github.dicemans.docker-vms")
  }

  // Rows for bar plugins we don't already cover with a card. Restricted to
  // widgets actually placed in the bar AND exposing the popout contract
  // (open/close/opened) — a row that summons nothing is just noise. Slot
  // state only settles after load, so this is recomputed on each open
  // rather than bound.
  property var otherPlugins: []

  function computeOtherPlugins() {
    var reg = bar && bar.shell ? bar.shell.pluginRegistry : null
    if (!reg || !bar) return []
    var rows = Model.otherPluginRows(reg.installedPlugins, root.enabledCards,
      root.moduleName, function(id) { return reg.inBar(id) })
    var out = []
    for (var i = 0; i < rows.length; i++) {
      // Visibility guard: widgets like omarchy.power keep the popout contract
      // but hide themselves when their hardware is absent — summoning those
      // is a dead click.
      var w = bar.findPanelWidget(rows[i].id)
      if (w && w.visible !== false) out.push(rows[i])
    }
    return out
  }

  function summonPlugin(id) {
    if (bar && bar.shell) bar.shell.summon(id, "{}")
  }

  // ----------------------------------------------------------------- polling
  // Same idiom as docker-vms: resolve helpers relative to the plugin dir so a
  // clone or rename keeps working without touching $PATH.
  readonly property string statsHelperPath: {
    var url = String(Qt.resolvedUrl("bin/omarchy-info-stats"))
    return url.indexOf("file://") === 0 ? url.substring(7) : url
  }

  Process {
    id: statsProc
    command: [root.statsHelperPath]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.stats = Model.parseStats(text) }
  }

  Process {
    id: netProc
    command: ["omarchy-network-status", "--verbose"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var next = Model.parseKeyValue(text)
        // Keep last known good data across transient empty samples.
        if (Object.keys(next).length > 0) root.netInfo = next
        else if (text.trim() === "") root.netInfo = {}
      }
    }
  }

  Process {
    id: dockerProc
    command: ["docker", "ps", "-a", "--format", "{{.Names}}\t{{.State}}\t{{.Status}}"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.containers = Model.parseDockerPs(text) }
    onExited: function(code) { root.dockerAvailable = code === 0 }
  }

  // Weather goes out to the network via omarchy's own helper, so it gets a
  // stale-guard instead of the regular poll cadence.
  Process {
    id: weatherProc
    command: ["omarchy-weather-status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var line = text.trim()
        if (line !== "") { root.weatherStatus = line; root.weatherFetchedMs = Date.now() }
      }
    }
  }

  Process {
    id: agentsProc
    command: ["bash", "-c",
      'for f in "$HOME"/.local/state/omarchy/agents/usage/*.json; do [ -f "$f" ] || continue; echo "===REC"; cat "$f"; done']
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.agents = Model.agentRows(Model.parseDelimitedJson(text))
    }
  }

  Process {
    id: layoutsProc
    command: ["bash", "-c",
      'for f in "$HOME"/.config/omarchy/workspace-restorer/*.json; do [ -f "$f" ] || continue; printf "===PROFILE\\t%s\\t%s\\n" "$(basename "$f" .json)" "$(stat -c %Y "$f")"; cat "$f"; echo; done']
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.layouts = Model.parseProfiles(text) }
  }

  // Quick-settings probe for the toggles the shell has no live service for:
  // omarchy's "-off" flag files, plus input-device presence/disable state.
  // Key/value lines, same shape as the network probe.
  Process {
    id: togglesProc
    command: ["bash", "-c",
      'T="$HOME/.local/state/omarchy/toggles"\n' +
      'for f in screensaver-off suspend-off crash-capture-off; do\n' +
      '  if [ -f "$T/$f" ]; then v=1; else v=0; fi\n' +
      '  printf "%s\\t%s\\n" "$f" "$v"\n' +
      'done\n' +
      'for k in touchpad touchscreen; do\n' +
      '  if n="$("omarchy-hw-$k" 2>/dev/null)" && [ -n "$n" ]; then p=1; else p=0; fi\n' +
      '  printf "%s-present\\t%s\\n" "$k" "$p"\n' +
      '  if [ -f "$T/hypr/$k-disabled-name" ]; then d=1; else d=0; fi\n' +
      '  printf "%s-disabled\\t%s\\n" "$k" "$d"\n' +
      'done']
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.toggleStates = Model.parseKeyValue(text) }
  }

  function refreshToggles() {
    if (!togglesProc.running) togglesProc.running = true
  }

  // The calendar sync timer rewrites this file every few minutes; watching it
  // is free and needs no polling at all.
  FileView {
    path: (Quickshell.env("HOME") || "") + "/.local/state/omarchy/calendar-events.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.applyCalendar(text())
    onFileChanged: reload()
    onLoadFailed: root.calendarDoc = {}
  }

  function applyCalendar(text) {
    try { root.calendarDoc = JSON.parse(text) || {} }
    catch (e) { root.calendarDoc = {} }
  }

  // Whether the user's selection asks for the docker card at all (before the
  // availability probe). Polled on this rather than enabledCards so a stopped
  // daemon coming back re-surfaces the card without a shell restart.
  readonly property bool wantsDocker: {
    var sel = setting("cards", [])
    return !Array.isArray(sel) || sel.length === 0 || sel.indexOf("docker") !== -1
  }

  function refresh() {
    var cards = root.enabledCards
    if (cards.indexOf("stats") !== -1 && !statsProc.running) statsProc.running = true
    if (cards.indexOf("network") !== -1 && !netProc.running) netProc.running = true
    if (cards.indexOf("settings") !== -1) refreshToggles()
    if (root.wantsDocker && !dockerProc.running) dockerProc.running = true
  }

  // Local file reads for cards whose sources change slowly. Weather only
  // refetches when the last result has gone stale (it hits the network);
  // pass force=true (the "r" key) to override.
  function refreshSlow(force) {
    var cards = root.enabledCards
    if (cards.indexOf("agents") !== -1 && !agentsProc.running) agentsProc.running = true
    if (cards.indexOf("layouts") !== -1 && !layoutsProc.running) layoutsProc.running = true
    var weatherStale = Date.now() - root.weatherFetchedMs > 5 * 60 * 1000
    if (cards.indexOf("weather") !== -1 && (force || weatherStale) && !weatherProc.running)
      weatherProc.running = true
  }

  Timer {
    interval: root.refreshMs
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    interval: 60 * 1000
    running: root.opened
    repeat: true
    onTriggered: root.refreshSlow(false)
  }

  onOpenedChanged: {
    if (opened) { refresh(); refreshSlow(false); otherPlugins = computeOtherPlugins() }
    else settingsOpen = false
  }
  // Card availability can change while open (e.g. the docker probe failing
  // right after the first refresh) — keep the row list in sync so a plugin
  // whose card just vanished reappears as a row.
  onEnabledCardsChanged: if (opened) otherPlugins = computeOtherPlugins()

  // --------------------------------------------------------------- bar icon
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰋼"
    tooltipText: "OmarchyInfo"
    onPressed: function(b) { root.toggle() }
  }

  // ---------------------------------------------------------------- dropdown
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(root.panelWidthPx))
    contentHeight: panel.fittedContentHeight(layoutColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.settingsOpen ? root.settingsOpen = false : root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r") { root.refresh(); root.refreshSlow(true) }
        else if (t === "s") root.settingsOpen = !root.settingsOpen
      }

      Column {
        id: layoutColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        // Header: title on the left, the gear that flips between the cards
        // and the panel's own settings editor on the right.
        Item {
          width: parent.width
          implicitHeight: Math.max(headerTitle.implicitHeight, gearButton.implicitHeight)

          PanelSectionHeader {
            id: headerTitle
            text: root.settingsOpen ? "PANEL SETTINGS" : "OMARCHY INFO"
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.bar ? root.bar.fontFamily : ""
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            id: gearButton
            text: root.settingsOpen ? "󰅖" : "󰒓"
            color: root.bar ? root.bar.foreground : Color.foreground
            opacity: gearMouse.containsMouse || root.settingsOpen ? 1.0 : 0.5
            font.family: root.bar ? root.bar.fontFamily : ""
            font.pixelSize: Style.font.bodySmall
            anchors.right: parent.right
            anchors.rightMargin: Style.space(2)
            anchors.verticalCenter: parent.verticalCenter

            Behavior on opacity { NumberAnimation { duration: 120 } }

            MouseArea {
              id: gearMouse
              anchors.fill: parent
              anchors.margins: -Style.space(6)
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.settingsOpen = !root.settingsOpen
            }
          }
        }

        // Card area: manual placement so masonry can close the vertical gaps
        // a row-aligned grid leaves under short cards. The math lives in
        // Model.js (masonryLayout/gridLayout); this item only assigns x/y and
        // re-runs the layout when anything that affects it moves.
        Item {
          id: cardArea
          width: parent.width
          visible: !root.settingsOpen

          readonly property real gutter: Style.space(10)
          readonly property real cellWidth:
            (width - gutter * (root.gridColumns - 1)) / root.gridColumns

          onWidthChanged: scheduleLayout()

          function scheduleLayout() { layoutTimer.restart() }

          function relayout() {
            var items = []
            for (var i = 0; i < children.length; i++) {
              var it = children[i]
              if (it && it.isCardCell === true && it.height > 0) items.push(it)
            }
            var heights = []
            for (var j = 0; j < items.length; j++) heights.push(items[j].height)
            var res = root.layoutMode === "grid"
              ? Model.gridLayout(heights, root.gridColumns, gutter)
              : Model.masonryLayout(heights, root.gridColumns, gutter)
            for (var k = 0; k < items.length; k++) {
              items[k].x = res.positions[k].column * (cellWidth + gutter)
              items[k].y = res.positions[k].y
            }
            implicitHeight = res.height
          }

          Timer { id: layoutTimer; interval: 0; onTriggered: cardArea.relayout() }

          Connections {
            target: root
            function onGridColumnsChanged() { cardArea.scheduleLayout() }
            function onLayoutModeChanged() { cardArea.scheduleLayout() }
          }

          Repeater {
            model: root.enabledCards
            onItemAdded: function(index, item) { cardArea.scheduleLayout() }
            onItemRemoved: function(index, item) { cardArea.scheduleLayout() }
            Loader {
              required property var modelData
              readonly property bool isCardCell: true
              width: cardArea.cellWidth
              height: item ? item.implicitHeight : 0
              source: Model.cardSource(modelData)
              onHeightChanged: cardArea.scheduleLayout()
              onLoaded: {
                item.panelRoot = root
                item.cardId = modelData
              }
            }
          }
        }

        Loader {
          width: parent.width
          active: root.settingsOpen
          visible: root.settingsOpen
          source: "SettingsView.qml"
          onLoaded: item.panelRoot = root
        }

        PanelSeparator {
          visible: !root.settingsOpen && root.showOtherPlugins && root.otherPlugins.length > 0
          foreground: root.bar ? root.bar.foreground : Color.foreground
        }

        PanelSectionHeader {
          visible: !root.settingsOpen && root.showOtherPlugins && root.otherPlugins.length > 0
          text: "OTHER PLUGINS"
          foreground: root.bar ? root.bar.foreground : Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : ""
        }

        Column {
          width: parent.width
          spacing: Style.space(2)
          visible: !root.settingsOpen && root.showOtherPlugins

          Repeater {
            model: root.otherPlugins
            Rectangle {
              id: pluginRow
              required property var modelData
              width: parent.width
              implicitHeight: rowName.implicitHeight + Style.space(12)
              radius: Style.cornerRadius
              color: rowMouse.containsMouse
                ? Qt.rgba(rowFg.r, rowFg.g, rowFg.b, 0.08)
                : "transparent"

              readonly property color rowFg: root.bar ? root.bar.foreground : Color.foreground

              Text {
                id: rowName
                text: pluginRow.modelData.displayName
                color: pluginRow.rowFg
                font.family: root.bar ? root.bar.fontFamily : ""
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
                anchors.left: parent.left
                anchors.leftMargin: Style.space(8)
                anchors.right: rowCategory.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: rowCategory
                text: pluginRow.modelData.category !== ""
                  ? pluginRow.modelData.category + "  ›" : "›"
                color: pluginRow.rowFg
                opacity: rowMouse.containsMouse ? 0.9 : 0.45
                font.family: root.bar ? root.bar.fontFamily : ""
                font.pixelSize: Style.font.caption
                anchors.right: parent.right
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
              }

              MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.summonPlugin(pluginRow.modelData.id)
              }
            }
          }
        }
      }
    }
  }
}
