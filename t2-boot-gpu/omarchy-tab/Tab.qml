import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// The Graphics tab of the T2 panel (t2.panel; t2-boot-gpu's, in place of
// KaiT2en's T2 Hybrid GPU Control window): which GPU the dual-GPU MacBook Pro
// boots on (Hybrid: the Intel iGPU drives the panel and the Radeon sleeps until
// an app asks for it; Discrete: the Radeon does everything, which external
// displays on the Thunderbolt ports need), what runs now, and whether the
// Radeon is awake. The `graphics` helper beside this file reads sysfs without
// waking the dGPU; switching asks for the admin password (pkexec t2-boot-gpu).
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

  readonly property string helper: String(Qt.resolvedUrl("graphics")).replace(/^file:\/\//, "")

  property var s: null
  property bool busy: false
  property string error: ""

  // Keyboard cursor: the boot GPU row.
  property bool cursorActive: false
  property int cursorIndex: 1
  readonly property bool ok: s !== null && !!s.available
  readonly property var modes: [{ value: "integrated", label: "Hybrid" }, { value: "discrete", label: "Discrete" }]

  function label(mode) { return mode === "integrated" ? "Hybrid" : mode === "discrete" ? "Discrete" : "–" }
  function shortName(name) { var p = String(name).split(" / "); return p.length > 1 ? "Radeon " + p[p.length - 1] : name }

  function refresh() { if (!statusProc.running) statusProc.running = true }

  function setMode(mode) {
    if (busy || !ok || mode === s.next) return
    busy = true
    error = ""
    actProc.command = [root.helper, "set", mode]
    actProc.running = true
  }

  function moveCursor(dy) { cursorActive = true }

  // ←/→ on the boot GPU row picks; elsewhere they switch the panel's tabs.
  function moveSideways(dx) {
    if (!(cursorActive && ok)) return false
    setMode(dx > 0 ? "discrete" : "integrated")
    return true
  }

  function activateCursor() { if (ok) setMode(s.next === "integrated" ? "discrete" : "integrated") }
  function textKey(t) { if (t === "r" || t === "R") refresh() }

  Component.onCompleted: refresh()

  Timer {
    interval: 3000
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
          root.s = JSON.parse(text)
        } catch (e) {
          root.error = "Couldn't read the GPUs' state"
        }
      }
    }
  }

  Process {
    id: actProc
    stderr: StdioCollector { id: actErr; waitForEnd: true }
    onExited: function(exitCode) {
      root.busy = false
      // 126/127: pkexec's dialog was dismissed or not authorized.
      if (exitCode === 126 || exitCode === 127) root.error = "Not changed: the password was cancelled"
      else if (exitCode !== 0) root.error = actErr.text.trim() !== "" ? actErr.text.trim() : "That didn't work"
      root.refresh()
    }
  }

  Column {
    id: column
    width: parent.width
    spacing: Style.space(12)

    PanelHero {
      width: parent.width
      title: "Graphics"
      meta: !root.ok ? "" : root.s.running === "integrated" ? "Hybrid: the Radeon sleeps until needed" : "Discrete: the Radeon does everything"
      foreground: root.foreground
      fontFamily: root.fontFamily
      iconComponent: Component {
        Text {
          text: "󰢮"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.display
        }
      }
    }

    Text {
      visible: root.error !== "" || (root.s !== null && !root.ok)
      width: parent.width
      text: root.error !== "" ? root.error : "Not a dual-GPU MacBook Pro, or t2-boot-gpu isn't installed"
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

      CursorSurface {
        width: column.width
        hasCursor: root.cursorActive && root.cursorIndex === 1
        foreground: root.foreground
        implicitHeight: modeRow.implicitHeight + Style.spacing.rowPaddingX

        HoverHandler { onHoveredChanged: if (hovered) root.cursorActive = true }

        RowLayout {
          id: modeRow
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(1)
            Text {
              text: "Boot on"
              textFormat: Text.PlainText
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }
            Text {
              Layout.fillWidth: true
              text: !root.ok ? "" : root.s.next !== root.s.running ? "From the next boot: " + root.label(root.s.next) : "Applies at the next boot; asks for your password"
              textFormat: Text.PlainText
              color: root.ok && root.s.next !== root.s.running ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }

          ButtonGroup {
            options: root.modes
            value: root.ok ? root.s.next : ""
            focusable: false
            enabled: !root.busy
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            cursorIndex: root.cursorActive && root.ok ? (root.s.next === "discrete" ? 1 : 0) : -1
            onChanged: function(v) { root.setMode(v) }
          }
        }
      }

      Item {
        width: column.width
        implicitHeight: gpuInfo.implicitHeight + Style.spacing.rowPaddingX

        RowLayout {
          id: gpuInfo
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)

          Text { text: "󰢮"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.icon }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(1)
            Text {
              Layout.fillWidth: true
              text: root.ok ? root.shortName(root.s.dgpu.name) : ""
              textFormat: Text.PlainText
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }
            Text {
              Layout.fillWidth: true
              text: !root.ok ? "" : root.s.running === "discrete" ? "Drives the panel"
                    : root.s.dgpu.awake ? "Awake: an app is using it" : "Asleep, powered off (" + root.s.dgpu.state + ")"
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }
        }
      }

      Text {
        width: parent.width
        leftPadding: Style.space(10)
        rightPadding: Style.space(10)
        text: "Hybrid saves the most power. External displays on the Thunderbolt ports need Discrete."
        textFormat: Text.PlainText
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }
  }
}
