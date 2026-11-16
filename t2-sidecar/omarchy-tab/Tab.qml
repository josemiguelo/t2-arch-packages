import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// The Sidecar tab of the T2 panel (t2.panel; the t2-sidecar package): a phone, tablet or computer
// as a second screen, or a view of this one, through Moonlight, encoded by the
// T2's Sidecar encoder. The icon is lit while it streams; the panel has the
// switch, the mode (an extended display right of the others, or the built-in
// display mirrored), the extended display's size, whether a device is watching,
// and Sunshine's PIN page for pairing a new one. The `sidecar` helper beside
// this file reads the state and runs t2-sidecar. Hidden without t2-sidecar.
Item {
  id: root
  // Set by the T2 hub (t2.panel), which shows this tab.
  property var bar: null
  property color foreground: Commons.Color.foreground
  property color urgent: Commons.Color.urgent
  property color dim: Qt.darker(foreground, 1.55)
  property string fontFamily: Style.font.family
  readonly property bool opened: true
  signal closeRequested()
  implicitHeight: column.implicitHeight

  function textKey(t) {
        if (t === "m" || t === "M") root.setMode(root.extended ? "mirror" : "extend")
        else if (t === "p" || t === "P") root.pair()
        else if (t === "r" || t === "R") root.refresh()
  }

  readonly property string helper: String(Qt.resolvedUrl("sidecar")).replace(/^file:\/\//, "")

  property bool installed: false
  property bool running: false
  property string mode: "extend"
  property string size: "1920x1080"
  property var sizes: ["1280x800", "1920x1080", "2560x1600"]
  property bool encoder: true
  property bool t2Ave: true
  property bool client: false
  property bool busy: false
  property string error: ""

  // Keyboard cursor over the panel's rows: the switch, the mode, the size
  // (extended only), pairing.
  property bool cursorActive: false
  property int cursorIndex: 0
  readonly property bool extended: mode === "extend"
  readonly property var rows: extended ? [0, 1, 2, 3] : [0, 1, 3]

  readonly property bool encoderOk: encoder && t2Ave

  function refresh() { if (!statusProc.running) statusProc.running = true }

  function act(args) {
    if (busy) return
    busy = true
    error = ""
    actProc.command = [root.helper].concat(args)
    actProc.running = true
  }

  function setRunning(on) { running = on; act([on ? "on" : "off"]) }
  function setMode(m) { if (m !== mode) { mode = m; act(["mode", m]) } }
  function setSize(s) { if (s !== size) { size = s; act(["size", s]) } }
  function pair() { act(["pair"]) }

  function sizeLabel(s) { return s.replace("x", "×") }

  // The header's status line is short (it's set in capitals and elides); the
  // bar icon's tooltip says what is shown as well.
  function state() {
    if (!encoderOk) return "Encoder off"
    if (!running) return "Off"
    return client ? "Streaming" : "Waiting for Moonlight"
  }

  function summary() {
    var what = extended ? "extended display, " + sizeLabel(size) : "built-in display mirrored"
    return state() + " · " + what
  }

  function moveCursor(dy) {
    if (!cursorActive) { cursorActive = true; return }
    var i = Math.max(0, rows.indexOf(cursorIndex))
    cursorIndex = rows[Math.max(0, Math.min(rows.length - 1, i + dy))]
  }

  // ←/→ on the mode or size row picks; elsewhere they switch the hub's tabs.
  function moveSideways(dx) {
    if (!cursorActive) return false
    if (cursorIndex === 1) { setMode(dx > 0 ? "mirror" : "extend"); return true }
    if (cursorIndex === 2) {
      var i = sizes.indexOf(size)
      setSize(sizes[Math.max(0, Math.min(sizes.length - 1, i + dx))])
      return true
    }
    return false
  }

  function activateCursor() {
    if (cursorIndex === 0) setRunning(!running)
    else if (cursorIndex === 1) setMode(extended ? "mirror" : "extend")
    else if (cursorIndex === 3) pair()
  }

  Component.onCompleted: refresh()

  // Whether a device is watching while the panel is open; the switch otherwise.
  Timer {
    interval: 2000
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
            root.mode = s.mode
            root.size = s.size
          }
          root.sizes = s.sizes
          root.encoder = !!s.encoder
          root.t2Ave = !!s.t2Ave
          root.client = !!s.client
        } catch (e) {
          root.error = "Couldn't read t2-sidecar's state"
        }
      }
    }
  }

  Process {
    id: actProc
    onExited: function(exitCode) {
      root.busy = false
      if (exitCode !== 0) root.error = "That didn't work (t2-sidecar; journalctl --user -u t2-sidecar)"
      root.refresh()
    }
  }

  // A row with a label and a pick-one group of chips.
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
        title: "Sidecar"
        meta: root.state()
        foreground: root.foreground
        fontFamily: root.fontFamily
        iconOpacity: root.running ? 1.0 : 0.5
        iconComponent: Component {
          Text {
            text: "󰍺"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
          }
        }
        trailingControl: Component {
          ToggleSwitch {
            id: streamSwitch
            checked: root.running
            busy: root.busy
            hasCursor: header.ringVisible
            foreground: hero.foreground
            onHovered: function(on) { if (on) { root.cursorActive = true; root.cursorIndex = 0 } }
            onToggled: root.setRunning(!root.running)

            PanelToolTip {
              visible: streamSwitch.containsMouse
              text: root.running ? "Stop streaming" : "Stream to Moonlight"
              fontFamily: hero.fontFamily
            }
          }
        }
      }
    }

    Text {
      visible: root.error !== "" || !root.encoderOk
      width: parent.width
      text: root.error !== "" ? root.error
            : "The T2's encoder needs t2-ave: sudo systemctl enable --now t2-ave.service t2-ave-suspend.service"
      textFormat: Text.PlainText
      color: root.urgent
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
    }

    Column {
      width: parent.width
      spacing: Style.space(6)

      PanelSectionHeader {
        text: "Screen"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      ChoiceRow {
        width: column.width
        rowIndex: 1
        label: "Show (m)"
        options: [{ value: "extend", label: "Extended" }, { value: "mirror", label: "Mirror" }]
        value: root.mode
        onPicked: function(v) { root.setMode(v) }
      }

      ChoiceRow {
        visible: root.extended
        width: column.width
        rowIndex: 2
        label: "Size"
        options: root.sizes.map(function(s) { return { value: s, label: root.sizeLabel(s) } })
        value: root.size
        onPicked: function(v) { root.setSize(v) }
      }

      Text {
        width: parent.width
        leftPadding: Style.space(10)
        rightPadding: Style.space(10)
        text: root.extended
              ? "A screen right of this one; match the size in Moonlight. Move windows there with Super+Shift+→."
              : "What the built-in display shows."
        textFormat: Text.PlainText
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }

    PanelSeparator { foreground: root.foreground }

    CursorSurface {
      width: parent.width
      hasCursor: root.cursorActive && root.cursorIndex === 3
      foreground: root.foreground
      implicitHeight: pairRow.implicitHeight + Style.spacing.rowPaddingX

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: { root.cursorActive = true; root.cursorIndex = 3 }
        onClicked: root.pair()
      }

      RowLayout {
        id: pairRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        spacing: Style.space(8)

        Text {
          text: "󰌷"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.icon
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.space(1)

          Text {
            Layout.fillWidth: true
            text: "Pair a device (p)"
            textFormat: Text.PlainText
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
          }

          Text {
            Layout.fillWidth: true
            text: root.running ? "Tap the Mac in Moonlight, enter its PIN"
                               : "Turn Sidecar on, then tap the Mac in Moonlight"
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }
      }
    }
  }

  component ChoiceRow: CursorSurface {
    id: row
    property int rowIndex: 0
    property string label: ""
    property var options: []
    property string value: ""
    signal picked(string value)

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
