import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// The Battery tab of the T2 panel (t2.panel; t2-smc-control's, for KaiT2en's
// SMC Control window): the battery as the T2 SMC reports it (charge, watts,
// time left, health, the charge limit), the system's power draw, and the SMC
// clock when it drifts. The `battery` helper beside this file reads t2smc's
// hwmon (world-readable).
Item {
  id: root
  // Set by the T2 panel (t2.panel), which shows this tab.
  property var bar: null
  property color foreground: Commons.Color.foreground
  property color urgent: Commons.Color.urgent
  property color dim: Qt.darker(foreground, 1.55)
  property string fontFamily: Style.font.family
  property bool opened: true   // the panel is open (set by it)
  signal closeRequested()
  implicitHeight: column.implicitHeight

  readonly property string helper: String(Qt.resolvedUrl("battery")).replace(/^file:\/\//, "")

  property var s: null
  property bool busy: false
  property string error: ""

  // Keyboard cursor: the clock sync, when it shows.
  property bool cursorActive: false
  property int cursorIndex: 3
  readonly property bool installed: s !== null && !!s.installed
  readonly property bool clockOff: installed && s.clockOffset !== null && Math.abs(s.clockOffset) > 5

  function refresh() { if (!statusProc.running) statusProc.running = true }

  function act(args) {
    if (busy) return
    busy = true
    error = ""
    actProc.command = [root.helper].concat(args)
    actProc.running = true
  }

  function duration(h) {
    if (h === null || h === undefined) return ""
    var m = Math.round(h * 60)
    return m >= 60 ? Math.floor(m / 60) + " h " + (m % 60) + " min" : m + " min"
  }

  function batteryLine() {
    if (!installed) return ""
    var b = s.battery
    var t = b.percent + "%"
    if (b.status === "Discharging") return t + (b.hours ? " · " + duration(b.hours) + " left" : "")
    if (b.status === "Charging") return t + " · charging" + (b.hours ? ", " + duration(b.hours) + " to the limit" : "")
    return t + (s.adapter.online ? " · on power" : "")
  }

  function limitLine() {
    if (!installed || s.limit.value === null) return ""
    if (s.limit.suspended) return "Lifted for a calibration charge (to 100%)"
    if (s.limit.value >= 100) return "None"
    return "Charging stops near " + (s.limit.value - 5) + "%"
  }

  function deg(v) { return v === null || v === undefined ? "–" : v + "°" }

  function moveCursor(dy) { if (clockOff) cursorActive = true }
  function activateCursor() { if (clockOff && cursorIndex === 3) act(["sync-clock"]) }
  function textKey(t) { if (t === "r" || t === "R") refresh() }

  Component.onCompleted: refresh()

  Timer {
    interval: 2000
    running: root.opened
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
          var st = JSON.parse(text)
          root.s = st
          if (st.installed) root.error = ""
        } catch (e) {
          root.error = "Couldn't read the T2 SMC"
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

  // A read-only row: an icon, a label with detail under it, a value at the end.

  Column {
    id: column
    width: parent.width
    spacing: Style.space(12)

    PanelHero {
      width: parent.width
      title: "Battery"
      meta: root.installed ? (root.s.battery.status === "Discharging" ? "On battery" : root.s.adapter.online ? "On power" : "Battery") : ""
      foreground: root.foreground
      fontFamily: root.fontFamily
      iconComponent: Component {
        Text {
          text: "󰁹"
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
      visible: root.installed

      

      InfoRow {
        icon: root.s && root.s.battery.status === "Charging" ? "󰂄" : "󰁹"
        label: root.batteryLine()
        value: root.s ? (root.s.battery.watts > 0 ? "+" : "") + root.s.battery.watts + " W" : ""
      }
      InfoRow {
        icon: "󰂃"
        label: "Charge limit"
        detail: root.limitLine()
        value: root.s && root.s.limit.value !== null ? root.s.limit.value + "%" : ""
      }
      InfoRow {
        icon: "󱊣"
        label: "Health"
        detail: root.s && root.s.battery.cycles !== null ? root.s.battery.cycles + " charge cycles" : ""
        value: root.s && root.s.battery.health !== null ? root.s.battery.health + "%" : ""
      }
      InfoRow {
        icon: "󱐋"
        label: "Power draw"
        detail: root.s && root.s.power.cpu !== null ? "Processor " + root.s.power.cpu + " W" : ""
        value: root.s && root.s.power.system !== null ? root.s.power.system + " W" : ""
      }
    }

    CursorSurface {
      visible: root.clockOff
      width: parent.width
      hasCursor: root.cursorActive && root.cursorIndex === 3
      foreground: root.foreground
      implicitHeight: clockText.implicitHeight + Style.spacing.rowPaddingX

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: { root.cursorActive = true; root.cursorIndex = 3 }
        onClicked: root.act(["sync-clock"])
      }

      Text {
        id: clockText
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(10)
        text: root.clockOff ? "The SMC's clock is " + Math.abs(root.s.clockOffset) + " s off: sync it (asks for your password)" : ""
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
      }
    }
  }

  component InfoRow: Item {
    id: info
    property string icon: ""
    property string label: ""
    property string detail: ""
    property string value: ""
    width: column.width
    implicitHeight: infoContent.implicitHeight + Style.spacing.rowPaddingX

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text { text: info.icon; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.icon }

      ColumnLayout {
        id: infoContent
        Layout.fillWidth: true
        spacing: Style.space(1)
        Text {
          Layout.fillWidth: true
          text: info.label
          textFormat: Text.PlainText
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }
        Text {
          visible: info.detail !== ""
          Layout.fillWidth: true
          text: info.detail
          textFormat: Text.PlainText
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      Text {
        visible: info.value !== ""
        text: info.value
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }
    }
  }
}

