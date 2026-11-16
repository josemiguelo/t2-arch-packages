import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// T2 TrueTone in the bar (the t2-truetone package): the screen's white point
// and brightness follow the room's light, from the T2 Mac's ambient light
// sensor. The icon is lit while the daemon runs; the panel ("Ambient Light",
// so its switch isn't confused with True Tone's) has the daemon's switch,
// True Tone with its strength, automatic brightness (it learns from the
// brightness keys) and what the sensor sees. The `truetone` helper beside
// this file reads the daemon's state and writes its settings. Hidden where
// t2-truetone isn't installed.
Panel {
  id: root
  moduleName: "josemiguelo.truetone"
  ipcTarget: "josemiguelo.truetone"
  manageIpc: false

  readonly property string helper: String(Qt.resolvedUrl("truetone")).replace(/^file:\/\//, "")

  property bool installed: false
  property bool running: false
  property bool trueTone: true
  property bool autoBrightness: true
  property real strength: 0.2
  property bool learned: false
  property var live: null
  property bool busy: false
  // The strength slider is in the panel's lazily loaded content: its drag is
  // mirrored here so a refresh doesn't move the knob under the finger.
  property bool strengthDragging: false
  property string error: ""

  // Keyboard cursor over the panel's rows: the daemon switch, True Tone,
  // strength, automatic brightness, forgetting what it learned.
  property bool cursorActive: false
  property int cursorIndex: 0
  readonly property int rowCount: learned ? 5 : 4

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool active: running && (trueTone || autoBrightness)
  readonly property color barIconColor: active ? barForeground : Qt.darker(barForeground, 1.55)
  readonly property bool liveOk: running && live !== null && live.fresh && live.sensor

  visible: installed
  implicitWidth: installed ? button.implicitWidth : 0
  implicitHeight: button.implicitHeight

  function refresh() { if (!statusProc.running) statusProc.running = true }

  function run(args) {
    if (busy) return
    busy = true
    actProc.command = [root.helper].concat(args)
    actProc.running = true
  }

  function setService(on) { running = on; run(["service", on ? "on" : "off"]) }
  function setTrueTone(on) { trueTone = on; run(["set", "true_tone", on ? "on" : "off"]) }
  function setAuto(on) { autoBrightness = on; run(["set", "auto_brightness", on ? "on" : "off"]) }
  function setStrength(v) {
    strength = Math.round(Math.max(0, Math.min(0.3, v)) * 100) / 100
    run(["set", "strength", String(strength)])
  }

  function kelvin(k) { return k > 0 ? Math.round(k / 50) * 50 + " K" : "–" }

  function liveSummary() {
    if (!running) return "Off: colour and brightness stay as set"
    if (live === null || !live.fresh) return "Starting…"
    if (live.error) return live.error
    if (!live.sensor) return "No light sensor reading yet"
    return Math.round(live.lux) + " lux · light " + kelvin(live.ambient_cct)
  }

  function moveCursor(dy) {
    if (!cursorActive) { cursorActive = true; return }
    cursorIndex = Math.max(0, Math.min(rowCount - 1, cursorIndex + dy))
  }

  function moveSideways(dx) {
    if (cursorActive && cursorIndex === 2) setStrength(strength + dx * 0.05)
  }

  function activateCursor() {
    if (cursorIndex === 0) setService(!running)
    else if (cursorIndex === 1) setTrueTone(!trueTone)
    else if (cursorIndex === 3) setAuto(!autoBrightness)
    else if (cursorIndex === 4) run(["forget-brightness"])
  }

  onOpenedChanged: if (opened) {
    cursorActive = false
    cursorIndex = 0
    refresh()
    Qt.callLater(function() { if (panel.loadedContent) panel.loadedContent.forceActiveFocus() })
  }

  Component.onCompleted: refresh()

  // Live numbers while the panel is open; the switch state otherwise.
  Timer {
    interval: root.opened ? 1000 : 15000
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
          root.installed = !!s.installed
          if (!root.busy) {
            root.running = !!s.running
            root.trueTone = !!s.trueTone
            root.autoBrightness = !!s.autoBrightness
            if (!root.strengthDragging) root.strength = s.strength
          }
          root.learned = !!s.learned
          root.live = s.live
          root.error = ""
        } catch (e) {
          root.error = "Couldn't read t2-truetone's state"
        }
      }
    }
  }

  Process {
    id: actProc
    onExited: function(exitCode) {
      root.busy = false
      if (exitCode !== 0) root.error = "That didn't work (t2-truetone)"
      root.refresh()
    }
  }

  ShellIpc {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
    function service(on: string): string { root.setService(on === "on" || on === "true"); return "ok" }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰃡"
    foreground: root.barIconColor
    tooltipText: root.running ? "Ambient light: " + root.liveSummary() : "Ambient light: off"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.setService(!root.running)
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(480))

    content: PanelKeyCatcher {
      implicitHeight: column.implicitHeight
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { if (dy !== 0) root.moveCursor(dy); else root.moveSideways(dx) }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "t" || t === "T") root.setTrueTone(!root.trueTone)
        else if (t === "a" || t === "A") root.setAuto(!root.autoBrightness)
        else if (t === "r" || t === "R") root.refresh()
      }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        Item {
          id: header
          width: parent.width
          implicitHeight: hero.implicitHeight
          readonly property bool ringVisible: root.cursorActive && root.cursorIndex === 0

          PanelHero {
            id: hero
            width: parent.width
            title: "Ambient Light"
            meta: root.liveSummary()
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: root.active ? 1.0 : 0.5
            iconComponent: Component {
              Text {
                text: "󰃡"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
            trailingControl: Component {
              ToggleSwitch {
                id: serviceSwitch
                checked: root.running
                busy: root.busy
                hasCursor: header.ringVisible
                foreground: hero.foreground
                onHovered: function(on) { if (on) { root.cursorActive = true; root.cursorIndex = 0 } }
                onToggled: root.setService(!root.running)

                PanelToolTip {
                  visible: serviceSwitch.containsMouse
                  text: root.running ? "Stop using the light sensor" : "Use the light sensor"
                  fontFamily: hero.fontFamily
                }
              }
            }
          }
        }

        Text {
          visible: root.error !== ""
          width: parent.width
          text: root.error
          textFormat: Text.PlainText
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Column {
          width: parent.width
          spacing: Style.space(6)
          enabled: root.running
          opacity: root.running ? 1.0 : 0.5

          PanelSectionHeader {
            text: "Colour"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          SwitchRow {
            width: column.width
            rowIndex: 1
            icon: "󰖨"
            label: "True Tone"
            detail: root.liveOk && root.trueTone ? "Screen white " + root.kelvin(root.live.white_cct) + " (t)" : "White follows the room (t)"
            checked: root.trueTone
            onToggled: root.setTrueTone(!root.trueTone)
          }

          CursorSurface {
            width: column.width
            hasCursor: root.cursorActive && root.cursorIndex === 2
            foreground: root.foreground
            implicitHeight: strengthRow.implicitHeight + Style.spacing.rowPaddingX
            enabled: root.trueTone
            opacity: root.trueTone ? 1.0 : 0.5

            HoverHandler { onHoveredChanged: if (hovered) { root.cursorActive = true; root.cursorIndex = 2 } }

            RowLayout {
              id: strengthRow
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              spacing: Style.space(8)

              Text {
                text: "Strength"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }

              PanelSlider {
                id: strengthSlider
                bar: root.bar
                Layout.fillWidth: true
                minimum: 0
                maximum: 0.3
                step: 0.05
                value: root.strength
                onDraggingChanged: root.strengthDragging = dragging
                onReleased: function(v) { root.setStrength(v) }
              }

              Text {
                text: Math.round((strengthSlider.dragging ? strengthSlider.liveValue : root.strength) / 0.3 * 100) + "%"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                Layout.preferredWidth: Style.space(34)
                horizontalAlignment: Text.AlignRight
              }
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        Column {
          width: parent.width
          spacing: Style.space(6)
          enabled: root.running
          opacity: root.running ? 1.0 : 0.5

          PanelSectionHeader {
            text: "Brightness"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          SwitchRow {
            width: column.width
            rowIndex: 3
            icon: "󰃠"
            label: "Automatic brightness"
            detail: root.liveOk && root.live.brightness !== null && root.live.brightness !== undefined
                    ? "Now " + Math.round(root.live.brightness * 100) + "%, learns from your keys (a)"
                    : "Learns from your brightness keys (a)"
            checked: root.autoBrightness
            onToggled: root.setAuto(!root.autoBrightness)
          }

          CursorSurface {
            visible: root.learned
            width: column.width
            hasCursor: root.cursorActive && root.cursorIndex === 4
            foreground: root.foreground
            implicitHeight: forgetText.implicitHeight + Style.spacing.rowPaddingX

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: { root.cursorActive = true; root.cursorIndex = 4 }
              onClicked: root.run(["forget-brightness"])
            }

            Text {
              id: forgetText
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(10)
              text: "Forget what it learned"
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }
          }
        }
      }
    }
  }

  // A row with an icon, a label and detail, and a switch at the end.
  component SwitchRow: CursorSurface {
    id: row
    property int rowIndex: 0
    property string icon: ""
    property string label: ""
    property string detail: ""
    property bool checked: false
    signal toggled()

    hasCursor: root.cursorActive && root.cursorIndex === rowIndex
    foreground: root.foreground
    implicitHeight: rowContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: { root.cursorActive = true; root.cursorIndex = row.rowIndex }
      onClicked: row.toggled()
    }

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        text: row.icon
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        id: rowContent
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          Layout.fillWidth: true
          text: row.label
          textFormat: Text.PlainText
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          text: row.detail
          textFormat: Text.PlainText
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      ToggleSwitch {
        checked: row.checked
        busy: root.busy
        interactive: false
        foreground: root.foreground
        Layout.alignment: Qt.AlignVCenter
      }
    }
  }
}
