import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

// GeForce cards for an NVIDIA host reached over SSH.
// Left click opens the instrument panel. Right click opens nvidia-smi.
// Middle click polls immediately.
BarWidget {
  id: root

  readonly property string fontFamily: (bar && bar.fontFamily) ? bar.fontFamily : Style.font.family
  readonly property color fg: Color.popups.text
  readonly property color muted: Qt.rgba(fg.r, fg.g, fg.b, 0.62)
  readonly property int count: Math.max(1, probe.gpus.length)
  readonly property int gap: 4
  readonly property int faceW: vertical ? Math.max(18, barSize - 2) : 120
  readonly property int faceH: vertical ? 40 : Math.max(18, barSize - 2)
  readonly property real openPanelIndicatorWidth: implicitWidth
  readonly property real openPanelIndicatorHeight: implicitHeight

  property bool popupOpen: false
  readonly property bool opened: popupOpen

  function open() {
    popupOpen = true
    probe.poll()
  }

  function close() {
    popupOpen = false
  }

  function closeForPopoutSwitch() {
    popupOpen = false
  }

  function toggle() {
    if (popupOpen) close()
    else open()
  }

  function openSmi() {
    if (!probe.ready) return
    Quickshell.execDetached(["omarchy", "launch", "tui", "--app-id=remote-nvidia"].concat(probe.smiArgs()))
  }

  implicitWidth: vertical ? barSize : (faceW * count + gap * Math.max(0, count - 1))
  implicitHeight: vertical ? (faceH * count + gap * Math.max(0, count - 1)) : barSize

  onSettingsChanged: probe.configure(settings)
  Component.onCompleted: probe.configure(settings)

  Probe {
    id: probe
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    tooltipText: probe.tooltip

    onPressed: function(button) {
      if (button === Qt.RightButton) root.openSmi()
      else if (button === Qt.MiddleButton) probe.poll()
      else root.toggle()
    }

    Repeater {
      model: probe.gpus

      GpuFace {
        required property var modelData
        required property int index

        x: root.vertical ? Math.round((root.width - root.faceW) / 2) : index * (root.faceW + root.gap)
        y: root.vertical ? index * (root.faceH + root.gap) : Math.round((root.height - root.faceH) / 2)
        width: root.faceW
        height: root.faceH
        gpu: modelData
        linked: probe.linked
        animate: true
        warnC: probe.warnC
        hotC: probe.hotC
        fontFamily: root.fontFamily
      }
    }
  }

  component StatRow: Item {
    id: stat
    property string label: ""
    property string value: ""
    property color valueColor: root.fg

    height: Math.max(16, valueText.implicitHeight)
    width: parent ? parent.width : 0

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: stat.label
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: 11
      renderType: Text.NativeRendering
    }

    Text {
      id: valueText
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: stat.value
      color: stat.valueColor
      font.family: root.fontFamily
      font.pixelSize: 12
      font.bold: true
      renderType: Text.NativeRendering
    }
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.opened
    padding: Style.space(14)
    contentWidth: popup.fittedContentWidth(Style.space(640))
    contentHeight: popup.fittedContentHeight(body.implicitHeight, Style.space(720))

    Flickable {
      id: flick
      anchors.fill: parent
      contentWidth: width
      contentHeight: body.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height + 2

      Column {
        id: body
        width: flick.width
        spacing: Style.space(12)

        Item {
          width: parent.width
          height: header.implicitHeight

          Column {
            id: header
            spacing: 2

            Row {
              spacing: Style.space(8)

              Text {
                text: probe.host || "NVIDIA"
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: true
                font.letterSpacing: 1.1
                font.capitalization: Font.AllUppercase
                renderType: Text.NativeRendering
              }

              Rectangle {
                width: 7
                height: 7
                radius: 3.5
                color: Model.colorFor(probe.watch.level)
              }

              Text {
                text: probe.ageLabel
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: 11
                renderType: Text.NativeRendering
              }
            }

            Text {
              text: {
                var gpu = probe.gpus.length > 0 ? probe.gpus[0] : null
                var name = gpu && gpu.name ? gpu.name.replace(/^NVIDIA\s+/i, "") : "GeForce"
                var driver = probe.driver ? "  ·  driver " + probe.driver : ""
                return probe.gpus.length + "×  " + name + driver
              }
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: 11
              renderType: Text.NativeRendering
            }
          }

          Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: "nvidia-smi"
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: 11
            font.underline: true
            renderType: Text.NativeRendering

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.openSmi()
            }
          }
        }

        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: probe.watch.text
          color: Model.colorFor(probe.watch.level)
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: probe.watch.level === "hot" || probe.watch.level === "warn"
          renderType: Text.NativeRendering
        }

        Text {
          visible: probe.lastError !== "" && !probe.linked
          width: parent.width
          wrapMode: Text.WordWrap
          text: probe.lastError
          color: root.muted
          font.family: root.fontFamily
          font.pixelSize: 11
          renderType: Text.NativeRendering
        }

        Row {
          id: cardRow
          width: parent.width
          spacing: Style.space(14)
          property real cardWidth: Math.max(120, (width - spacing * Math.max(0, root.count - 1)) / root.count)

          Repeater {
            model: probe.gpus

            Column {
              required property var modelData
              required property int index

              width: cardRow.cardWidth
              spacing: Style.space(6)

              Text {
                text: "GPU " + modelData.index + (modelData.bus ? "   ·   " + modelData.bus : "")
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: 12
                font.bold: true
                renderType: Text.NativeRendering
              }

              GpuFace {
                width: parent.width
                height: 156
                gpu: modelData
                linked: probe.linked
                animate: root.opened
                warnC: probe.warnC
                hotC: probe.hotC
                fontFamily: root.fontFamily
              }

              StatRow { label: "Load"; value: Model.fmt(modelData.utilGpu, "%"); valueColor: Model.utilColor(modelData.utilGpu) }
              StatRow { label: "Power"; value: Model.fmt(modelData.power, " W") + "  /  " + Model.fmt(modelData.powerLimit, " W"); valueColor: Model.powerColor(Model.powerFraction(modelData)) }
              StatRow { label: "VRAM"; value: Model.gib(modelData.memUsed) + "  /  " + Model.gib(modelData.memTotal) + " GB"; valueColor: Model.memColor(Model.memFraction(modelData)) }
              StatRow { label: "Fan"; value: Model.fmt(modelData.fan, "%") }
              StatRow { label: "Clock"; value: Model.clockPair(modelData.smClock, modelData.smMax) }
              StatRow { label: "Memory"; value: Model.fmt(modelData.memClock, " MHz") }
              StatRow {
                label: "State"
                value: (modelData.pstate || "—") + (modelData.throttle ? "  ·  throttling" : "  ·  clear")
                valueColor: modelData.throttle ? Model.colorFor("hot") : root.fg
              }

              Item {
                width: parent.width
                height: caption.implicitHeight

                Text {
                  id: caption
                  anchors.left: parent.left
                  text: "temperature"
                  color: root.muted
                  font.family: root.fontFamily
                  font.pixelSize: 10
                  renderType: Text.NativeRendering
                }

                Text {
                  anchors.right: parent.right
                  anchors.baseline: caption.baseline
                  text: probe.warnC + "°"
                  color: "#ff8a3d"
                  font.family: root.fontFamily
                  font.pixelSize: 10
                  renderType: Text.NativeRendering
                }
              }

              Sparkline {
                width: parent.width
                height: Style.space(36)
                samples: probe.samples(modelData.index)
                stroke: Model.colorFor(Model.band(modelData.temp, probe.warnC, probe.hotC))
                warnAt: probe.warnC
              }

              Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: Model.procSummary(modelData.procs) || (probe.linked ? "no compute process" : "")
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: 11
                renderType: Text.NativeRendering
              }
            }
          }
        }
      }
    }
  }
}
