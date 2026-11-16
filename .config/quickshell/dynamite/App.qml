pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Bluetooth

Scope {
    id: app
    function teach(keys) {
        Quickshell.execDetached(["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.Notify", "Dynamite", "0", "", "next time: " + keys, "", "[]", "{}", "1500"]);
    }
    readonly property string preferredScreen: Quickshell.env("DYNAMITE_BAR_SCREEN") || ""
    readonly property var barScreen: Quickshell.screens.find(s => s.name === preferredScreen)
        || Quickshell.screens.find(s => /^(eDP|LVDS|DSI)-/.test(s.name)) || Quickshell.screens[0] || null
    // Capture the invoking monitor once so pointer movement cannot move an open panel.
    property string panelScreenName: ""
    readonly property var panelScreen: Quickshell.screens.find(s => s.name === panelScreenName) || barScreen
    function targetPanelScreen() { panelScreenName = Hyprland.focusedMonitor?.name || barScreen?.name || ""; }
    function settings(kind) {
        const command = data.settings?.[kind];
        if (command?.length) external(command);
    }
    property string panel: "compact"
    property bool overviewPinned: false
    property bool joinActive: false
    readonly property bool barJoined: joinActive && panelScreen?.name === barScreen?.name
    property int hoveredWorkspace: 0
    property real joinProgress: 0
    // Slow-motion factor for filming animations via IPC; always 1 in normal use.
    property real motionScale: 1
    property real dropProgress: 0
    signal dismissOverview()
    readonly property bool modal: panel === "overview" ? overviewPinned : ["themes", "wallpapers"].includes(panel)
    property bool reducedMotion: Quickshell.env("DYNAMITE_REDUCED_MOTION") === "1"
    property bool keepAwake: false
    property bool barsShown: true
    // Set by the right bar from its natural width; the left bar matches it (one direction only).
    property int sideWidth: 612
    property string error: ""
    property bool busy: false
    property var queue: []
    property real cpuUsage: 0
    property var healthSample: ({})
    property var healthLatches: ({})
    property var healthLevels: ({temp: 0, memory: 0, disk: 0, cpu: 0})
    readonly property real memoryUsed: healthSample.memory?.MemTotal > 0
        ? 100 * (1 - healthSample.memory.MemAvailable / healthSample.memory.MemTotal) : 0
    readonly property string healthCulprit: ["temp", "memory", "disk", "cpu"].reduce((worst, name) =>
        healthLevels[name] > (healthLevels[worst] || 0) ? name : worst, "")
    readonly property int healthLevel: healthLevels[healthCulprit] || 0
    readonly property string healthLabel: healthCulprit === "temp" ? Math.round(healthSample.temperature) + "°C"
        : healthCulprit === "memory" ? "RAM " + Math.round(memoryUsed) + "%"
        : healthCulprit === "disk" ? (healthSample.disk?.mount === "/home" ? "/home " : "/ ") + Math.round(healthSample.disk?.used || 0) + "%"
        : healthCulprit === "cpu" ? "CPU " + Math.round(cpuUsage) + "%" : ""
    readonly property string healthHint: !healthLevel ? "System OK" : healthCulprit === "temp"
        ? "CPU temperature " + (healthLevel === 2 ? "critical" : "high")
        : healthCulprit === "disk" ? "Disk " + (healthSample.disk?.mount || "/") + " almost full"
        : (healthCulprit === "memory" ? "Memory" : "CPU") + " pressure " + (healthLevel === 2 ? "critical" : "high")
    function healthColor(level) { return level === 2 ? "#e18593" : level === 1 ? "#dfb479" : "transparent"; }
    function updateHealth(sample) {
        healthSample = sample;
        cpuUsage = sample.total;
        const available = sample.memory?.MemTotal > 0 && sample.memory?.MemAvailable !== undefined
            ? 100 * sample.memory.MemAvailable / sample.memory.MemTotal : null;
        const limit = sample.temperatureLimit || 100;
        // Each threshold recovers independently, allowing critical to settle back to warning.
        const rules = [
            ["cpu", sample.pressure?.cpu?.some?.avg60, 20, 50, 5],
            ["memory", sample.pressure?.memory?.some?.avg10, 10, null, 3],
            ["memory", sample.pressure?.memory?.full?.avg10, null, 5, 1],
            ["memory", available === null ? null : 100 - available, 90, 95, 3],
            ["temp", sample.temperature, limit - 15, limit - 5, 3],
            ["disk", sample.disk?.used, 90, 95, 2]
        ];
        const now = Date.now(), latches = {}, levels = {temp: 0, memory: 0, disk: 0, cpu: 0};
        rules.forEach((rule, index) => {
            for (let level = 1; level <= 2; level++) {
                const threshold = rule[level + 1], value = rule[1], key = index + ":" + level;
                if (threshold === null) continue;
                const old = healthLatches[key] || {active: false, below: 0};
                let active = old.active, below = old.below;
                // The available-memory fallback is strictly below 10% / 5%.
                const tripped = value != null && (index === 3 ? value > threshold : value >= threshold);
                if (tripped) { active = true; below = 0; }
                else if (active && value != null && value < threshold - rule[4]) {
                    if (!below) below = now;
                    if (now - below >= 30000) { active = false; below = 0; }
                } else below = 0;
                latches[key] = {active: active, below: below};
                if (active) levels[rule[0]] = Math.max(levels[rule[0]], level);
            }
        });
        healthLatches = latches;
        healthLevels = levels;
    }
    property var data: ({audio: {}, brightness: {}, network: {}})
    property var palettes: [{id:"tidepool", name:"Tidepool", bg:"#0b1112", surface:"#192022", text:"#d9e5d9", muted:"#8fa5a0", accent:"#9bcac1", swatches:["#9bcac1","#d9e5d9","#8fa5a0"]}]
    property string appliedTheme: "tidepool"
    readonly property var palette: palettes.find(t => t.id === appliedTheme) || palettes[0]
    property var wallpapers: ({morning:[], day:[], evening:[], night:[]})
    property string appliedWallpaper: ""
    property string previewWallpaper: ""
    readonly property var mediaPlayers: {
        const players = Mpris.players.values;
        const browserBridge = players.find(p => p.dbusName === "org.mpris.MediaPlayer2.plasma-browser-integration");
        // The browser's duplicate exports tab titles with unread counts instead of track metadata.
        return browserBridge?.identity ? players.filter(p => p === browserBridge || p.identity !== browserBridge.identity) : players;
    }
    readonly property var player: mediaPlayers.find(p => p.isPlaying) || mediaPlayers[0] || null
    readonly property bool hasBattery: UPower.displayDevice?.isPresent || false
    readonly property string battery: UPower.displayDevice?.isPresent ? Math.round(UPower.displayDevice.percentage * 100) + "%" : ""
    // Same level glyphs as the Waybar battery pill.
    readonly property string batteryGlyph: !UPower.displayDevice?.isPresent ? "" : UPower.displayDevice.state === UPowerDeviceState.Charging ? "󰂄"
        : ["󰁺","󰁻","󰁼","󰁽","󰁾","󰁿","󰂀","󰂁","󰂂","󰁹"][Math.min(9, Math.floor(UPower.displayDevice.percentage * 10))]
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property string helper: Qt.resolvedUrl("bridge.py").toString().replace("file://", "")
    readonly property string home: Quickshell.env("HOME")
    // Vertical rhythm: Hyprland's outer gap above the bars and between bars and windows.
    property int gap: 8
    readonly property int barHeight: 38
    readonly property int topHeight: gap + barHeight
    // Optical nudge: the bright window border makes the gap below read smaller, so the bars sit 1 px higher.
    readonly property int barTop: gap - 1
    // Horizontal rhythm: every bar slot is its content plus this padding on each side.
    readonly property int itemPadding: 13
    // Bar backgrounds at rest; the hovered/open item and its menus are fully opaque. Icons and text are never faded.
    readonly property real barAlpha: 0.8
    // palette.bg is a string; convert once so every bar surface shares the exact same translucent fill.
    readonly property color bgColor: palette.bg
    readonly property color barFill: Qt.rgba(bgColor.r, bgColor.g, bgColor.b, barAlpha)
    function isoWeek(date) {
        const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
        return Math.ceil((((d - new Date(Date.UTC(d.getUTCFullYear(), 0, 1))) / 86400000) + 1) / 7);
    }
    function longDate(date) { return Qt.formatDate(date, "dddd d MMMM yyyy") + " · Week " + isoWeek(date); }
    Process {
        running: true; command: ["hyprctl", "getoption", "general:gaps_out", "-j"]
        stdout: StdioCollector { onStreamFinished: { try { const g = parseInt(JSON.parse(text).css); if (g >= 0) app.gap = g; } catch (e) {} } }
    }

    // The one interaction tint for every surface (bridge.py exports the same values to Waybar/rofi).
    function tone(base, hovered, pressed) {
        return pressed ? Qt.tint(base, "#55" + palette.accent.slice(1)) : hovered ? Qt.tint(base, "#30" + palette.accent.slice(1)) : base;
    }
    function openBarOverview(workspace) {
        finishClose();
        hoveredWorkspace = workspace || 0;
        hoverOverview();
        pinOverview();
    }
    function pinOverview() {
        overviewPinned=true;
        if (!joinActive) { joinProgress=0; dropProgress=0; joinActive=true; }
    }
    function hoverOverview() { if (panel === "compact") { overviewPinned=false; joinProgress=0; dropProgress=0; panel="overview"; joinActive=true; } }
    function toggle(name) {
        if (name === "launcher") name="overview";
        if (!["compact","overview","themes","wallpapers"].includes(name)) return;
        if (name === "overview" && panel === "overview" && !overviewPinned) { targetPanelScreen(); pinOverview(); return; }
        if (panel === name) { close(); return; }
        if (name === "compact") { close(); return; }
        if (!modal) targetPanelScreen();
        // Keep keyboard focus while switching between open centre panels.
        if (name === "overview") overviewPinned = true;
        panel = name;
        overviewPinned = name === "overview";
        if (!joinActive) { joinProgress=0; dropProgress=0; joinActive=true; }
    }
    function finishClose() { panel="compact"; overviewPinned=false; joinActive=false; hoveredWorkspace=0; joinProgress=0; dropProgress=0; panelScreenName=""; }
    function close() { if (joinActive) dismissOverview(); else finishClose(); }
    function refresh() { if (!snapshot.running) snapshot.running = true; }
    function external(command) { close(); Quickshell.execDetached(command); }
    function action(name, value) {
        if (name === "focus") { Notifications.toggleDnd(); return; }
        if (["notification-dismiss", "notification-invoke", "notifications-clear"].includes(name)) { Notifications.action(name, value); return; }
        // Replace queued slider writes so rapid dragging always ends at the latest value.
        let pending = queue.filter(j => !(j[0] === name && ["volume","brightness"].includes(name)));
        pending.push(value === undefined ? [name] : [name, String(value)]);
        queue = pending;
        drain();
    }
    function drain() {
        if (writer.running || queue.length === 0) return;
        let next = queue[0]; queue = queue.slice(1); busy = true; error = "";
        writer.command = ["python3", helper, "action"].concat(next);
        writer.running = true;
    }
    function receive(text) {
        try {
            const result = JSON.parse(text);
            if (!result.ok) { error = result.error || "The action failed"; return; }
            if (result.dnd !== undefined) Notifications.dnd = result.dnd;
            if (result.themes) palettes = result.themes;
            if (result.appliedTheme) appliedTheme = result.appliedTheme;
            if (result.wallpapers && JSON.stringify(result.wallpapers) !== JSON.stringify(wallpapers)) wallpapers = result.wallpapers;
            if (result.appliedWallpaper !== undefined) appliedWallpaper = result.appliedWallpaper;
            if (result.reducedMotion !== undefined) reducedMotion = result.reducedMotion;
        } catch (e) { error = "Could not read the service response"; }
    }
    onPanelChanged: {
        if (panel !== "wallpapers") previewWallpaper = "";
        error = "";
        if (panel !== "compact") refresh();
        if (panel === "wallpapers" && !wallpaperList.running) wallpaperList.running = true;
    }
    Process {
        command: ["python3", app.helper, "cpu"]; running: true
        stdout: SplitParser { onRead: line => {
            try { app.updateHealth(JSON.parse(line)); }
            catch (e) { app.error = "Could not read CPU usage"; }
        } }
    }
    Process {
        id: snapshot
        command: ["python3", app.helper, "snapshot"]
        stdout: StdioCollector { onStreamFinished: {
            try { const result = JSON.parse(text); if (result.ok) { app.data = result; app.appliedWallpaper = result.appliedWallpaper; } }
            catch (e) { app.error = "Could not read desktop services"; }
        } }
    }
    Process {
        id: writer
        stdout: StdioCollector { onStreamFinished: app.receive(text) }
        onExited: { app.busy = false; app.refresh(); Qt.callLater(app.drain); }
    }
    Process { id: catalog; command: ["python3", app.helper, "catalog"]; running: true; stdout: StdioCollector { onStreamFinished: app.receive(text) } }
    Process { id: wallpaperList; command: ["python3", app.helper, "wallpapers"]; stdout: StdioCollector { onStreamFinished: app.receive(text) } }
    Process { command: ["python3", app.helper, "motion"]; running: true; stdout: StdioCollector { onStreamFinished: app.receive(text) } }
    Process {
        command: ["pactl", "subscribe"]; running: app.data.audio?.backend === "pactl"
        stdout: SplitParser { onRead: line => { if (line.includes("sink") || line.includes("server")) debounce.restart(); } }
    }
    Process { command: ["nmcli", "monitor"]; running: app.data.network?.backend === "nmcli"; stdout: SplitParser { onRead: debounce.restart() } }
    Timer { id: debounce; interval: 100; onTriggered: app.refresh() }
    Timer { interval: app.panel === "compact" && app.data.audio?.backend !== "wpctl" ? 10000 : 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: app.refresh() }
    FileView {
        path: app.home + "/.cache/hypr-wallpaper/state"; watchChanges: true
        onFileChanged: { reload(); app.refresh(); }
    }
}
