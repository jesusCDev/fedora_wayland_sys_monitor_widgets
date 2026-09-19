// Pure helpers shared by main.qml and the offscreen self-check
.pragma library


// Bodies may carry the spec's <b><i><u><a> markup plus entities; we show and
// copy the plain form. Never RichText: notification text is attacker-controlled.
function stripHtml(s) {
    return String(s || "")
        .replace(/<br\s*\/?>/gi, "\n")
        .replace(/<[^>]+>/g, "")
        .replace(/&nbsp;/g, " ").replace(/&quot;/g, '"').replace(/&#39;/g, "'")
        .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&")
        .replace(/[ \t]+/g, " ").replace(/\s*\n\s*/g, "\n").trim()
}

// One colour per app: hue from a hash of the name in 24 steps of 15°, with
// saturation/lightness fixed in a band that stays readable on the dark theme
// (lightness 62% never comes near the ~#1b1e20 popup or #0c0c10 panel ground).
// QML colour bindings need hex, not hsl(), hence the conversion.
function appColor(name) {
    var h = 5381
    for (var i = 0; i < name.length; i++) h = ((h * 33) ^ name.charCodeAt(i)) | 0
    return hslHex((Math.abs(h) % 24) * 15, 0.70, 0.62)
}

function hslHex(hue, s, l) {
    var c = (1 - Math.abs(2 * l - 1)) * s, x = c * (1 - Math.abs((hue / 60) % 2 - 1)), m = l - c / 2
    var r = 0, g = 0, b = 0
    if (hue < 60) { r = c; g = x } else if (hue < 120) { r = x; g = c } else if (hue < 180) { g = c; b = x }
    else if (hue < 240) { g = x; b = c } else if (hue < 300) { r = x; b = c } else { r = c; b = x }
    function hx(v) { var n = Math.round((v + m) * 255); return (n < 16 ? "0" : "") + n.toString(16) }
    return "#" + hx(r) + hx(g) + hx(b)
}

function clip(s, n) {
    s = String(s || "")
    return s.length > n ? s.substring(0, n - 1) + "…" : s
}

// ponytail: 4-digit years and numbers inside URLs match as codes; tighten if noisy
function extractChips(text) {
    var out = [], seen = {}
    function add(label, value) {
        if (seen[value] || out.length >= 4) return
        seen[value] = true
        out.push({ label: label, value: value })
    }
    var urls = text.match(/https?:\/\/[^\s<>"']+/g) || []
    for (var i = 0; i < urls.length; i++) {
        var u = urls[i].replace(/[.,;:!?)]+$/, "")
        add(clip(u.replace(/^https?:\/\/(www\.)?/, ""), 24), u)
    }
    var mails = text.match(/[\w.+-]+@[\w-]+\.[\w.-]+/g) || []
    for (var j = 0; j < mails.length; j++) { var m = mails[j].replace(/\.+$/, ""); add(m, m) }
    var codes = text.match(/\b\d{4,8}\b/g) || []
    for (var k = 0; k < codes.length; k++) add(codes[k], codes[k])
    return out
}

function shQuote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

// seq keeps every copy a distinct executable-DataSource key
function copyCmd(s, seq) { return "wl-copy -- " + shQuote(s) + " >/dev/null 2>&1 #" + seq }

function relTime(now, created) {
    var t = created instanceof Date ? created.getTime() : new Date(created).getTime()
    var s = Math.max(0, (now - t) / 1000)
    if (s < 60) return "now"
    if (s < 3600) return Math.floor(s / 60) + "m"
    if (s < 86400) return Math.floor(s / 3600) + "h"
    return Math.floor(s / 86400) + "d"
}
