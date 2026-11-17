import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// The T2 Mac's one place on the bar (t2-omarchy-plugins): a tab for each T2
// feature whose package is installed (Mac: battery, power, fans; Ambient Light;
// AirShare; Sidecar; ...), each package's tab loaded from
// /usr/share/t2-omarchy/tabs/<id>/Tab.qml while the panel is open. The icon
// carries a dot while AirShare is visible or Sidecar streams (a tab's
// indicator unit running); right-click opens on that tab. The `t2hub` helper
// beside this file lists the tabs and the active indicators.
//
// A tab is an Item that takes bar, foreground, urgent, dim, fontFamily and
// opened (the panel is open: its timers run only then), sets its
// implicitHeight, and may offer refresh() (called whenever the panel opens),
// moveCursor(dy), moveSideways(dx) (true when it used the keys),
// activateCursor(), textKey(t), a closeRequested() signal, `locked` (true while
// it mustn't be switched away from, e.g. during a transfer) and `editing`
// (true while a text field of its has the keyboard).
Panel {
  id: root
  moduleName: "t2.panel"
  ipcTarget: "t2.panel"
  manageIpc: false

  readonly property string helper: String(Qt.resolvedUrl("t2hub")).replace(/^file:\/\//, "")

  property var tabs: []
  property string tabsJson: ""
  property var active: []
  property string currentId: ""
  readonly property int currentIndex: Math.max(0, tabs.findIndex(function(t) { return t.id === currentId }))
  readonly property var currentTab: tabs.length ? tabs[currentIndex] : null

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property color accent: Commons.Color.accent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  visible: tabs.length > 0
  implicitWidth: tabs.length > 0 ? button.implicitWidth : 0
  implicitHeight: button.implicitHeight

  function refresh() { if (!statusProc.running) statusProc.running = true }

  function select(id) {
    if (!tabs.some(function(t) { return t.id === id }) || id === currentId) return
    currentId = id
    rememberProc.command = [root.helper, "remember", id]
    rememberProc.running = true
  }

  function selectIndex(i) {
    if (tabs.length) select(tabs[(i + tabs.length) % tabs.length].id)
  }

  // Number keys: 1..n, nothing past the last tab.
  function selectNumber(n) {
    if (n >= 1 && n <= tabs.length) select(tabs[n - 1].id)
  }

  onOpenedChanged: if (opened) {
    refresh()
    Qt.callLater(function() { if (panel.loadedContent) panel.loadedContent.forceActiveFocus() })
  }

  Component.onCompleted: refresh()

  Timer {
    interval: root.opened ? 3000 : 15000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    command: [root.helper, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var s = JSON.parse(text)
          // Only when they change: a new array rebuilds the tab row.
          var j = JSON.stringify(s.tabs)
          if (j !== root.tabsJson) { root.tabsJson = j; root.tabs = s.tabs }
          if (JSON.stringify(s.active) !== JSON.stringify(root.active)) root.active = s.active
          if (!root.tabs.some(function(t) { return t.id === root.currentId }))
            root.currentId = root.tabs.some(function(t) { return t.id === s.last }) ? s.last : (root.tabs.length ? root.tabs[0].id : "")
        } catch (e) {}
      }
    }
  }

  Process { id: rememberProc }

  ShellIpc {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
    function tab(id: string): string { root.select(id); root.open(); return "ok" }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰻠"
    foreground: root.barForeground
    tooltipText: "T2" + (root.active.length ? ": " + root.active.map(function(a) { return a.text }).join(" · ") : "")
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton && root.active.length) { root.select(root.active[0].id); root.open() }
      else root.toggle()
    }

    // AirShare visible, Sidecar streaming: worth seeing without opening.
    Rectangle {
      visible: root.active.length > 0
      width: Math.max(5, Math.round(button.height * 0.2))
      height: width
      radius: width / 2
      color: root.accent
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.rightMargin: Math.round(button.width * 0.18)
      anchors.topMargin: Math.round(button.height * 0.18)
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(640))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(620))

    content: PanelKeyCatcher {
      implicitHeight: column.implicitHeight
      anchors.fill: parent
      readonly property var tab: tabLoader.item
      readonly property bool locked: !!(tab && tab.locked)
      // A tab's text field gets every key while it has the keyboard.
      blocked: !!(tab && tab.editing)
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) { if (tab && tab.moveCursor) tab.moveCursor(dy) }
        else if (!(tab && tab.moveSideways && tab.moveSideways(dx)) && !locked) root.selectIndex(root.currentIndex + dx)
      }
      onActivateRequested: if (tab && tab.activateCursor) tab.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (/^[1-9]$/.test(t)) { if (!locked) root.selectNumber(parseInt(t)) }
        else if (tab && tab.textKey) tab.textKey(t)
      }

      // The panel keeps the tab loaded while closed: fresh values on opening.
      Connections {
        target: root
        function onOpenedChanged() { if (root.opened && tabLoader.item && tabLoader.item.refresh) tabLoader.item.refresh() }
      }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        ButtonGroup {
          visible: root.tabs.length > 1
          anchors.horizontalCenter: parent.horizontalCenter
          options: root.tabs.map(function(t, i) { return { value: t.id, label: t.title, tooltip: t.title + " (" + (i + 1) + ")" } })
          value: root.currentId
          focusable: false
          enabled: !locked
          foreground: root.foreground
          fontFamily: root.fontFamily
          fontSize: Style.font.bodySmall
          onChanged: function(v) { root.select(v) }
        }

        Loader {
          id: tabLoader
          width: parent.width
          source: root.currentTab ? "file://" + root.currentTab.dir + "/Tab.qml" : ""
          onLoaded: {
            item.width = Qt.binding(function() { return tabLoader.width })
            if (item.opened !== undefined) item.opened = Qt.binding(function() { return root.opened })
            if (item.closeRequested) item.closeRequested.connect(root.close)
            item.bar = Qt.binding(function() { return root.bar })
            item.foreground = Qt.binding(function() { return root.foreground })
            item.urgent = Qt.binding(function() { return root.urgent })
            item.dim = Qt.binding(function() { return root.dim })
            item.fontFamily = Qt.binding(function() { return root.fontFamily })
          }
        }

        Text {
          visible: tabLoader.status === Loader.Error
          width: parent.width
          text: "This tab didn't load (journalctl --user -t omarchy-shell)"
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
