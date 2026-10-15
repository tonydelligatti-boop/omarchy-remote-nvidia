import QtQuick

// Session temperature trace. The vertical scale stays fixed so a quiet
// card does not look like it is climbing, and the dashed line is the
// warn temperature.
Canvas {
  id: root

  property var samples: []
  property string stroke: "#f0c14a"
  property real warnAt: 83
  property real low: 35
  property real high: 100
  readonly property real dpr: Math.max(1, Screen.devicePixelRatio)

  canvasSize: Qt.size(Math.max(1, width * dpr), Math.max(1, height * dpr))

  onSamplesChanged: requestPaint()
  onStrokeChanged: requestPaint()
  onWarnAtChanged: requestPaint()
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
    if (w < 4 || h < 4) return

    function yOf(temp) {
      var clamped = Math.max(root.low, Math.min(root.high, temp))
      return h - 3 - ((clamped - root.low) / (root.high - root.low)) * (h - 6)
    }

    ctx.strokeStyle = "rgba(255,138,61,0.7)"
    ctx.lineWidth = 1
    ctx.setLineDash([3, 3])
    ctx.beginPath()
    var warnY = yOf(root.warnAt)
    ctx.moveTo(0, warnY)
    ctx.lineTo(w, warnY)
    ctx.stroke()
    ctx.setLineDash([])

    var points = root.samples || []
    if (!points.length) return
    ctx.strokeStyle = root.stroke
    ctx.fillStyle = root.stroke
    ctx.lineWidth = 1.6
    ctx.lineJoin = "round"
    ctx.lineCap = "round"
    ctx.beginPath()
    for (var i = 0; i < points.length; i++) {
      var x = points.length === 1 ? w - 2 : (i / (points.length - 1)) * (w - 2) + 1
      var y = yOf(points[i].temp)
      if (i === 0) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
    }
    ctx.stroke()
    var last = points[points.length - 1]
    var lx = w - 2
    var ly = yOf(last.temp)
    ctx.beginPath()
    ctx.arc(lx, ly, 2.2, 0, Math.PI * 2)
    ctx.fill()
  }

  Component.onCompleted: Qt.callLater(requestPaint)
}
