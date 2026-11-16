import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// The Trackpad tab of the T2 panel (t2.panel; t2-force-click's, for KaiT2en's
// Force Click window): the click's pressure, force click (on or off, how hard),
// and the action a force click runs (copy and paste in turn, a key combo, a
// command). The `trackpad` helper beside this file talks to t2-force-click's
// daemon, which applies the settings and keeps them across boots.
Item {
  id: root
  // Set by the T2 panel (t2.panel), which shows this tab.
  property var bar: null
  property color foreground: Commons.Color.foreground
  property color urgent: Commons.Color.urgent
  property color dim: Qt.darker(foreground, 1.55)
  property string fontFamily: Style.font.family
  signal closeRequested()
  implicitHeight: column.implicitHeight

  readonly property string helper: String(Qt.resolvedUrl("trackpad")).replace(/^file:\/\//, "")

  property var s: null
  property bool busy: false
  property bool thresholdDragging: false
  property real threshold: 200
  property string error: ""

  // Keyboard cursor: click, force click, its pressure, the action, its text.
  property bool cursorActive: false
  property int cursorIndex: 1
  readonly property bool ok: s !== null && !!s.available
  readonly property bool force: ok && s.force
  readonly property string action: ok ? s.action : "none"
  readonly property bool hasText: action === "key_combo" || action === "command"
  readonly property var rows: [1, 2].concat(force ? [3, 4] : []).concat(force && hasText ? [5] : [])
  readonly property var clicks: [{ value: "0", label: "Light" }, { value: "1", label: "Medium" }, { value: "2", label: "Firm" }]
  readonly property var actions: [
    { value: "none", label: "Nothing" },
    { value: "copy_paste", label: "Copy / paste" },
    { value: "key_combo", label: "Keys" },
    { value: "command", label: "Command" }
  ]

  function refresh() { if (!statusProc.running) statusProc.running = true }

  function set(key, value) {
    if (busy) return
    busy = true
    error = ""
    actProc.command = [root.helper, "set", key, String(value)]
    actProc.running = true
  }

  function setThreshold(v) { threshold = Math.round(Math.max(120, Math.min(300, v)) / 10) * 10; set("threshold", threshold) }

  function pick(list, current, dx) {
    var i = list.findIndex(function(o) { return o.value === current })
    return list[Math.max(0, Math.min(list.length - 1, i + dx))].value
  }

  function moveCursor(dy) {
    if (!cursorActive) { cursorActive = true; return }
    var i = Math.max(0, rows.indexOf(cursorIndex))
    cursorIndex = rows[Math.max(0, Math.min(rows.length - 1, i + dy))]
  }

  // ←/→ on the click, pressure or action row picks; elsewhere they switch tabs.
  function moveSideways(dx) {
    if (!cursorActive || !ok) return false
    if (cursorIndex === 1) { set("click", pick(clicks, String(s.click), dx)); return true }
    if (cursorIndex === 3) { setThreshold(threshold + dx * 10); return true }
    if (cursorIndex === 4) { set("action", pick(actions, action, dx)); return true }
    return false
  }

  function activateCursor() {
    if (!ok) return
    if (cursorIndex === 2) set("force", force ? "off" : "on")
    else if (cursorIndex === 5) textField.forceActiveFocus()
  }

  function textKey(t) { if (t === "r" || t === "R") refresh() }

  Component.onCompleted: refresh()

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: if (!textField.activeFocus) root.refresh()
  }

  Process {
    id: statusProc
    command: [root.helper, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var st = JSON.parse(text)
          root.s = st
          if (!st.available) root.error = st.error
          if (st.available && !root.busy && !root.thresholdDragging) root.threshold = st.threshold
          if (st.available && !textField.activeFocus)
            textField.text = st.action === "command" ? st.command : st.combo
        } catch (e) {
          root.error = "Couldn't read Force Click's state"
        }
      }
    }
  }

  Process {
    id: actProc
    stderr: StdioCollector { id: actErr; waitForEnd: true }
    onExited: function(exitCode) {
      root.busy = false
      if (exitCode !== 0) root.error = actErr.text.trim() !== "" ? actErr.text.trim() : "That didn't work"
      root.refresh()
    }
  }

  Column {
    id: column
    width: parent.width
    spacing: Style.space(12)

    PanelHero {
      width: parent.width
      title: "Trackpad"
      meta: !root.ok ? "" : !root.s.driver ? "Driver not loaded" : !root.s.device ? "Trackpad not found" : root.force ? "Force click on" : "Force click off"
      foreground: root.foreground
      fontFamily: root.fontFamily
      iconComponent: Component {
        Text {
          text: "󰟸"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.display
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
      visible: root.ok

      ChoiceRow {
        rowIndex: 1
        label: "Click"
        options: root.clicks
        value: root.ok ? String(root.s.click) : "1"
        onPicked: function(v) { root.set("click", v) }
      }

      CursorSurface {
        width: column.width
        hasCursor: root.cursorActive && root.cursorIndex === 2
        foreground: root.foreground
        implicitHeight: forceRow.implicitHeight + Style.spacing.rowPaddingX

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: { root.cursorActive = true; root.cursorIndex = 2 }
          onClicked: root.set("force", root.force ? "off" : "on")
        }

        RowLayout {
          id: forceRow
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)

          Text { text: "󰳽"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.icon }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(1)
            Text {
              Layout.fillWidth: true
              text: "Force click"
              textFormat: Text.PlainText
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }
            Text {
              Layout.fillWidth: true
              text: root.force ? "Press harder for a second click" : "Off: only the plain click"
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }

          ToggleSwitch {
            checked: root.force
            busy: root.busy
            interactive: false
            foreground: root.foreground
            Layout.alignment: Qt.AlignVCenter
          }
        }
      }

      CursorSurface {
        visible: root.force
        width: column.width
        hasCursor: root.cursorActive && root.cursorIndex === 3
        foreground: root.foreground
        implicitHeight: pressureRow.implicitHeight + Style.spacing.rowPaddingX

        HoverHandler { onHoveredChanged: if (hovered) { root.cursorActive = true; root.cursorIndex = 3 } }

        RowLayout {
          id: pressureRow
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)

          Text { text: "Pressure"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }

          PanelSlider {
            id: pressureSlider
            bar: root.bar
            Layout.fillWidth: true
            minimum: 120
            maximum: 300
            step: 10
            value: root.threshold
            onDraggingChanged: root.thresholdDragging = dragging
            onReleased: function(v) { root.setThreshold(v) }
          }

          Text {
            text: (Math.round(pressureSlider.dragging ? pressureSlider.liveValue : root.threshold) / 100).toFixed(1) + "×"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            Layout.preferredWidth: Style.space(34)
            horizontalAlignment: Text.AlignRight
          }
        }
      }

      ChoiceRow {
        visible: root.force
        rowIndex: 4
        label: "On force click"
        options: root.actions
        value: root.action
        onPicked: function(v) { root.set("action", v) }
      }

      CursorSurface {
        visible: root.force && root.hasText
        width: column.width
        hasCursor: root.cursorActive && root.cursorIndex === 5
        foreground: root.foreground
        implicitHeight: textCol.implicitHeight + Style.spacing.rowPaddingX

        HoverHandler { onHoveredChanged: if (hovered) { root.cursorActive = true; root.cursorIndex = 5 } }

        ColumnLayout {
          id: textCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(4)

          TextField {
            id: textField
            Layout.fillWidth: true
            placeholderText: root.action === "command" ? "A command, e.g. omarchy-launch-browser" : "Keys, e.g. leftctrl+leftalt+t"
            foreground: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            onAccepted: { root.set(root.action === "command" ? "command" : "combo", text); focus = false }
            Keys.onEscapePressed: function(event) { focus = false; root.refresh(); event.accepted = true }
          }

          Text {
            Layout.fillWidth: true
            text: root.action === "command" ? "Runs as you on a force click. Enter saves, Esc cancels."
                                            : "Evdev key names joined with +, held together then released. Enter saves."
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }

  // A row with a label and a pick-one group of chips.
  component ChoiceRow: CursorSurface {
    id: row
    property int rowIndex: 0
    property string label: ""
    property var options: []
    property string value: ""
    signal picked(string value)

    width: column.width
    hasCursor: root.cursorActive && root.cursorIndex === rowIndex
    foreground: root.foreground
    implicitHeight: choiceLayout.implicitHeight + Style.spacing.rowPaddingX

    HoverHandler { onHoveredChanged: if (hovered) { root.cursorActive = true; root.cursorIndex = row.rowIndex } }

    RowLayout {
      id: choiceLayout
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        text: row.label
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        Layout.fillWidth: true
      }

      ButtonGroup {
        options: row.options
        value: row.value
        focusable: false
        foreground: root.foreground
        fontFamily: root.fontFamily
        fontSize: Style.font.bodySmall
        cursorIndex: row.hasCursor ? Math.max(0, row.options.findIndex(function(o) { return o.value === row.value })) : -1
        onChanged: function(v) { row.picked(v) }
      }
    }
  }
}
