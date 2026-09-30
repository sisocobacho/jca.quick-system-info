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
  readonly property string deviceValue: status.device || status.host || "—"
  readonly property string cpuNameValue: status.cpu_name || "—"
  readonly property string cpuFrequencyValue: status.cpu || "—"
  readonly property string memoryValue: (status.memory_used && status.memory_total)
    ? status.memory_used + " / " + status.memory_total
    : "—"
  readonly property string ramTypeValue: status.ram_type || "—"
  readonly property string diskValue: (status.disk_used && status.disk_total)
    ? status.disk_used + " / " + status.disk_total
    : "—"
  readonly property string gpuTempValue: status.gpu_temp !== undefined && status.gpu_temp !== null ? status.gpu_temp + "°C" : "—"
  readonly property string diskTempValue: status.disk_temp !== undefined && status.disk_temp !== null ? status.disk_temp + "°C" : "—"
  readonly property real openPanelIndicatorWidth: !button.vertical ? button.labelWidth : 0
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function openBtop() {
    if (!root.bar) return
    root.bar.run("omarchy-launch-or-focus-tui btop")
  }

  function copyToClipboard(value) {
    if (!value) return
    Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(value) + " | wl-copy"])
  }

  function infoLine(label, value) {
    var text = value === undefined || value === null ? "" : String(value).trim()
    return label + ": " + (text !== "" ? text : "—")
  }

  readonly property string allInfoText: [
    infoLine("Device", root.deviceValue),
    infoLine("Temperature", root.temperatureText),
    infoLine("CPU", root.cpuNameValue),
    infoLine("CPU freq", root.cpuFrequencyValue),
    infoLine("Memory", root.memoryValue),
    infoLine("RAM type", root.ramTypeValue),
    infoLine("GPU", root.status.gpu || "—"),
    infoLine("GPU temp", root.gpuTempValue),
    infoLine("Disk", root.diskValue),
    infoLine("Disk temp", root.diskTempValue),
    infoLine("Network", root.status.network || "—"),
    infoLine("IP address", root.status.ip_address || "—"),
    infoLine("Distribution", root.status.distribution || "—"),
    infoLine("Kernel", root.status.kernel || "—"),
    infoLine("Filesystem", root.status.filesystem || "—"),
    infoLine("Uptime", root.status.uptime || "—")
  ].join("\n")

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
    contentWidth: panel.fittedContentWidth(Style.space(620))
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
          implicitHeight: Math.max(heroLeft.implicitHeight, heroStatus.implicitHeight)

          Column {
            id: heroStatus
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            Row {
              anchors.right: parent.right
              spacing: Style.space(8)

              Text {
                text: ""
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.displayLarge
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: root.temperatureText
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.displayLarge
                font.bold: true
                horizontalAlignment: Text.AlignRight
                anchors.verticalCenter: parent.verticalCenter
              }
            }

          }

          Item {
            id: heroLeft
            anchors.left: parent.left
            anchors.right: heroStatus.left
            anchors.rightMargin: Style.space(24)
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: heroLeftContent.implicitHeight

            Row {
              id: heroLeftContent
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(14)

              Text {
                id: heroLeftIcon
                text: "󰌢"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: 42
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: root.deviceValue
                width: Math.max(0, heroLeft.width - heroLeftIcon.implicitWidth - heroLeftContent.spacing)
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            MouseArea {
              id: copyAllMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.copyToClipboard(root.allInfoText)
            }

            PanelToolTip {
              visible: copyAllMouse.containsMouse
              text: "Copy all information"
              fontFamily: root.contentFontFamily
            }
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(10)

          DualInfoRow {
            leftLabel: "CPU"
            leftValue: root.cpuNameValue
            leftValueCopyable: true
            leftValueTooltipText: "Copy CPU"
            rightLabel: "CPU freq"
            rightValue: root.cpuFrequencyValue
            rightValueCopyable: true
            rightValueTooltipText: "Copy CPU frequency"
          }
          DualInfoRow {
            leftLabel: "Memory"
            leftValue: root.memoryValue
            leftValueCopyable: true
            leftValueTooltipText: "Copy memory"
            rightLabel: "RAM type"
            rightValue: root.ramTypeValue
            rightValueCopyable: true
            rightValueTooltipText: "Copy RAM type"
          }
          DualInfoRow {
            leftLabel: "GPU"
            leftValue: root.status.gpu || "—"
            leftValueCopyable: true
            leftValueTooltipText: "Copy GPU"
            rightLabel: "GPU temp"
            rightValue: root.gpuTempValue
          }
          DualInfoRow {
            leftLabel: "Disk"
            leftValue: root.diskValue
            leftValueCopyable: true
            leftValueTooltipText: "Copy disk usage"
            rightLabel: "Disk temp"
            rightValue: root.diskTempValue
          }
          DualInfoRow {
            leftLabel: "Network"
            leftValue: root.status.network || "—"
            leftValueCopyable: true
            leftValueTooltipText: "Copy network"
            rightLabel: "IP address"
            rightValue: root.status.ip_address || "—"
            rightValueCopyable: true
            rightValueTooltipText: "Copy IP address"
          }
        }

        PanelSeparator {
          foreground: root.contentForeground
        }

        Column {
          width: parent.width
          spacing: Style.space(8)

          InfoPair {
            label: "Distribution"
            value: root.status.distribution || "—"
            valueCopyable: true
            valueTooltipText: "Copy distribution"
          }
          InfoPair {
            label: "Kernel"
            value: root.status.kernel || "—"
            valueCopyable: true
            valueTooltipText: "Copy kernel"
          }
          InfoPair {
            label: "Filesystem"
            value: root.status.filesystem || "—"
            valueCopyable: true
            valueTooltipText: "Copy filesystem"
          }
          InfoPair { label: "Uptime"; value: root.status.uptime || "—" }

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

  component DualInfoRow: Row {
    property string leftLabel: ""
    property string leftValue: ""
    property bool leftValueCopyable: false
    property string leftValueTooltipText: "Copy to clipboard"
    property string leftValueCopyText: ""
    property string rightLabel: ""
    property string rightValue: ""
    property bool rightValueCopyable: false
    property string rightValueTooltipText: "Copy to clipboard"
    property string rightValueCopyText: ""

    width: parent.width
    spacing: Style.space(24)

    Item {
      width: (parent.width - parent.spacing) / 2
      implicitHeight: leftPair.implicitHeight

      InfoPair {
        id: leftPair
        width: parent.width
        label: parent.parent.leftLabel
        value: parent.parent.leftValue
        valueCopyable: parent.parent.leftValueCopyable
        valueTooltipText: parent.parent.leftValueTooltipText
        valueCopyText: parent.parent.leftValueCopyText
      }
    }

    Item {
      width: (parent.width - parent.spacing) / 2
      implicitHeight: rightPair.implicitHeight

      InfoPair {
        id: rightPair
        width: parent.width
        label: parent.parent.rightLabel
        value: parent.parent.rightValue
        valueCopyable: parent.parent.rightValueCopyable
        valueTooltipText: parent.parent.rightValueTooltipText
        valueCopyText: parent.parent.rightValueCopyText
      }
    }
  }

  component InfoPair: Row {
    id: pair
    property string label: ""
    property string value: ""
    property bool valueCopyable: false
    property string valueTooltipText: "Copy to clipboard"
    property string valueCopyText: ""

    width: parent ? parent.width : 0
    spacing: Style.space(8)

    InfoLabel { text: label }
    Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
    CopyableInfoValue {
      text: pair.value
      copyable: pair.valueCopyable
      tooltipText: pair.valueTooltipText
      copyText: pair.valueCopyText
    }
  }

  component CopyableInfoValue: InfoValue {
    property bool copyable: false
    property string tooltipText: "Copy to clipboard"
    property string copyText: ""

    MouseArea {
      id: valueMouse
      anchors.fill: parent
      enabled: parent.copyable && parent.text !== "" && parent.text !== "—"
      hoverEnabled: enabled
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: root.copyToClipboard(parent.copyText || parent.text)
    }

    PanelToolTip {
      visible: valueMouse.enabled && valueMouse.containsMouse
      text: parent.tooltipText
      fontFamily: root.contentFontFamily
    }
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
