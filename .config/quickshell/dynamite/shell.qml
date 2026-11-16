import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    readonly property var menus: ({wifi:rightBar.wifi, power:rightBar.power, battery:rightBar.battery, notifications:rightBar.notifications, calendar:rightBar.calendar, toast:rightBar.toast, tray:rightBar.tray, brightness:rightBar.brightness, volume:rightBar.volume, music:leftBar.music, cpu:leftBar.cpu, task:leftBar.task})
    function menuName(menu) { return menu === menus.volume ? menu.kind : Object.keys(menus).find(name => menus[name] === menu) || ""; }
    Binding { target: Notifications; property: "otherMenuOpen"; value: leftBar.menuFrame.open }
    // One input-free surface reserves the bar area: Hyprland gap + bar height (windows add their own gap below).
    PanelWindow {
        screen: App.barScreen
        anchors { top: true; left: true; right: true }
        implicitHeight: App.topHeight; exclusiveZone: App.topHeight
        visible: App.barsShown && !win.fullscreen
        exclusionMode: ExclusionMode.Normal
        color: "transparent"; mask: Region {}
        WlrLayershell.layer: win.behindWindow ? WlrLayer.Bottom : WlrLayer.Top
        WlrLayershell.namespace: "dynamite-bar-space"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    }
    LeftBar { id: leftBar; screen: App.barScreen; fullscreen: win.fullscreen; behindWindow: win.behindWindow }
    RightBar { id: rightBar; screen: App.barScreen; fullscreen: win.fullscreen; behindWindow: win.behindWindow }
    // Keep the bar's workspace island mapped while the modal surface is on another screen.
    PanelWindow {
        id: barIsland
        screen: App.barScreen
        anchors.top: true
        margins.top: App.barTop
        implicitWidth: persistentWorkspaces.implicitWidth + 2 * (8 + App.itemPadding)
        implicitHeight: App.barHeight
        visible: win.centered && App.barsShown && !win.fullscreen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: win.behindWindow ? WlrLayer.Bottom : WlrLayer.Top
        WlrLayershell.namespace: "dynamite-workspace-island"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        Rectangle {
            anchors.fill: parent
            radius: App.barHeight / 2
            color: App.barFill
            Rectangle {
                anchors.fill: parent; anchors.margins: 2
                radius: height / 2; color: App.bgColor
                visible: islandHover.hovered
            }
            MouseArea { anchors.fill: parent; onClicked: App.openBarOverview(0) }
            Workspaces { id: persistentWorkspaces; anchors.centerIn: parent; barIsland: true }
            HoverHandler { id: islandHover }
        }
    }
    WallpaperPreview { id: wallpaperPreview; screen: win.screen }
    Variants {
        model: Quickshell.screens.filter(s => s !== App.barScreen)
        DesktopClock { required property var modelData; screen: modelData }
    }
    Process {
        id: layoutPolicy
        command: ["python3", Qt.resolvedUrl("layout.py").toString().replace("file://", ""), App.barScreen?.name || ""]
        running: App.barScreen !== null
        onExited: if (App.barScreen !== null) layoutRetry.restart()
    }
    Timer { id: layoutRetry; interval: 1000; onTriggered: layoutPolicy.running = App.barScreen !== null }
    Connections {
        target: App
        function onBarScreenChanged() { layoutPolicy.running = false; Qt.callLater(() => { layoutPolicy.running = App.barScreen !== null; }); }
    }
    PanelWindow {
    id: win
    screen: App.panelScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: App.modal ? WlrLayer.Overlay : behindWindow ? WlrLayer.Bottom : WlrLayer.Top
    WlrLayershell.namespace: "dynamite"
    WlrLayershell.keyboardFocus: App.modal ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: App.modal ? null : fullscreen ? emptyRegion : centerRegion
    readonly property var hyprMonitor: Hyprland.monitors.values.find(m => m.name === App.barScreen?.name) || null
    // Hyprland reports a shown special workspace (scratchpad) only in the monitor's IPC object.
    readonly property string special: hyprMonitor?.lastIpcObject?.specialWorkspace?.name || ""
    readonly property bool behindWindow: !fullscreen && (hyprMonitor?.activeWorkspace?.hasFullscreen
        || (special !== "" && Hyprland.workspaces.values.some(w => w.name === special && w.hasFullscreen)))
    // Compositor-only fullscreen keeps the bar rendered underneath transparent windows.
    readonly property bool fullscreen: Hyprland.toplevels.values.some(t =>
        t.lastIpcObject?.fullscreen === 2 && t.lastIpcObject?.fullscreenClient === 2
        && (t.workspace === hyprMonitor?.activeWorkspace || (special !== "" && t.workspace?.name === special)))
    visible: App.modal || App.keepAwake || !fullscreen
    Region { id: emptyRegion }
    Region { id: centerRegion; item: dotsPill; Region { item: centerFrame } }
    IdleInhibitor { window: win; enabled: App.keepAwake }
    MouseArea { anchors.fill: parent; enabled: App.modal; onClicked: App.close() }
    SystemClock { id: clock; precision: SystemClock.Minutes }

    readonly property bool centered: screen?.name !== App.barScreen?.name
    readonly property real panelTop: centered ? Math.max(12, (height - App.barHeight - centerFrame.fullHeight) / 2) : App.barTop
    readonly property real centerLeft: (win.width-dotsPill.width)/2
    readonly property real centerRight: win.centerLeft+dotsPill.width
    readonly property real leftGap: Math.max(0,win.centerLeft-leftBar.width)
    readonly property real rightGap: Math.max(0,win.width-rightBar.width-win.centerRight)
    // The side bars extend to the centre pill while the panel grows out of it, at the same time.
    Rectangle {
        visible:App.joinActive && !win.centered; color:App.barFill
        x:leftBar.width - App.barHeight/2; y:App.barTop; height:App.barHeight
        width:App.barHeight/2 + win.leftGap*App.joinProgress
        topRightRadius:App.barHeight/2*(1-App.joinProgress); bottomRightRadius:topRightRadius
    }
    Rectangle {
        visible:App.joinActive && !win.centered; color:App.barFill
        x:win.centerLeft; y:App.barTop; height:App.barHeight
        width:dotsPill.width
        radius:App.barHeight/2*(1-App.joinProgress)
    }
    Rectangle {
        visible:App.joinActive && !win.centered; color:App.barFill
        x:win.width-rightBar.width-win.rightGap*App.joinProgress; y:App.barTop; height:App.barHeight
        width:App.barHeight/2 + win.rightGap*App.joinProgress
        topLeftRadius:App.barHeight/2*(1-App.joinProgress); bottomLeftRadius:topLeftRadius
    }
    ParallelAnimation {
        id: joinOpen
        NumberAnimation { target:App; property:"joinProgress"; to:1; duration:App.reducedMotion ? 0 : 120 * App.motionScale; easing.type:Easing.OutCubic }
        NumberAnimation { target:App; property:"dropProgress"; to:1; duration:App.reducedMotion ? 0 : 160 * App.motionScale; easing.type:Easing.OutCubic }
    }
    SequentialAnimation {
        id: joinClose
        ParallelAnimation {
            NumberAnimation { target:App; property:"dropProgress"; to:0; duration:App.reducedMotion ? 0 : 120 * App.motionScale; easing.type:Easing.InCubic }
            NumberAnimation { target:App; property:"joinProgress"; to:0; duration:App.reducedMotion ? 0 : 120 * App.motionScale; easing.type:Easing.InCubic }
        }
        ScriptAction { script:App.finishClose() }
    }
    Connections {
        target:App
        function onJoinActiveChanged() { if (App.joinActive) { joinClose.stop(); joinOpen.restart(); } }
        function onDismissOverview() { joinOpen.stop(); joinClose.restart(); }
        function onPanelChanged() {
            if (App.panel !== "compact" && App.joinActive && joinClose.running) { joinClose.stop(); joinOpen.restart(); }
            if (App.modal) Qt.callLater(() => panelLoader.item?.activate());
        }
    }
    readonly property real modeWidth: Math.min(win.width-24, App.panel === "themes" ? 800 : App.panel === "wallpapers" ? 1000 : 520)
    property real contentWidth: modeWidth
    Behavior on contentWidth { NumberAnimation { duration:App.reducedMotion ? 0 : 160*App.motionScale; easing.type:Easing.OutCubic } }
    Rectangle {
        id: dotsPill
        anchors.horizontalCenter:parent.horizontalCenter; y:win.panelTop
        width:headerRow.implicitWidth + 2*(8+App.itemPadding); height:App.barHeight
        radius:App.barHeight/2; color:App.joinActive ? "transparent" : App.barFill
        visible:App.modal || (!win.centered && !win.fullscreen)
        Rectangle {
            id:dotsTab
            anchors.horizontalCenter:parent.horizontalCenter
            width:parent.width; y:2; height:App.joinActive ? 35+App.dropProgress : 34
            topLeftRadius:17; topRightRadius:17
            bottomLeftRadius:App.joinActive ? 0 : 17; bottomRightRadius:bottomLeftRadius
            color:App.bgColor; visible:hover.hovered || App.joinActive
            ConcaveCorner { curveRadius:12*App.dropProgress; inverted:true; x:-width; y:dotsTab.height-height; visible:App.joinActive }
            ConcaveCorner { curveRadius:12*App.dropProgress; inverted:true; mirrored:true; x:dotsTab.width; y:dotsTab.height-height; visible:App.joinActive }
        }
        Row {
            id:headerRow
            anchors.centerIn:parent
            Workspaces { id:workspaces; anchors.verticalCenter:parent.verticalCenter }
        }
        MouseArea { anchors.fill:parent; z:-1; onClicked: { if (App.panel === "compact") App.hoverOverview(); App.pinOverview(); } }
        HoverHandler { id:hover; onHoveredChanged: { if (hovered) { leave.stop(); if (App.panel === "compact") enter.restart(); } else { enter.stop(); if (!panelHover.hovered && App.panel === "overview" && !App.overviewPinned) leave.restart(); } } }
    }
    Timer { id:enter; interval:300; onTriggered:if (hover.hovered && App.panel === "compact") App.hoverOverview() }
    Timer { id:leave; interval:300; onTriggered:if (!hover.hovered && !panelHover.hovered && App.panel === "overview" && !App.overviewPinned) App.close() }
    FocusScope {
        id:focusScope
        anchors.horizontalCenter:parent.horizontalCenter; y:win.panelTop + App.barHeight - 1
        width:win.contentWidth; height:centerFrame.height; focus:App.modal
        Keys.onEscapePressed:App.close()
        Item {
            id:centerFrame
            anchors.horizontalCenter:parent.horizontalCenter
            width:dotsPill.width+(win.contentWidth-dotsPill.width)*App.dropProgress
            property real fullHeight: 0
            Binding {
                target: centerFrame; property: "fullHeight"
                when: panelLoader.item !== null
                value: panelLoader.item ? panelLoader.item.desiredHeight - App.barHeight : 0
                delayed: true; restoreMode: Binding.RestoreNone
            }
            Behavior on fullHeight { NumberAnimation { duration:App.reducedMotion ? 0 : 160*App.motionScale; easing.type:Easing.OutCubic } }
            height:fullHeight*App.dropProgress; visible:App.joinActive
            // All centre modes share these solid L2/L3 surfaces and their reveal.
            Rectangle {
                width:parent.width; height:parent.height; color:App.bgColor
                bottomLeftRadius:Math.min(19, height/2); bottomRightRadius:bottomLeftRadius
                ConcaveCorner { x:-width; y:0; curveRadius:12 }
                ConcaveCorner { x:parent.width; y:0; curveRadius:12; mirrored:true }
            }
            MouseArea { anchors.fill:parent; onClicked:if (App.panel === "overview") App.pinOverview() }
            HoverHandler { id:panelHover; onHoveredChanged: { if (hovered) leave.stop(); else if (!hover.hovered && App.panel === "overview" && !App.overviewPinned) leave.restart(); } }
            Rectangle {
                id: panelMask
                width: centerFrame.width; height: centerFrame.height
                bottomLeftRadius: Math.min(19, height / 2); bottomRightRadius: bottomLeftRadius
                visible: false; layer.enabled: true
            }
            Item {
                // Content is masked to the panel's rounded shape, so nothing pokes out while it grows.
                anchors.fill:parent; clip:true
                layer.enabled:App.joinActive && App.dropProgress < 1
                layer.effect: MultiEffect { autoPaddingEnabled: false; maskEnabled: true; maskSource: panelMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                Loader {
                    id:panelLoader
                    anchors.horizontalCenter:parent.horizontalCenter
                    width:win.contentWidth; height:centerFrame.fullHeight
                    sourceComponent:App.panel === "themes" ? themesPanel : App.panel === "wallpapers" ? wallpapersPanel : overviewPanel
                    onLoaded:Qt.callLater(() => { if (App.modal && item) { focusScope.forceActiveFocus(); item.activate(); } })
                }
            }
        }
    }
    Connections { target: App; function onOverviewPinnedChanged() { if (App.overviewPinned) Qt.callLater(() => panelLoader.item?.activate()); } }
    Connections { target: App; function onPanelChanged() { if (!App.modal) { enter.stop(); leave.stop(); } } }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activespecial" || event.name === "fullscreen") { Hyprland.refreshMonitors(); Hyprland.refreshWorkspaces(); Hyprland.refreshToplevels(); }
        }
    }
    Component { id: overviewPanel; Overview { } }
    Component { id: themesPanel; Picker { } }
    Component { id: wallpapersPanel; Picker { wallpaper: true } }
    IpcHandler {
        target: "dynamite"
        function toggle(panel: string): void { App.toggle(panel); }
        function close(): void { App.close(); rightBar.menuFrame.close(); leftBar.menuFrame.close(); }
        function bars(): void { App.barsShown = !App.barsShown; rightBar.menuFrame.close(); leftBar.menuFrame.close(); }
        function menu(kind: string): void { const m = menus[kind]; if (["music", "cpu", "wifi", "power", "battery", "notifications", "calendar"].includes(kind)) { if (kind === "music") m.frame.activeMenu = m; else m.frame.show(m, true); } }
        function hintPreview(): void { App.teach("SUPER T"); }
        function overviewHover(): void { App.hoverOverview(); }
        function motionScale(factor: real): void { App.motionScale = factor; }
        function overviewSearch(query: string): void { if (App.panel !== "overview") App.toggle("launcher"); App.pinOverview(); Qt.callLater(() => { if (panelLoader.item) panelLoader.item.query=query; }); }
        function overviewState(): string { return JSON.stringify({panel:App.panel, modal:App.modal, height:centerFrame.height, width:centerFrame.width, pinned:App.overviewPinned, join:App.joinProgress, drop:App.dropProgress, focus:panelLoader.item?.searchFocused, results:panelLoader.item?.entries?.map(r=>({id:r.id,label:r.label,type:r.type})), armed:panelLoader.item?.armed || ""}); }
        function calendarMonth(year: int, month: int): void { menus.calendar.setCalendarMonth(year, month); }
        function menuTask(index: int): void { { const item = leftBar.taskAt(index); if (item) { menus.task.source = item; menus.task.frame.show(menus.task, false); } }; }
        function menuTray(index: int): void { { const item = rightBar.trayAt(index); if (item) { menus.tray.source = item; menus.tray.frame.show(menus.tray, false); } }; }
        function notificationAction(name: string, value: string): void { App.action(name, value); }
        function toastState(): string { return JSON.stringify({current:Notifications.toast?.id || 0, queued:Notifications.toastQueue.map(t=>t.id), remaining:Notifications.toastRemaining, dnd:Notifications.dnd}); }
        function menuState(): string { const wifi = menus.wifi, power = menus.power, notices = menus.notifications, frame = rightBar.menuFrame; return JSON.stringify({kind:menuName(frame.activeMenu), query:wifi.passwordNetwork ? "" : wifi.focusTarget.text, password:wifi.passwordNetwork?.ssid || "", focus:wifi.focusTarget.activeFocus, scopeFocus:frame.activeFocus, pinned:frame.pinned, notifications:notices.notifications.length, groups:notices.notificationGroups.length, notificationIndex:notices.currentNotification, networks:wifi.networks.length, filtered:wifi.filteredNetworks.length, powerIndex:power.powerIndex, armed:power.armedPower}); }
        function menuSearch(query: string): void { menus.wifi.setSearch(query); }
        function menuPassword(ssid: string): void { menus.wifi.passwordFor(ssid); }
        function menuPower(index: int, arm: bool): void { menus.power.choosePower(index); if (arm && index >= 2) { menus.power.armedPower = index; menus.power.armTimer(); } }
        function slider(kind: string): void { if (["volume", "brightness"].includes(kind)) { menus[kind].anchor = kind === "volume" ? rightBar.volumeAnchor : rightBar.brightnessAnchor; menus[kind].frame.show(menus[kind], false, true); } }
        function demoTargets(): string {
            const point = (item, right) => { const p = item.mapToItem(null, item.width / 2, item.height / 2); return {x:p.x + (right ? win.width - rightBar.width : 0), y:p.y + App.barTop}; };
            return JSON.stringify({music:point(menus.music.anchor, false), cpu:point(menus.cpu.anchor, false),
                tasks:leftBar.windows.map((w,i)=>Object.assign({appId:w.appId}, point(leftBar.taskAt(i), false))),
                network:point(menus.wifi.anchor, true), volume:point(rightBar.volumeAnchor, true), power:point(menus.power.anchor, true), calendar:point(menus.calendar.anchor, true)});
        }
        function state(): string { return JSON.stringify({barScreen:App.barScreen?.name, panelScreen:win.screen?.name, centered:win.centered, panelTop:win.panelTop, panelHeight:App.barHeight+centerFrame.fullHeight, screenHeight:win.height, screens:Quickshell.screens.map(s=>s.name), panel:App.panel, preview:App.previewWallpaper, previewVisible:wallpaperPreview.visible, leftBar:{kind:menuName(leftBar.menuFrame.activeMenu),displayed:menuName(leftBar.menuFrame.displayedMenu),width:leftBar.width,music:leftBar.menuFrame.activeMenu === menus.music,player:App.player?.identity || "",source:App.player?.dbusName || "",sources:App.mediaPlayers.map(p=>p.dbusName),playing:App.player?.isPlaying || false,title:App.player?.trackTitle || "",windows:leftBar.windows.map(t=>t.appId)}, barsShown:App.barsShown, rightBar:{width:rightBar.width,slider:menuName(rightBar.menuFrame.activeMenu),hoverX:rightBar.menuFrame.hoverX,hoverWidth:rightBar.menuFrame.hoverWidth}, visible:win.visible, theme:App.appliedTheme, wallpaper:App.appliedWallpaper, busy:App.busy, error:App.error, services:App.data, workspaces:workspaces.entries, focusedWorkspace:Hyprland.focusedWorkspace?.id, nativeLua:Hyprland.usingLua, query:panelLoader.item?.query || "", resultCount:panelLoader.item?.resultCount || 0, selected:panelLoader.item?.selected?.id || panelLoader.item?.selected?.path || "", battery:App.battery, fullscreen:win.fullscreen, special:win.special, reducedMotion:App.reducedMotion}); }
    }
}
}
