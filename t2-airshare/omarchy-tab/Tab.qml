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
  readonly property int rowCount: sendMode ? devices.length + 2 : 1 + actions.length + recent.length + trusted.length

  // Sending: the files the send actions picked (the helper's "pending"), the
  // devices found nearby, and the transfer to the one picked.
  property var pending: []
  property var devices: []
  property string phase: "pick"   // pick, sending, done
  property var target: null
  property string pin: ""
  property int percent: -1
  property string result: ""      // sent, declined, error
  property string resultText: ""
  readonly property bool sendMode: pending.length > 0
  readonly property bool scanning: nearbyProc.running

  function fileName(path) { return String(path).split("/").pop() }

  function startScan() {
    if (nearbyProc.running) return
    devices = []
    nearbyProc.running = true
  }

  function sendTo(d) {
    nearbyProc.running = false
    target = d
    pin = ""
    percent = -1
    result = ""
    resultText = ""
    phase = "sending"
    sendProc.command = [root.helper, "send-to", d.proto, d.proto === "quickshare" ? d.addr : d.id].concat(pending)
    sendProc.running = true
  }

  function finishSend() {
    sendProc.running = false
    nearbyProc.running = false
    Quickshell.execDetached([root.helper, "pending", "clear"])
    pending = []
    devices = []
    phase = "pick"
    result = ""
    cursorIndex = 0
  }

  function deviceIcon(d) { return d.proto === "airdrop" ? "" : (d.type === "Tablet" ? "󰓶" : d.type === "Laptop" ? "󰌢" : "󰏲") }
  // A phone that advertises only an encrypted identity (Samsung's Quick Share
  // does even on Everyone) has no name to show: t2airshare calls it "Hidden
  // device <id>"; its type is all there is.
  function hiddenName(d) { return d.proto === "quickshare" && String(d.name).indexOf("Hidden device ") === 0 }
  function deviceLabel(d) {
    if (!hiddenName(d)) return d.name
    return d.type === "Tablet" ? "Android tablet" : d.type === "Laptop" ? "Android laptop" : "Android phone"
  }
  function deviceDetail(d) {
    if (d.proto === "airdrop") return "Apple device (AirDrop)"
    if (hiddenName(d)) return "Quick Share · the phone hides its name"
    return (d.type === "Unknown" ? "Android" : d.type) + " (Quick Share)"
  }

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
    if (sendMode) {
      if (phase === "pick" && cursorIndex < devices.length) sendTo(devices[cursorIndex])
      else if (phase === "pick" && cursorIndex === devices.length) startScan()
      else finishSend()
      return
    }
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
          root.pending = s.pending || []
          if (root.sendMode && root.phase === "pick" && root.devices.length === 0) root.startScan()
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

  // The devices nearby, one JSON line each as the helper's discoveries find them.
  Process {
    id: nearbyProc
    command: [root.helper, "nearby", "30"]
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var d = JSON.parse(line)
          var key = d.proto + ":" + d.id
          if (!root.devices.some(function(x) { return x.proto + ":" + x.id === key }))
            root.devices = root.devices.concat([d])
        } catch (e) {}
      }
    }
  }

  // The transfer: waiting (the PIN), sending, progress, then sent, declined or error.
  Process {
    id: sendProc
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var e = JSON.parse(line)
          if (e.event === "waiting") root.pin = e.pin
          else if (e.event === "progress") root.percent = e.percent
          else if (e.event === "sent") { root.result = "sent"; root.resultText = "Sent" }
          else if (e.event === "declined") { root.result = "declined"; root.resultText = "Declined on the other side" }
          else if (e.event === "error") { root.result = "error"; root.resultText = e.message }
        } catch (err) {}
      }
    }
    onExited: function(exitCode) {
      if (root.result === "") { root.result = exitCode === 0 ? "sent" : "error"; root.resultText = exitCode === 0 ? "Sent" : "That didn't work" }
      root.phase = "done"
      root.cursorIndex = root.devices.length
    }
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

    SendView { visible: root.sendMode }

    Column {
      width: parent.width
      spacing: Style.space(6)
      visible: !root.sendMode

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

    PanelSeparator { foreground: root.foreground; visible: !root.sendMode }

    Column {
      width: parent.width
      spacing: Style.space(6)
      visible: !root.sendMode

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
          onActivated: { root.act(["open", modelData.path]); root.closeRequested() }
          onTrailing: { root.act(["show", modelData.path]); root.closeRequested() }
        }
      }
    }

    PanelSeparator {
      visible: root.trusted.length > 0 && !root.sendMode
      foreground: root.foreground
    }

    Column {
      visible: root.trusted.length > 0 && !root.sendMode
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

  // Sending: the files, then the devices nearby to pick from, then the
  // transfer's PIN, progress and result.
  component SendView: Column {
    width: column.width
    spacing: Style.space(6)

    PanelSectionHeader {
      text: root.phase === "pick" ? "Send to" : root.target ? root.deviceLabel(root.target) : "Sending"
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    Text {
      width: parent.width
      leftPadding: Style.space(10)
      rightPadding: Style.space(10)
      text: root.pending.length === 1 ? root.fileName(root.pending[0])
            : root.pending.length + " files: " + root.pending.map(root.fileName).join(", ")
      textFormat: Text.PlainText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }

    // Picking: the devices as they're found.
    Repeater {
      model: root.phase === "pick" ? root.devices : []
      Row_ {
        required property var modelData
        required property int index
        width: column.width
        rowIndex: index
        icon: root.deviceIcon(modelData)
        label: root.deviceLabel(modelData)
        detail: root.deviceDetail(modelData)
        onActivated: root.sendTo(modelData)
      }
    }

    Row_ {
      visible: root.phase === "pick"
      width: column.width
      rowIndex: root.devices.length
      icon: root.scanning ? "󰑓" : "󰑐"
      label: root.scanning ? (root.devices.length ? "Looking for more…" : "Looking nearby…") : (root.devices.length ? "Look again" : "Nobody found: look again")
      detail: "Phones need Quick Share visible to everyone; iPhones and Macs, AirDrop for everyone"
      onActivated: root.startScan()
    }

    // Sending: the PIN the phone shows, the progress, the result.
    Text {
      visible: root.phase !== "pick" && root.pin !== "" && root.result === ""
      width: parent.width
      leftPadding: Style.space(10)
      text: "Accept on the phone: PIN " + root.pin
      textFormat: Text.PlainText
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    Text {
      visible: root.phase === "sending" && root.pin === "" && root.percent < 0
      width: parent.width
      leftPadding: Style.space(10)
      text: "Accept on the other device…"
      textFormat: Text.PlainText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    Item {
      visible: root.phase === "sending" && root.percent >= 0
      width: parent.width
      implicitHeight: Style.space(18)
      Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(50)
        height: Style.space(6)
        radius: height / 2
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15)
        Rectangle {
          width: parent.width * Math.max(0, Math.min(100, root.percent)) / 100
          height: parent.height
          radius: parent.radius
          color: root.foreground
        }
      }
      Text {
        anchors.right: parent.right
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        text: root.percent + "%"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    Row_ {
      visible: root.phase === "done"
      width: column.width
      rowIndex: root.devices.length
      icon: root.result === "sent" ? "󰄬" : "󰅖"
      label: root.resultText
      detail: "Done"
      onActivated: root.finishSend()
    }

    Row_ {
      visible: root.phase !== "done"
      width: column.width
      rowIndex: root.devices.length + 1
      icon: "󰜺"
      label: "Cancel"
      detail: root.phase === "sending" ? "Stops the transfer" : "Leaves sending"
      onActivated: root.finishSend()
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
