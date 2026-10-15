// Pure parsing and presentation for an nvidia-smi poll over SSH.
// Temperatures are the thing this widget exists to watch. The default
// warn and hot marks match a 3090, and each install can change them.

var GPU_FIELDS = [
  "index",
  "uuid",
  "name",
  "temperature.gpu",
  "utilization.gpu",
  "utilization.memory",
  "memory.used",
  "memory.total",
  "power.draw",
  "power.limit",
  "fan.speed",
  "clocks.sm",
  "clocks.max.sm",
  "clocks.mem",
  "pstate",
  "clocks_throttle_reasons.hw_thermal_slowdown",
  "clocks_throttle_reasons.sw_thermal_slowdown",
  "clocks_throttle_reasons.hw_slowdown",
  "driver_version",
  "pci.bus_id"
]

var COLORS = {
  offline: "#8b9098",
  cool: "#7ec8e3",
  warm: "#9ddeaf",
  busy: "#f0c14a",
  warn: "#ff8a3d",
  hot: "#ff4b4b"
}

function remoteScript() {
  return "LC_ALL=C nvidia-smi --query-gpu=" + GPU_FIELDS.join(",")
    + " --format=csv,noheader,nounits; echo ---; LC_ALL=C nvidia-smi --query-compute-apps=gpu_uuid,pid,process_name,used_gpu_memory --format=csv,noheader,nounits"
}

function clamp(n, lo, hi) {
  if (n < lo) return lo
  if (n > hi) return hi
  return n
}

function clampInt(v, fallback, lo, hi) {
  var n = parseInt(v, 10)
  if (!isFinite(n)) n = fallback
  return clamp(n, lo, hi)
}

function cleanToken(v, fallback) {
  var s = String(v === undefined || v === null ? "" : v).replace(/^\s+|\s+$/g, "")
  if (!/^[A-Za-z0-9._-]+$/.test(s)) return fallback
  return s
}

function cleanPath(v) {
  var s = String(v === undefined || v === null ? "" : v).replace(/^\s+|\s+$/g, "")
  if (!s) return ""
  if (s.indexOf("..") !== -1) return ""
  if (!/^[A-Za-z0-9._~/-]+$/.test(s)) return ""
  return s
}

function num(v) {
  if (v === null || v === undefined) return null
  var s = String(v).replace(/^\s+|\s+$/g, "")
  if (!s || s === "[N/A]" || s === "N/A" || s === "[Not Supported]" || s === "[Unknown Error]") return null
  var n = Number(s)
  return isFinite(n) ? n : null
}

function isActive(v) {
  return String(v === undefined || v === null ? "" : v).replace(/^\s+|\s+$/g, "").toLowerCase() === "active"
}

function splitCsv(line) {
  var out = []
  var cur = ""
  var quoted = false
  for (var i = 0; i < line.length; i++) {
    var c = line.charAt(i)
    if (quoted) {
      if (c === '"') quoted = false
      else cur += c
    } else if (c === '"') {
      quoted = true
    } else if (c === ",") {
      out.push(cur.replace(/^\s+|\s+$/g, ""))
      cur = ""
    } else {
      cur += c
    }
  }
  out.push(cur.replace(/^\s+|\s+$/g, ""))
  return out
}

function splitBlocks(text) {
  var lines = String(text || "").split(/\r?\n/)
  var gpuLines = []
  var procLines = []
  var procs = false
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].replace(/^\s+|\s+$/g, "")
    if (!line) continue
    if (line === "---") {
      procs = true
      continue
    }
    if (procs) procLines.push(line)
    else gpuLines.push(line)
  }
  return { gpuLines: gpuLines, procLines: procLines }
}

function shortGpu(name) {
  var s = String(name || "")
  var match = s.match(/RTX\s+\d+\S*/i)
  if (match) return match[0].replace(/\s+/, " ")
  s = s.replace(/^NVIDIA\s+/i, "").replace(/^GeForce\s+/i, "")
  return s || "GPU"
}

function heroTitle(gpu) {
  return String(gpu && gpu.shortName || "GPU").replace(/^RTX\s+/i, "")
}

function kicker(gpu) {
  var name = String(gpu && gpu.name || "")
  if (/rtx/i.test(name)) return "GEFORCE RTX"
  if (/radeon|instinct/i.test(name)) return "AMD"
  return "NVIDIA"
}

function shortBus(bus) {
  var match = String(bus || "").match(/([0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-7])$/)
  return match ? match[1] : String(bus || "")
}

function shortProc(name) {
  var base = String(name || "").split("/").pop()
  base = base.replace(/^VLLM::Worker_/i, "vLLM ")
  base = base.replace(/_/g, " ")
  return base || "process"
}

function placeholder(index) {
  return {
    index: index,
    uuid: "",
    name: "NVIDIA GPU",
    shortName: "GPU",
    bus: "",
    temp: null,
    utilGpu: null,
    utilMem: null,
    memUsed: null,
    memTotal: null,
    power: null,
    powerLimit: null,
    fan: null,
    smClock: null,
    smMax: null,
    memClock: null,
    pstate: "",
    throttle: false,
    throttleWhy: "",
    driver: "",
    offline: true,
    procs: []
  }
}

