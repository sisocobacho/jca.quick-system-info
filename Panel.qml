import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "jca.quick-system-info"
  ipcTarget: "jca.quick-system-info"

  property var status: ({})
  property string errorText: ""
  readonly property string collectorScript: Quickshell.env("HOME") + "/.config/omarchy/plugins/jca.quick-system-info/collect.py"
  readonly property string labelText: status.label || " --"
  readonly property string temperatureText: status.temperature_text || "—"
  readonly property string thermalStatus: String(status.thermal_status || "Unknown").toUpperCase()
  readonly property string cpuValue: status.cpu_name
    ? status.cpu_name + " · " + (status.cpu || "—")
    : (status.cpu || "—")
  readonly property string memoryValue: (status.memory_used && status.memory_total)
    ? status.memory_used + " / " + status.memory_total
    : "—"
  readonly property string diskValue: (status.disk_used && status.disk_total)
    ? status.disk_used + " / " + status.disk_total
    : "—"
  readonly property string gpuTempValue: status.gpu_temp !== undefined && status.gpu_temp !== null ? status.gpu_temp + "°C" : "—"
  readonly property string diskTempValue: status.disk_temp !== undefined && status.disk_temp !== null ? status.disk_temp + "°C" : "—"
  readonly property real openPanelIndicatorWidth: !button.vertical ? button.labelWidth : 0
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color accentColor: {
    var s = String(status.thermal_status || "").toLowerCase()
    if (s === "hot") return "#ef4444"
    if (s === "warm") return "#f59e0b"
    return contentForeground
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function openBtop() {
    if (!root.bar) return
    root.bar.run("omarchy-launch-or-focus-tui btop")
  }

  function updateStatus(raw) {
    try {
      var parsed = JSON.parse(raw)
      if (parsed && typeof parsed === "object") {
        root.status = parsed
        root.errorText = ""
      }
    } catch (e) {
      if (!root.status.label) root.errorText = "Failed to parse system status"
    }
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: refresh()
  onOpenedChanged: if (opened) refresh()

  Process {
    id: statusProc
    command: ["python3", root.collectorScript]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateStatus(text) }
  }

  Timer {
    interval: 10000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    interval: 3000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.labelText
    fontSize: Style.font.caption
    horizontalMargin: 6
    tooltipText: ""

    onPressed: function(b) {
      if (b === Qt.RightButton) root.openBtop()
      else if (b === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(520))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function") root.bar.switchPanelFrom(root, direction)
      }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Style.space(16)
        anchors.rightMargin: Style.space(16)
        anchors.top: parent.top
        spacing: Style.space(14)

        Item {
          width: parent.width
          implicitHeight: Math.max(heroLeft.implicitHeight, heroMeta.implicitHeight)

          Row {
            id: heroLeft
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(14)

            Text {
              text: "󰌢"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: 42
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: heroTemp
              text: root.temperatureText
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.displayLarge
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Column {
            id: heroMeta
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            Text {
              text: "System"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Row {
              spacing: Style.space(8)

              Rectangle {
                width: Style.space(8)
                height: width
                radius: width / 2
                color: root.accentColor
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: root.thermalStatus
                color: root.accentColor
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(40)

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.space(10)
            InfoPair { label: "CPU"; value: root.cpuValue }
            InfoPair { label: "Memory"; value: root.memoryValue }
            InfoPair { label: "Disk"; value: root.diskValue }
            InfoPair { label: "Uptime"; value: root.status.uptime || "—" }
          }

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.space(10)
            InfoPair { label: "GPU"; value: root.status.gpu || "—" }
            InfoPair { label: "GPU temp"; value: root.gpuTempValue }
            InfoPair { label: "Disk temp"; value: root.diskTempValue }
            InfoPair { label: "Network"; value: root.status.network || "—" }
          }
        }

        PanelSeparator {
          foreground: root.contentForeground
        }

        Column {
          width: parent.width
          spacing: Style.space(8)

          InfoPair { label: "Host"; value: root.status.host || "—" }
          InfoPair { label: "IP address"; value: root.status.ip_address || "—" }
          InfoPair { label: "Kernel"; value: root.status.kernel || "—" }
          InfoPair { label: "Filesystem"; value: root.status.filesystem || "—" }

          Text {
            visible: root.errorText !== ""
            text: root.errorText
            color: "#ef4444"
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }
      }
    }
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""

    width: parent.width
    spacing: Style.space(8)

    InfoLabel { text: label }
    Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
    InfoValue { text: value }
  }

  component InfoLabel: Text {
    textFormat: Text.PlainText
    color: root.contentForeground
    opacity: 0.6
    font.family: root.contentFontFamily
    font.pixelSize: Style.font.bodySmall
  }

  component InfoValue: Text {
    textFormat: Text.PlainText
    color: root.contentForeground
    font.family: root.contentFontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.NoWrap
    elide: Text.ElideRight
  }
}
