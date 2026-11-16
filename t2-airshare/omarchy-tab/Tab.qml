import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// The AirShare tab of the T2 panel (t2.panel): Quick Share with Android and AirDrop with Apple
// devices (the t2-airshare and t2-drop packages). The icon is lit while the
// Mac is visible (the receiver, t2-airshare.service, runs) and dim when it
// isn't; the panel has the visibility switch, sending a file, the clipboard
// or the last screenshot (AirShare's send window picks the device), the files
// received lately (open, show in folder) and the trusted devices. The
// `airshare` helper beside this file does the work; accepting a transfer
// stays in AirShare's notification. Hidden where T2 AirShare isn't installed.
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
        if (t === "v" || t === "V") root.setVisible(!root.visibleToOthers)
        else if (t === "s" || t === "S") root.runAction("send-files")
        else if (t === "r" || t === "R") root.refresh()
  }

  readonly property string helper: String(Qt.resolvedUrl("airshare")).replace(/^file:\/\//, "")

  property bool installed: false
  property bool visibleToOthers: false
  property bool busy: false
  property string downloadDir: ""
  property var trusted: []
  property var recent: []
  property string error: ""

  // Keyboard cursor over the panel's rows, in order: the switch, the three
  // send actions, the received files, the trusted devices.
  property bool cursorActive: false
  property int cursorIndex: 0
  readonly property var actions: [
    { id: "send-files", icon: "", label: "Send files…", detail: "Pick files, then a phone or a Mac nearby" },
    { id: "send-clipboard", icon: "", label: "Send the clipboard", detail: "Text or an image, as a file" },
    { id: "send-screenshot", icon: "", label: "Send the last screenshot", detail: "The newest file in your screenshots" }
  ]
  readonly property int rowCount: 1 + actions.length + recent.length + trusted.length

  function refresh() { if (!statusProc.running) statusProc.running = true }

  function act(args) {
    Quickshell.execDetached([root.helper].concat(args))
  }

  function setVisible(on) {
    if (busy) return
    busy = true
    visibleToOthers = on // optimistic: the knob moves at once
    toggleProc.command = [root.helper, "visible", on ? "on" : "off"]
    toggleProc.running = true
  }

  function runAction(id) {
    act([id])
    root.closeRequested()
  }

  function ago(seconds) {
    var diff = Math.max(0, Math.floor(Date.now() / 1000) - seconds)
    if (diff < 60) return "just now"
    if (diff < 3600) return Math.floor(diff / 60) + " min ago"
    if (diff < 86400) return Math.floor(diff / 3600) + " h ago"
    return Math.floor(diff / 86400) + " d ago"
  }

  function moveCursor(dy) {
    if (!cursorActive) { cursorActive = true; return }
    cursorIndex = Math.max(0, Math.min(rowCount - 1, cursorIndex + dy))
  }

  function activateCursor() {
    var i = cursorIndex
    if (i === 0) { setVisible(!visibleToOthers); return }
    i -= 1
    if (i < actions.length) { runAction(actions[i].id); return }
    i -= actions.length
    if (i < recent.length) { act(["open", recent[i].path]); root.closeRequested(); return }
    i -= recent.length
    if (i < trusted.length) act(["untrust", trusted[i]]), refreshSoon.restart()
  }

  Component.onCompleted: refresh()

  // The receiver can be switched elsewhere too (the app, systemctl).
  Timer {
    interval: 15000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    id: refreshSoon
    interval: 600
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
          if (!root.busy) root.visibleToOthers = !!s.visible
          root.downloadDir = s.downloadDir || ""
          root.trusted = s.trusted || []
          root.recent = s.recent || []
          root.error = ""
        } catch (e) {
          root.error = "Couldn't read AirShare's state"
        }
      }
    }
  }

  Process {
    id: toggleProc
    onExited: function(exitCode) {
      root.busy = false
      if (exitCode !== 0) root.error = "Couldn't switch the receiver"
      root.refresh()
    }
  }

  // One clickable row: an icon, a label with a detail line, and an optional
  // trailing button.
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
        title: "AirShare"
        meta: root.visibleToOthers ? "Visible to phones and Macs nearby" : "Hidden: nobody can send to this Mac"
        foreground: root.foreground
        fontFamily: root.fontFamily
        iconOpacity: root.visibleToOthers ? 1.0 : 0.5
        iconComponent: Component {
          Text {
            text: ""
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
          }
        }
        trailingControl: Component {
          ToggleSwitch {
            id: visibleSwitch
            checked: root.visibleToOthers
            busy: root.busy
            hasCursor: header.ringVisible
            foreground: hero.foreground
            onHovered: function(on) { if (on) { root.cursorActive = true; root.cursorIndex = 0 } }
            onToggled: root.setVisible(!root.visibleToOthers)

            PanelToolTip {
              visible: visibleSwitch.containsMouse
              text: root.visibleToOthers ? "Hide this Mac (v)" : "Make this Mac visible (v)"
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

      PanelSectionHeader {
        text: "Send"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Repeater {
        model: root.actions
        Row_ {
          required property var modelData
          required property int index
          width: column.width
          rowIndex: 1 + index
          icon: modelData.icon
          label: modelData.label
          detail: modelData.detail
          onActivated: root.runAction(modelData.id)
        }
      }
    }

    PanelSeparator { foreground: root.foreground }

    Column {
      width: parent.width
      spacing: Style.space(6)

      PanelSectionHeader {
        text: "Received"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Text {
        visible: root.recent.length === 0
        width: parent.width
        text: root.visibleToOthers ? "Nothing yet. Files land in " + root.downloadDir : "Nothing yet"
        textFormat: Text.PlainText
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
      }

      Repeater {
        model: root.recent
        Row_ {
          required property var modelData
          required property int index
          width: column.width
          rowIndex: 1 + root.actions.length + index
          icon: ""
          label: modelData.name
          detail: root.ago(modelData.when)
          trailingIcon: ""
          trailingTip: "Show in folder"
          onActivated: { root.act(["open", modelData.path]); root.close() }
          onTrailing: { root.act(["show", modelData.path]); root.close() }
        }
      }
    }

    PanelSeparator {
      visible: root.trusted.length > 0
      foreground: root.foreground
    }

    Column {
      visible: root.trusted.length > 0
      width: parent.width
      spacing: Style.space(6)

      PanelSectionHeader {
        text: "Trusted (accepted without asking)"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Repeater {
        model: root.trusted
        Row_ {
          required property var modelData
          required property int index
          width: column.width
          rowIndex: 1 + root.actions.length + root.recent.length + index
          icon: ""
          label: modelData
          detail: "Matched by name only"
          trailingIcon: ""
          trailingTip: "Stop trusting"
          onActivated: { root.act(["untrust", modelData]); refreshSoon.restart() }
          onTrailing: { root.act(["untrust", modelData]); refreshSoon.restart() }
        }
      }
    }
  }

  component Row_: CursorSurface {
    id: row
    property int rowIndex: 0
    property string icon: ""
    property string label: ""
    property string detail: ""
    property string trailingIcon: ""
    property string trailingTip: ""
    signal activated()
    signal trailing()

    hasCursor: root.cursorActive && root.cursorIndex === rowIndex
    foreground: root.foreground
    implicitHeight: rowContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: { root.cursorActive = true; root.cursorIndex = row.rowIndex }
      onClicked: row.activated()
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
          elide: Text.ElideMiddle
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

      PanelActionButton {
        visible: row.trailingIcon !== ""
        iconText: row.trailingIcon
        tooltipText: row.trailingTip
        foreground: root.foreground
        fontFamily: root.fontFamily
        Layout.alignment: Qt.AlignVCenter
        onClicked: row.trailing()
      }
    }
  }
}