function placeholders(count) {
  var out = []
  var n = count > 0 ? count : 2
  for (var i = 0; i < n; i++) out.push(placeholder(i))
  return out
}

function parseGpuLine(line) {
  var cols = splitCsv(line)
  if (cols.length < 4 || !/^\d+$/.test(cols[0])) return null
  var reasons = []
  if (isActive(cols[15])) reasons.push("thermal")
  if (isActive(cols[16])) reasons.push("software thermal")
  if (isActive(cols[17])) reasons.push("slowdown")
  var name = cols[2] || "GPU"
  return {
    index: parseInt(cols[0], 10),
    uuid: cols[1] || "",
    name: name,
    shortName: shortGpu(name),
    bus: shortBus(cols[19] || ""),
    temp: num(cols[3]),
    utilGpu: num(cols[4]),
    utilMem: num(cols[5]),
    memUsed: num(cols[6]),
    memTotal: num(cols[7]),
    power: num(cols[8]),
    powerLimit: num(cols[9]),
    fan: num(cols[10]),
    smClock: num(cols[11]),
    smMax: num(cols[12]),
    memClock: num(cols[13]),
    pstate: cols[14] || "",
    throttle: reasons.length > 0,
    throttleWhy: reasons.join(", "),
    driver: cols[18] || "",
    offline: false,
    procs: []
  }
}

function parseProcLine(line) {
  var cols = splitCsv(line)
  if (cols.length < 4 || cols[0].indexOf("GPU-") !== 0) return null
  var name = cols.slice(2, cols.length - 1).join(", ")
  var pid = num(cols[1])
  return {
    uuid: cols[0],
    pid: pid === null ? 0 : pid,
    name: name,
    shortName: shortProc(name),
    mem: num(cols[cols.length - 1])
  }
}

function parse(text) {
  var blocks = splitBlocks(text)
  var gpus = []
  var byUuid = {}
  var driver = ""
  for (var i = 0; i < blocks.gpuLines.length; i++) {
    var gpu = parseGpuLine(blocks.gpuLines[i])
    if (!gpu) continue
    if (!driver && gpu.driver) driver = gpu.driver
    if (gpu.uuid) byUuid[gpu.uuid] = gpu
    gpus.push(gpu)
  }
  for (var j = 0; j < blocks.procLines.length; j++) {
    var proc = parseProcLine(blocks.procLines[j])
    if (!proc) continue
    var owner = byUuid[proc.uuid]
    if (owner) owner.procs.push(proc)
  }
  gpus.sort(function(a, b) { return a.index - b.index })
  return {
    ok: gpus.length > 0,
    gpus: gpus,
    driver: driver,
    error: gpus.length > 0 ? "" : "nvidia-smi returned no cards"
  }
}

function band(temp, warnC, hotC) {
  if (temp === null || temp === undefined || !isFinite(temp)) return "offline"
  if (temp >= hotC) return "hot"
  if (temp >= warnC) return "warn"
  if (temp >= 70) return "busy"
  if (temp >= 55) return "warm"
  return "cool"
}

function colorFor(name) {
  return COLORS[name] || COLORS.offline
}

function fraction(used, total) {
  if (used === null || used === undefined || !total || !isFinite(used) || !isFinite(total)) return 0
  return clamp(used / total, 0, 1)
}

function memFraction(gpu) {
  if (!gpu) return 0
  return fraction(gpu.memUsed, gpu.memTotal)
}

function powerFraction(gpu) {
  if (!gpu) return 0
  return fraction(gpu.power, gpu.powerLimit)
}

function spinPercent(gpu) {
  if (!gpu || gpu.offline) return 0
  if (gpu.fan !== null && gpu.fan !== undefined && isFinite(gpu.fan)) return clamp(gpu.fan, 0, 100)
  if (gpu.utilGpu !== null && gpu.utilGpu !== undefined && isFinite(gpu.utilGpu)) return clamp(gpu.utilGpu * 0.55, 0, 100)
  return 0
}

function utilOf(gpu) {
  if (!gpu || gpu.utilGpu === null || gpu.utilGpu === undefined || !isFinite(gpu.utilGpu)) return 0
  return clamp(gpu.utilGpu, 0, 100)
}

function memColor(amount) {
  if (amount >= 0.92) return "#e07a9a"
  if (amount >= 0.75) return "#e2b656"
  return "#8eb4c8"
}

function powerColor(amount) {
  if (amount >= 0.95) return "#e2b656"
  if (amount >= 0.7) return "#9ddeaf"
  return "#8eb4c8"
}

function utilColor(util) {
  if (util === null || util === undefined || !isFinite(util)) return "#5c6370"
  if (util >= 90) return "#f0c14a"
  if (util >= 40) return "#9ddeaf"
  return "#7f8b99"
}

