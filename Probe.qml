import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// One SSH poll of nvidia-smi. The last good sample stays on screen when
// the link drops, and failures back off so a down host is not hit every
// two seconds. Host and user come from the widget settings.
Item {
  id: root

  property bool active: true
  property string host: ""
  property string user: ""
  property string identityFile: ""
  property int pollMs: 2000
  property int warnC: 83
  property int hotC: 90
  property int delayMs: 2000
  property int failStreak: 0

  property var gpus: Model.placeholders(2)
  property var history: ({})
  property var emptySamples: []
  property string driver: ""
  property string status: "setup"
  property string lastError: ""
  property double updatedAt: 0
  property double now: 0

  readonly property bool linked: status === "live"
  readonly property bool ready: host !== "" && user !== ""
  readonly property string identityPath: expandHome(identityFile)
  readonly property string target: user + "@" + host
  readonly property var sshCommand: sshArgs([Model.remoteScript()])
  readonly property string tooltip: Model.tooltip(host, gpus, status, updatedAt, now, lastError)
  readonly property var watch: ready
    ? Model.watchLine(gpus, warnC, hotC, linked)
    : ({ text: "Set host and user on this widget in shell.json.", level: "offline" })
  readonly property string ageLabel: Model.statusLabel(status, updatedAt, now)

  function expandHome(path) {
    var home = Quickshell.env("HOME") || ""
    var cleaned = Model.cleanPath(path)
    if (!cleaned) return ""
    if (cleaned === "~") return home
    if (cleaned.indexOf("~/") === 0) return home + cleaned.slice(1)
    return cleaned
  }

  function sshArgs(remoteArgs) {
    var args = [
      "ssh",
      "-o", "BatchMode=yes",
      "-o", "ConnectTimeout=4",
      "-o", "ConnectionAttempts=1",
      "-o", "LogLevel=ERROR"
    ]
    if (identityPath) {
      args.push("-i")
      args.push(identityPath)
      args.push("-o")
      args.push("IdentitiesOnly=yes")
    }
    args.push(target)
    var extra = remoteArgs || []
    for (var i = 0; i < extra.length; i++) args.push(extra[i])
    return args
  }

  function configure(settings) {
    var incoming = settings || {}
    var nextPoll = Model.clampInt(incoming.pollMs, 2000, 1000, 60000)
    var nextWarn = Model.clampInt(incoming.warnC, 83, 40, 110)
    var nextHot = Model.clampInt(incoming.hotC, 90, 45, 120)
    if (nextHot <= nextWarn) nextHot = nextWarn + 1
    var pollChanged = nextPoll !== pollMs
    host = Model.cleanToken(incoming.host, "")
    user = Model.cleanToken(incoming.user, "")
    identityFile = Model.cleanPath(incoming.identityFile)
    pollMs = nextPoll
    warnC = nextWarn
    hotC = nextHot
    if (!ready) {
      status = updatedAt > 0 ? "stale" : "setup"
      return
    }
    if (status === "setup") status = "connecting"
    if (pollChanged) arm(pollMs)
  }

  function samples(index) {
    var book = history
    var row = book ? book[String(index)] : null
    return row ? row : emptySamples
  }

  function remember(list) {
    var next = {}
    var prev = history || {}
    for (var key in prev) next[key] = prev[key]
    var stamp = Date.now()
    for (var i = 0; i < list.length; i++) {
      var gpu = list[i]
      if (!gpu || gpu.temp === null || gpu.temp === undefined) continue
      var id = String(gpu.index)
      var row = (next[id] || []).slice()
      row.push({ temp: gpu.temp, util: gpu.utilGpu, power: gpu.power, t: stamp })
      if (row.length > 150) row = row.slice(row.length - 150)
      next[id] = row
    }
    history = next
  }

  function arm(ms) {
    delayMs = Math.max(1000, ms)
    ticker.restart()
  }

  function poll() {
    if (!active || !ready || proc.running) return
    proc.launch()
  }

  function ingest(code, stdout, stderr) {
    var parsed = Model.parse(stdout)
    if (code === 0 && parsed.ok) {
      gpus = parsed.gpus
      driver = parsed.driver || driver
      remember(parsed.gpus)
      updatedAt = Date.now()
      now = updatedAt
      status = "live"
      lastError = ""
      failStreak = 0
      arm(pollMs)
      return
    }
    failStreak = Math.min(6, failStreak + 1)
    status = updatedAt > 0 ? "stale" : "down"
    lastError = Model.cleanError(stderr, code, parsed.error)
    now = Date.now()
    arm(Math.min(30000, pollMs * Math.pow(2, failStreak)))
  }

  function smiArgs() {
    return sshArgs(["nvidia-smi", "-l", "1"])
  }

  Timer {
    id: ticker
    interval: Math.max(1000, root.delayMs)
    repeat: true
    running: root.active && root.ready
    triggeredOnStart: true
    onTriggered: root.poll()
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.active
    triggeredOnStart: true
    onTriggered: root.now = Date.now()
  }

  Process {
    id: proc

    property bool answered: false

    stdout: StdioCollector { id: out; waitForEnd: true }
    stderr: StdioCollector { id: errPipe; waitForEnd: true }

    function launch() {
      answered = false
      command = root.sshCommand
      running = true
    }

    onExited: function(code) {
      answered = true
      root.ingest(code, out.text, errPipe.text)
    }

    onRunningChanged: {
      if (running || answered) return
      answered = true
      root.ingest(-1, "", "ssh did not start")
    }
  }

  Timer {
    interval: 8000
    repeat: false
    running: proc.running
    onTriggered: if (proc.running) proc.running = false
  }
}
