pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Bluetooth

Scope {
    id: app
    property string panel: "compact"
    readonly property bool modal: ["launcher", "controls", "themes", "wallpapers"].includes(panel)
    property bool reducedMotion: Quickshell.env("DYNAMITE_REDUCED_MOTION") === "1"
    property bool keepAwake: false
    property bool barsShown: true
    property string error: ""
    property bool busy: false
    property var queue: []
    property var data: ({audio: {}, brightness: {}, network: {}, notifications: {items: []}})
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
    readonly property string battery: UPower.displayDevice?.isPresent ? Math.round(UPower.displayDevice.percentage * 100) + "%" : ""
    // Same level glyphs as the Waybar battery pill.
    readonly property string batteryGlyph: !UPower.displayDevice?.isPresent ? "" : UPower.displayDevice.state === UPowerDeviceState.Charging ? "󰂄"
        : ["󰁺","󰁻","󰁼","󰁽","󰁾","󰁿","󰂀","󰂁","󰂂","󰁹"][Math.min(9, Math.floor(UPower.displayDevice.percentage * 10))]
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property string helper: Qt.resolvedUrl("bridge.py").toString().replace("file://", "")
    readonly property string home: Quickshell.env("HOME")

    // The one interaction tint for every surface (bridge.py exports the same values to Waybar/rofi).
    function tone(base, hovered, pressed) {
        return pressed ? Qt.tint(base, "#55" + palette.accent.slice(1)) : hovered ? Qt.tint(base, "#30" + palette.accent.slice(1)) : base;
    }
    function toggle(name) {
        if (!["compact","status","launcher","controls","themes","wallpapers"].includes(name)) return;
        panel = panel === name ? "compact" : name;
    }
    function close() { panel = "compact"; }
    function refresh() { if (!snapshot.running) snapshot.running = true; }
    function external(command) { close(); Quickshell.execDetached(command); }
    function action(name, value) {
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
        command: ["pactl", "subscribe"]; running: true
        stdout: SplitParser { onRead: line => { if (line.includes("sink") || line.includes("server")) debounce.restart(); } }
    }
    Process { command: ["nmcli", "monitor"]; running: true; stdout: SplitParser { onRead: debounce.restart() } }
    Timer { id: debounce; interval: 100; onTriggered: app.refresh() }
    Timer { interval: app.panel === "compact" ? 10000 : 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: app.refresh() }
    FileView {
        path: app.home + "/.cache/hypr-wallpaper/state"; watchChanges: true
        onFileChanged: { reload(); app.refresh(); }
    }
}