function fmt(n, suffix) {
  if (n === null || n === undefined || !isFinite(Number(n))) return "—"
  return String(Math.round(Number(n))) + (suffix || "")
}

function gib(mib) {
  if (mib === null || mib === undefined || !isFinite(mib)) return "—"
  return (mib / 1024).toFixed(1)
}

function pair(used, total, unit) {
  return gib(used) + " / " + gib(total) + " " + unit
}

function clockPair(current, max) {
  if (current === null || current === undefined) return "—"
  if (max) return fmt(current, "") + " / " + fmt(max, " MHz")
  return fmt(current, " MHz")
}

function age(updatedAt, now) {
  if (!updatedAt || !now) return ""
  var seconds = Math.max(0, Math.round((now - updatedAt) / 1000))
  if (seconds < 2) return "just now"
  if (seconds < 90) return seconds + "s ago"
  return Math.round(seconds / 60) + "m ago"
}

function hottest(gpus) {
  var best = null
  for (var i = 0; i < (gpus ? gpus.length : 0); i++) {
    var gpu = gpus[i]
    if (!gpu || gpu.temp === null || gpu.temp === undefined || !isFinite(gpu.temp)) continue
    if (!best || gpu.temp > best.temp) best = gpu
  }
  return best
}

function watchLine(gpus, warnC, hotC, linked) {
  if (!linked) return { text: "No live reading from the host.", level: "offline" }
  var hot = hottest(gpus)
  if (!hot) return { text: "nvidia-smi returned no cards.", level: "offline" }
  var temp = Math.round(hot.temp)
  var who = "GPU " + hot.index
  if (hot.throttle) {
    var why = hot.throttleWhy ? " (" + hot.throttleWhy + ")" : ""
    return { text: who + " is thermal throttling at " + temp + "°" + why + ".", level: "hot" }
  }
  if (hot.temp >= hotC) return { text: who + " is hot at " + temp + "°. Give it some air.", level: "hot" }
  if (hot.temp >= warnC) return { text: who + " is at " + temp + "°, at the " + warnC + "° line.", level: "warn" }
  var powerNote = ""
  if (hot.power !== null && hot.powerLimit && hot.power / hot.powerLimit >= 0.95)
    powerNote = " Pinned at its " + Math.round(hot.powerLimit) + "W cap."
  if (hot.utilGpu !== null && hot.utilGpu >= 70)
    return { text: who + " is at " + temp + "° under load." + powerNote + " Under the " + warnC + "° line.", level: band(hot.temp, warnC, hotC) }
  return { text: "Hottest is " + who + " at " + temp + "°." + powerNote, level: band(hot.temp, warnC, hotC) }
}

function procSummary(procs) {
  if (!procs || !procs.length) return ""
  var lines = []
  var shown = Math.min(procs.length, 3)
  for (var i = 0; i < shown; i++) {
    var proc = procs[i]
    lines.push(proc.shortName + "  ·  " + gib(proc.mem) + " GB  ·  pid " + proc.pid)
  }
  if (procs.length > shown) lines.push("+" + (procs.length - shown) + " more")
  return lines.join("\n")
}

function tooltip(host, gpus, status, updatedAt, now, error) {
  if (status === "setup") return "Set host and user on this widget in ~/.config/omarchy/shell.json"
  var lines = [String(host || "gpu")]
  var list = gpus || []
  for (var i = 0; i < list.length; i++) {
    var gpu = list[i]
    if (!gpu || gpu.temp === null || gpu.temp === undefined) {
      lines.push("GPU " + (gpu ? gpu.index : i) + "   —")
      continue
    }
    var job = (gpu.procs && gpu.procs[0]) ? gpu.procs[0].shortName : "idle"
    lines.push(
      "GPU " + gpu.index
      + "   " + fmt(gpu.temp, "°C")
      + "   " + fmt(gpu.utilGpu, "%")
      + "   " + fmt(gpu.power, "W")
      + "   " + gib(gpu.memUsed) + "/" + gib(gpu.memTotal) + " GB"
      + "   fan " + fmt(gpu.fan, "%")
      + "   " + job
    )
  }
  if (status !== "live") {
    var when = age(updatedAt, now)
    if (status === "connecting") lines.push("connecting…")
    else lines.push("last reading " + (when || "never") + (error ? " — " + error : ""))
  }
  return lines.join("\n")
}

function cleanError(stderr, code, parseError) {
  var line = String(stderr || "").replace(/\s+/g, " ").replace(/^\s+|\s+$/g, "")
  if (line.length > 160) line = line.slice(0, 160)
  if (line) return line
  if (parseError) return parseError
  if (code === -1) return "ssh did not start"
  return "ssh exited " + code
}

function statusLabel(status, updatedAt, now) {
  if (status === "setup") return "set host"
  if (status === "live") return "live · " + (age(updatedAt, now) || "just now")
  if (status === "connecting") return "connecting"
  if (status === "stale") return "stale · " + (age(updatedAt, now) || "no reading")
  return "offline"
}
