import QtQuick
import "Model.js" as Model

// A Founders-style GeForce card. The bar uses the short form: a fan, the
// temperature, and a VRAM stripe. The popup uses the tall form, with the
// name, watts, and fins.
Item {
  id: root

  property var gpu: ({})
  property bool linked: false
  property bool animate: true
  property int warnC: 83
  property int hotC: 90
  property string fontFamily: ""

  readonly property bool hero: height >= 80
  readonly property bool tiny: width < 56
  readonly property bool hasReading: {
    var temp = gpu ? gpu.temp : null
    return temp !== null && temp !== undefined && isFinite(temp)
  }
  readonly property string bandName: Model.band(hasReading ? gpu.temp : null, warnC, hotC)
  readonly property string heatHex: Model.colorFor(bandName)
  readonly property color heat: heatHex
  readonly property real fanPct: linked ? Model.spinPercent(gpu) : 0
  readonly property real util: Model.utilOf(gpu)
  readonly property string utilHex: Model.utilColor(gpu ? gpu.utilGpu : null)
  readonly property real memFill: Model.memFraction(gpu)
  readonly property string memHex: Model.memColor(memFill)
  readonly property int bladeCount: hero ? 11 : 9
  readonly property int gpuIndex: gpu && gpu.index !== undefined ? gpu.index : 0
  readonly property string badge: Model.heroTitle(gpu)
  readonly property string kicker: Model.kicker(gpu)
  readonly property string tempText: hasReading ? Math.round(gpu.temp) + "°" : "—"
  readonly property string powerText: {
    if (!hasReading) return ""
    var power = Model.fmt(gpu.power, "W")
    var load = Model.fmt(gpu.utilGpu, "%")
    if (power === "—" && load === "—") return ""
    return power + "  ·  " + load
  }
  readonly property color stripe: gpuIndex === 1 ? "#8eb4c8" : "#e0c79a"

  property real spin: 0
  property real pulse: 0.4

  Timer {
    interval: 32
    repeat: true
    running: root.animate && root.visible && root.fanPct > 1
    onTriggered: root.spin = (root.spin + root.fanPct * 0.2 + (root.util > 85 ? 1.2 : 0)) % 360
  }

  SequentialAnimation on pulse {
    running: root.animate && (root.bandName === "hot" || root.bandName === "warn")
    loops: Animation.Infinite
    NumberAnimation { from: 0.35; to: 1; duration: 640; easing.type: Easing.InOutQuad }
    NumberAnimation { from: 1; to: 0.35; duration: 640; easing.type: Easing.InOutQuad }
  }

  Rectangle {
    id: frame
    anchors.fill: parent
    radius: root.hero ? 12 : 4
    antialiasing: true
    opacity: !root.hasReading ? 0.78 : (root.linked ? 1 : 0.7)
    gradient: Gradient {
      GradientStop { position: 0.0; color: "#f6f3ec" }
      GradientStop { position: 0.16; color: "#c4bfb4" }
      GradientStop { position: 0.48; color: "#6e6a64" }
      GradientStop { position: 1.0; color: "#1e2126" }
    }
    border.width: root.bandName === "hot" || root.bandName === "warn" ? (root.hero ? 2 : 1) : 0
    border.color: root.heat
  }

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: root.hero ? 5 : 2
    height: 1
    color: "#ffffff"
    opacity: 0.55
    z: 4
  }

  Rectangle {
    z: 5
    width: root.hero ? 3 : 2
    radius: 1
    antialiasing: true
    anchors.left: parent.left
    anchors.leftMargin: root.hero ? 5 : 2
    anchors.verticalCenter: parent.verticalCenter
    height: Math.max(6, parent.height * (root.hero ? 0.42 : 0.5))
    color: root.stripe
  }

  Rectangle {
    id: body
    anchors.fill: frame
    anchors.margins: root.hero ? 3 : 1
    radius: root.hero ? 9 : 3
    color: "#101216"
    clip: true
    antialiasing: true

    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      color: root.heat
      opacity: !root.hasReading ? 0 : (root.bandName === "hot" ? 0.18 * root.pulse : root.bandName === "warn" ? 0.12 * root.pulse : root.bandName === "busy" ? 0.07 : 0.035)
    }

    Item {
      id: finField
      visible: root.hero
      anchors.top: parent.top
      anchors.bottom: vram.top
      anchors.right: parent.right
      width: Math.max(0, parent.width * 0.62)
      clip: true

      Repeater {
        model: 16

        Rectangle {
          required property int index
          width: 2
          height: finField.height * 1.8
          x: index * (finField.width / 12) - 14
          y: -10
          rotation: -34
          transformOrigin: Item.Center
          color: "#d9d4c8"
          opacity: 0.1
        }
      }
    }

    Rectangle {
      id: vram
      visible: !root.tiny
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.leftMargin: root.hero ? 10 : 3
      anchors.rightMargin: root.hero ? 10 : 3
      anchors.bottomMargin: root.hero ? 8 : 2
      height: root.hero ? 7 : 2
      radius: height / 2
      color: "#242830"

      Rectangle {
        width: Math.max(height, parent.width * root.memFill)
        height: parent.height
        radius: parent.radius
        color: root.memHex
        visible: root.memFill > 0

        Behavior on width {
          NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
        }
      }
    }

    Text {
      visible: root.hero && root.gpu && root.gpu.throttle
      text: "THROTTLE"
      color: "#ff5b5b"
      font.family: root.fontFamily
      font.pixelSize: 9
      font.bold: true
      font.letterSpacing: 0.8
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 8
      z: 3
    }

    Row {
      id: row
      visible: !root.tiny
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: vram.top
      anchors.leftMargin: root.hero ? 8 : 3
      anchors.rightMargin: root.hero ? 8 : 4
      anchors.topMargin: root.hero ? 8 : 2
      anchors.bottomMargin: root.hero ? 6 : 1
      spacing: root.hero ? 10 : 4

      Item {
        id: fanBox
        width: height
        height: parent.height

        Rectangle {
          anchors.fill: parent
          radius: width / 2
          color: "#07080c"
          border.color: root.hero ? "#c8c2b6" : "#3a404a"
          border.width: root.hero ? 2 : 1
          antialiasing: true
        }

        Canvas {
          id: ring
          anchors.fill: parent
          antialiasing: true
          readonly property real dpr: Math.max(1, Screen.devicePixelRatio)
          canvasSize: Qt.size(Math.max(1, width * dpr), Math.max(1, height * dpr))
          onWidthChanged: requestPaint()
          onHeightChanged: requestPaint()
          onPaint: {
            var ctx = getContext("2d")
            var dpr = Math.max(1, width > 0 && canvasSize.width > 0 ? canvasSize.width / width : 1)
            ctx.setTransform(1, 0, 0, 1, 0, 0)
            ctx.clearRect(0, 0, canvasSize.width, canvasSize.height)
            ctx.scale(dpr, dpr)
            var w = width
            var h = height
            var cx = w / 2
            var cy = h / 2
            var line = w >= 70 ? 3.4 : 1.5
            var radius = Math.min(w, h) / 2 - line * 0.5 - (root.hero ? 1 : 0)
            if (radius < 2) return
            ctx.lineWidth = line
            ctx.lineCap = "round"
            ctx.strokeStyle = "rgba(255,255,255,0.16)"
            ctx.beginPath()
            ctx.arc(cx, cy, radius, 0, Math.PI * 2)
            ctx.stroke()
            if (root.util <= 0) return
            ctx.strokeStyle = root.utilHex
            ctx.beginPath()
            var start = -Math.PI / 2
            ctx.arc(cx, cy, radius, start, start + Math.PI * 2 * (root.util / 100))
            ctx.stroke()
          }
        }

        Item {
          id: rotor
          anchors.fill: parent
          anchors.margins: root.hero ? 10 : 2
          rotation: root.spin

          Repeater {
            model: root.bladeCount

            Rectangle {
              required property int index
              property real well: rotor.width
              width: Math.max(1, well * (root.hero ? 0.07 : 0.1))
              height: well * 0.46
              x: well / 2 - width / 2
              y: well / 2 - height
              radius: width
              antialiasing: true
              color: root.hero ? "#525866" : "#e6e0d2"
              transformOrigin: Item.Bottom
              rotation: index * (360 / Math.max(1, root.bladeCount))
            }
          }
        }

        Rectangle {
          id: hub
          anchors.centerIn: parent
          width: Math.max(4, parent.width * (root.hero ? 0.3 : 0.38))
          height: width
          radius: width / 2
          color: "#14171c"
          border.color: root.hasReading ? root.heat : "#3a3e46"
          border.width: root.hero ? 2 : 1
          antialiasing: true
          z: 2

          Text {
            anchors.centerIn: parent
            visible: hub.width >= 12
            text: String(root.gpuIndex)
            color: "#f4f1ea"
            font.family: root.fontFamily
            font.pixelSize: Math.max(8, Math.round(hub.width * 0.42))
            font.bold: true
            renderType: Text.NativeRendering
          }
        }
      }

      Item {
        id: shroud
        width: Math.max(0, row.width - fanBox.width - row.spacing)
        height: parent.height

        Column {
          visible: root.hero
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: 1

          Text {
            textFormat: Text.PlainText
            text: root.kicker
            color: "#b7b2a6"
            font.family: root.fontFamily
            font.pixelSize: 10
            font.letterSpacing: 1.8
            renderType: Text.NativeRendering
          }

          Text {
            textFormat: Text.PlainText
            text: root.badge
            color: "#f4f1ea"
            font.family: root.fontFamily
            font.pixelSize: 20
            font.bold: true
            renderType: Text.NativeRendering
          }

          Text {
            text: root.tempText
            color: root.heat
            font.family: root.fontFamily
            font.pixelSize: 34
            font.bold: true
            renderType: Text.NativeRendering

            Behavior on color { ColorAnimation { duration: 240 } }
          }

          Text {
            text: root.powerText
            color: "#c9c4b8"
            font.family: root.fontFamily
            font.pixelSize: 12
            renderType: Text.NativeRendering
          }
        }

        Text {
          visible: !root.hero
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: root.badge
          color: "#a39e92"
          font.family: root.fontFamily
          font.pixelSize: 8
          font.letterSpacing: 0.4
          renderType: Text.NativeRendering
        }

        Text {
          visible: !root.hero
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.tempText
          color: root.heat
          font.family: root.fontFamily
          font.pixelSize: Math.max(12, Math.min(15, root.height * 0.52))
          font.bold: true
          renderType: Text.NativeRendering

          Behavior on color { ColorAnimation { duration: 240 } }
        }
      }
    }

    Item {
      id: tinyFan
      visible: root.tiny
      anchors.fill: parent
      anchors.margins: 1

      Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) - 2
        height: width
        radius: width / 2
        color: "#07080c"
        border.color: "#c8c2b6"
        border.width: 1
        antialiasing: true

        Text {
          anchors.centerIn: parent
          text: root.tempText
          color: root.heat
          font.family: root.fontFamily
          font.pixelSize: 9
          font.bold: true
          renderType: Text.NativeRendering
        }
      }
    }
  }

  Repeater {
    model: root.hero ? 4 : 0

    Rectangle {
      required property int index
      z: 6
      width: 5
      height: 5
      radius: 2.5
      antialiasing: true
      color: "#17191d"
      border.color: "#9a958a"
      border.width: 1
      x: (index % 2 === 0 ? 6 : root.width - 11)
      y: (index < 2 ? 6 : root.height - 11)
    }
  }

  onUtilChanged: ring.requestPaint()
  onUtilHexChanged: ring.requestPaint()
  onHeroChanged: ring.requestPaint()
  Component.onCompleted: Qt.callLater(function() { ring.requestPaint() })
}
