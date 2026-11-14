import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    // One input-free surface preserves the original 48 px workspace reservation.
    PanelWindow {
        screen: win.screen
        anchors { top: true; left: true; right: true }
        implicitHeight: 48; exclusiveZone: 48
        visible: App.barsShown && !win.fullscreen
        exclusionMode: ExclusionMode.Normal
        color: "transparent"; mask: Region {}
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "dynamite-bar-space"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    }
    LeftBar { id: leftBar; screen: win.screen; fullscreen: win.fullscreen }
    RightBar { id: rightBar; screen: win.screen; fullscreen: win.fullscreen }
    WallpaperPreview { id: wallpaperPreview; screen: win.screen }
    PanelWindow {
    id: win
    screen: Quickshell.screens.find(s=>s.name === "eDP-1") || Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dynamite"
    WlrLayershell.keyboardFocus: App.modal ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: App.modal ? null : fullscreen ? emptyRegion : islandRegion
    readonly property var hyprMonitor: Hyprland.monitors.values.find(m => m.name === "eDP-1") || Hyprland.monitors.values[0]
    // Hyprland reports a shown special workspace (scratchpad) only in the monitor's IPC object.
    readonly property string special: hyprMonitor?.lastIpcObject?.specialWorkspace?.name || ""
    readonly property bool fullscreen: hyprMonitor?.activeWorkspace?.hasFullscreen
        || (special !== "" && Hyprland.workspaces.values.some(w => w.name === special && w.hasFullscreen))
    visible: App.modal || App.keepAwake || !fullscreen
    Region { id: emptyRegion }
    Region { id: islandRegion; item: island }
    IdleInhibitor { window: win; enabled: App.keepAwake }
    MouseArea { anchors.fill: parent; enabled: App.modal; onClicked: App.close() }
    SystemClock { id: clock; precision: SystemClock.Minutes }

    ConcaveCorner { x: island.x - width; y: 0; visible: island.visible }
    ConcaveCorner { x: island.x + island.width; y: 0; mirrored: true; visible: island.visible }
    Rectangle {
        id: island
        visible: App.modal || !win.fullscreen
        readonly property var sizes: ({compact:[headerRow.implicitWidth + 48,48], status:[720,App.player ? 178 : 108],launcher:[520,392],controls:[520,568],themes:[800,254],wallpapers:[1000,262]})
        readonly property real targetWidth: Math.min(win.width-24,sizes[App.panel][0])
        readonly property real targetHeight: Math.min(win.height-24,sizes[App.panel][1]+(App.error ? 36 : 0))
        anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
        width: targetWidth; height: targetHeight
        color: App.palette.bg; bottomLeftRadius: App.panel==="compact" ? 20 : 28; bottomRightRadius: bottomLeftRadius
        clip: true
        Behavior on width { NumberAnimation { duration: App.reducedMotion ? 0 : island.targetWidth > island.width ? 250 : 200; easing.type: island.targetWidth > island.width ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 1 } }
        Behavior on height { NumberAnimation { duration: App.reducedMotion ? 0 : island.targetHeight > island.height ? 250 : 200; easing.type: island.targetHeight > island.height ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 1 } }
        HoverHandler {
            id: hover
            onHoveredChanged: {
                if (hovered) { leave.stop(); if (App.panel==="compact") enter.restart(); }
                else { enter.stop(); if (App.panel==="status") leave.restart(); }
            }
        }
        Timer { id: enter; interval: 120; onTriggered: if (hover.hovered && App.panel==="compact") App.panel="status" }
        Timer { id: leave; interval: 300; onTriggered: if (!hover.hovered && App.panel==="status") App.close() }
        // This hit surface sits below the child controls, so it never steals their taps.
        MouseArea { anchors.fill: parent; onClicked: if (!App.modal) App.toggle("controls") }
        FocusScope {
            id: focusScope
            anchors.fill: parent; focus: App.modal
            Keys.onEscapePressed: App.close()
            Item {
                width: island.targetWidth; height: 48; anchors.horizontalCenter: parent.horizontalCenter
                Row {
                    id: headerRow
                    anchors.centerIn: parent; spacing: 16
                    Workspaces { id: workspaces; anchors.verticalCenter: parent.verticalCenter }
                    ShellText { text: Qt.formatDateTime(clock.date,"HH:mm"); font.pixelSize: 13; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { anchors.fill: parent; z:-1; onClicked: App.toggle("controls") }
            }
            Loader {
                id: panelLoader
                y: 48; width: island.targetWidth; height: Math.max(0,island.sizes[App.panel][1]-48)
                anchors.horizontalCenter: parent.horizontalCenter
                active: App.panel !== "compact"
                sourceComponent: App.panel === "status" ? statusPanel : App.panel === "launcher" ? launcherPanel : App.panel === "controls" ? controlsPanel : App.panel === "themes" ? themesPanel : wallpapersPanel
                onLoaded: Qt.callLater(() => { if (App.modal && item) { focusScope.forceActiveFocus(); if (item.activate) item.activate(); else item.forceActiveFocus(); } })
                opacity: status === Loader.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: App.reducedMotion ? 0 : 120 } }
            }
            ShellText { anchors.bottom: parent.bottom; anchors.bottomMargin: 12; anchors.horizontalCenter: parent.horizontalCenter; width: parent.width-32; text: App.error; color: "#ef9a9a"; font.pixelSize: 11; visible: text!=="" }
        }
    }
    Connections { target: App; function onPanelChanged() { if (!App.modal) { enter.stop(); leave.stop(); } } }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activespecial" || event.name === "fullscreen") { Hyprland.refreshMonitors(); Hyprland.refreshWorkspaces(); }
        }
    }
    Component { id: statusPanel; Status { } }
    Component { id: launcherPanel; Launcher { } }
    Component { id: controlsPanel; Controls { } }
    Component { id: themesPanel; Picker { } }
    Component { id: wallpapersPanel; Picker { wallpaper: true } }
    IpcHandler {
        target: "dynamite"
        function toggle(panel: string): void { App.toggle(panel); }
        function close(): void { App.close(); rightBar.sliderKind = ""; leftBar.musicOpen = false; }
        function bars(): void { App.barsShown = !App.barsShown; rightBar.sliderKind = ""; leftBar.musicOpen = false; }
        function menu(kind: string): void { if (kind === "music") leftBar.musicOpen = true; else if (["wifi", "power"].includes(kind)) rightBar.showMenu(kind); }
        function menuState(): string { return rightBar.menuState(); }
        function menuSearch(query: string): void { rightBar.setSearch(query); }
        function menuPassword(ssid: string): void { rightBar.passwordFor(ssid); }
        function menuPower(index: int, arm: bool): void { rightBar.choosePower(index); if (arm && index >= 2) { rightBar.armedPower = index; rightBar.armTimer(); } }
        function slider(kind: string): void { if (["volume", "brightness"].includes(kind)) rightBar.showSlider(kind); }
        function state(): string { return JSON.stringify({panel:App.panel, preview:App.previewWallpaper, previewVisible:wallpaperPreview.visible, leftBar:{width:leftBar.width,music:leftBar.musicOpen,player:App.player?.identity || "",source:App.player?.dbusName || "",sources:App.mediaPlayers.map(p=>p.dbusName),playing:App.player?.isPlaying || false,title:App.player?.trackTitle || "",windows:leftBar.windows.map(t=>t.appId)}, barsShown:App.barsShown, rightBar:{width:rightBar.width,slider:rightBar.sliderKind,hoverX:rightBar.hoverX,hoverWidth:rightBar.hoverWidth}, visible:win.visible, theme:App.appliedTheme, wallpaper:App.appliedWallpaper, busy:App.busy, error:App.error, services:App.data, workspaces:workspaces.entries, focusedWorkspace:Hyprland.focusedWorkspace?.id, nativeLua:Hyprland.usingLua, query:panelLoader.item?.query || "", resultCount:panelLoader.item?.resultCount || 0, selected:panelLoader.item?.selected?.id || panelLoader.item?.selected?.path || "", battery:App.battery, fullscreen:win.fullscreen, special:win.special, reducedMotion:App.reducedMotion}); }
    }
}
}
