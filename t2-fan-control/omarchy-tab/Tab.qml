import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// The Fans tab of the T2 panel (t2.panel; t2-fan-control's, for KaiT2en's Fan
// Control window): the custom curve or the SMC's own control, the temperature
// the curve cools to, both fans' speed, and the main temperatures. The `fans`
// helper beside this file talks to t2-fan-control's daemon (it takes changes
// from the active session's user only) and reads t2smc's temperatures.
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

  readonly property string helper: String(Qt.resolvedUrl("fans")).replace(/^file:\/\//, "")

  property var s: null
  property bool busy: false
  property bool targetDragging: false
  property real target: 80
  property string error: ""

  // Keyboard cursor: the fan curve switch, the target slider.
  property bool cursorActive: false
  property int cursorIndex: 1
  readonly property bool installed: s !== null
  readonly property var fans: installed ? s.fans : null
  readonly property bool fansOk: fans !== null && !!fans.available
  readonly property var rows: [1, 2]

  function refresh() { if (!statusProc.running) statusProc.running = true }

  function act(args) {
    if (busy) return
    busy = true
    error = ""
    actProc.command = [root.helper].concat(args)
    actProc.running = true
  }

  function setAuto(on) { act(["auto", on ? "on" : "off"]) }
  function setTarget(t) { target = Math.round(Math.max(50, Math.min(100, t)) / 5) * 5; act(["target", String(target)]) }
  function deg(v) { return v === null || v === undefined ? "–" : v + "°" }

  function moveCursor(dy) {
    if (!cursorActive) { cursorActive = true; return }
    cursorIndex = Math.max(1, Math.min(2, cursorIndex + dy))
  }

  // ←/→ on the "Cool to" row moves it; elsewhere they switch the panel's tabs.
  function moveSideways(dx) {
    if (!(cursorActive && cursorIndex === 2 && fansOk && fans.auto)) return false
    setTarget(target + dx * 5)
    return true
  }

  function activateCursor() { if (cursorIndex === 1 && fansOk) setAuto(!fans.auto) }

  function textKey(t) {
    if ((t === "f" || t === "F") && fansOk) setAuto(!fans.auto)
    else if (t === "r" || t === "R") refresh()
  }

  Component.onCompleted: refresh()

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
          var st = JSON.parse(text)
          root.s = st
          if (!root.busy && !root.targetDragging && st.fans.available) root.target = st.fans.target
        } catch (e) {
          root.error = "Couldn't read the fans"
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
      title: "Fans"
      meta: root.fansOk ? (root.fans.auto ? "Custom curve" : "The SMC drives them") : ""
      foreground: root.foreground
      fontFamily: root.fontFamily
      iconComponent: Component {
        Text {
          text: "󰈐"
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

      

      Text {
        visible: !root.fansOk
        width: parent.width
        leftPadding: Style.space(10)
        text: "t2-fan-control's daemon isn't answering: sudo systemctl enable --now t2-fancontrol.service"
        textFormat: Text.PlainText
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      CursorSurface {
        id: autoRow
        visible: root.fansOk
        width: column.width
        hasCursor: root.cursorActive && root.cursorIndex === 1
        foreground: root.foreground
        implicitHeight: autoContent.implicitHeight + Style.spacing.rowPaddingX

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: { root.cursorActive = true; root.cursorIndex = 1 }
          onClicked: root.setAuto(!root.fans.auto)
        }

        RowLayout {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)

          Text { text: "󰈐"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.icon }

          ColumnLayout {
            id: autoContent
            Layout.fillWidth: true
            spacing: Style.space(1)
            Text {
              Layout.fillWidth: true
              text: "Custom fan curve (f)"
              textFormat: Text.PlainText
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }
            Text {
              Layout.fillWidth: true
              text: root.fansOk && root.fans.auto ? "Cooling to keep the system under " + root.target + "° (" + root.fans.percent + "%)"
                                                 : "Off: the SMC drives the fans, as on macOS"
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }

          ToggleSwitch {
            checked: root.fansOk && root.fans.auto
            busy: root.busy
            interactive: false
            foreground: root.foreground
            Layout.alignment: Qt.AlignVCenter
          }
        }
      }

      CursorSurface {
        visible: root.fansOk
        width: column.width
        hasCursor: root.cursorActive && root.cursorIndex === 2
        foreground: root.foreground
        implicitHeight: targetRow.implicitHeight + Style.spacing.rowPaddingX
        enabled: root.fansOk && root.fans.auto
        opacity: enabled ? 1.0 : 0.5

        HoverHandler { onHoveredChanged: if (hovered) { root.cursorActive = true; root.cursorIndex = 2 } }

        RowLayout {
          id: targetRow
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)

          Text { text: "Cool to"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }

          PanelSlider {
            id: targetSlider
            bar: root.bar
            Layout.fillWidth: true
            minimum: 50
            maximum: 100
            step: 5
            value: root.target
            onDraggingChanged: root.targetDragging = dragging
            onReleased: function(v) { root.setTarget(v) }
          }

          Text {
            text: Math.round(targetSlider.dragging ? targetSlider.liveValue : root.target) + "°"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            Layout.preferredWidth: Style.space(34)
            horizontalAlignment: Text.AlignRight
          }
        }
      }

      Repeater {
        model: root.fansOk ? root.fans.fans : []
        InfoRow {
          required property var modelData
          icon: "󰈐"
          label: modelData.name
          detail: modelData.min + "–" + modelData.max + " rpm"
          value: modelData.rpm + " rpm"
        }
      }

      InfoRow {
        visible: root.fansOk
        icon: "󰔏"
        label: "Processor " + root.deg(root.fansOk ? root.fans.cpu : null) + " · graphics " + root.deg(root.fansOk ? root.fans.gpu : null)
        detail: root.s ? "Battery " + root.deg(root.s.temps.battery) + " · room " + root.deg(root.s.temps.ambient) : ""
        value: ""
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

