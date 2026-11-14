pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: leftBar
    property bool fullscreen: false
    property Item hoveredItem: null
    property real hoverX: 10
    property real hoverWidth: 47
    property color baseColor: App.palette.bg
    readonly property var player: App.player
    property bool musicOpen: false
    property string hoveredKind: ""
    readonly property Item highlightItem: hoveredItem || (musicOpen ? mediaButton : null)
    property real detailReveal: musicOpen && rowReveal > 0.99 ? 1 : 0
    Behavior on detailReveal { NumberAnimation { duration: App.reducedMotion ? 0 : leftBar.musicOpen ? 180 : 140; easing.type: Easing.OutCubic } }
    property real rowReveal: musicOpen ? 1 : 0
    Behavior on rowReveal { NumberAnimation { duration: App.reducedMotion ? 0 : leftBar.musicOpen ? 180 : 140; easing.type: Easing.OutCubic } }
    readonly property var windows: ToplevelManager.toplevels.values.filter(t => !["wofi", "Mattermost.Desktop"].includes(t.appId) && !t.appId.toLowerCase().includes("mattermost"))
    function enterItem(item, kind) {
        enterMusic.stop(); leaveMusic.stop(); hoveredItem = item; hoveredKind = kind;
        if (kind === "music" && player) enterMusic.restart();
        else if (musicOpen) leaveMusic.restart();
    }
    function leaveItem(item) {
        if (hoveredItem !== item) return;
        hoveredItem = null; hoveredKind = ""; enterMusic.stop(); leaveMusic.restart();
    }
    function launch(command) { musicOpen = false; App.external([App.home + "/.local/bin/bar-menu-guard"].concat(command)); }
    onHighlightItemChanged: if (highlightItem) { hoverX = highlightItem.mapToItem(background, 0, 0).x; hoverWidth = highlightItem.width; }
    anchors { top: true; left: true }
    margins.top: 10
    implicitWidth: row.implicitWidth + 16
    implicitHeight: 38 + 38 + 50
    color: "transparent"
    visible: !fullscreen && App.barsShown
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "dynamite-left-bar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    onVisibleChanged: if (!visible) { hoveredItem = null; musicOpen = false; }
    onPlayerChanged: if (!player) musicOpen = false
    mask: Region {
        item: background
        Region { x: 0; y: lowerReveal.y; width: lowerBar.width + lowerShoulder.width; height: lowerReveal.height }
        Region { x: 0; y: detailClip.y; width: detailBar.width + 12; height: detailClip.height }
    }
    Connections { target: App; function onPanelChanged() { if (App.modal) leftBar.musicOpen = false; } }
    Timer { id: enterMusic; interval: 150; onTriggered: if (leftBar.player && !App.modal) leftBar.musicOpen = true }
    Timer { id: leaveMusic; interval: 250; onTriggered: if (!detailHover.hovered && !detailShoulderHover.hovered && !lowerHover.hovered && !shoulderHover.hovered && leftBar.hoveredKind !== "music" && !musicControls.seeking) leftBar.musicOpen = false }
    Rectangle {
        id: background; width: leftBar.width; height: 38
        color: Qt.rgba(leftBar.baseColor.r, leftBar.baseColor.g, leftBar.baseColor.b, 0.8)
        topRightRadius: 19; bottomRightRadius: 19
        Rectangle {
            id: hoverPill
            readonly property bool attached: leftBar.musicOpen && (!leftBar.hoveredItem || leftBar.hoveredKind === "music")
            x: leftBar.hoverX; width: leftBar.hoverWidth; y: 2; height: attached ? 36 : 34
            topLeftRadius: 17; topRightRadius: 17; bottomLeftRadius: attached ? 0 : 17; bottomRightRadius: bottomLeftRadius
            color: App.palette.bg; opacity: leftBar.highlightItem ? 1 : 0
            ConcaveCorner { curveRadius: 12; inverted: true; x: -width; y: hoverPill.height - height; visible: hoverPill.attached }
            ConcaveCorner { curveRadius: 12; inverted: true; mirrored: true; x: hoverPill.width; y: hoverPill.height - height; visible: hoverPill.attached }
            Behavior on x { NumberAnimation { duration: App.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: App.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: App.reducedMotion ? 0 : 100 } }
        }
        Row {
            id: row; x: 10; height: 38; spacing: 7
            BarItem {
                bar: leftBar; width: 47; glyph: ""; iconSize: 19; hint: "Applications"
                onClicked: button => leftBar.launch(button === Qt.RightButton ? ["dolphin"] : [App.home + "/.local/bin/dynamite", "toggle", "launcher"])
            }
            BarItem {
                id: mediaButton
                sliderKind: "music"
                bar: leftBar; width: 218; glyph: leftBar.player ? (leftBar.player.isPlaying ? "" : "") : ""; iconSize: 12
                label: leftBar.player?.trackTitle || "No media"; maximumLabelWidth: 170
                hint: leftBar.player ? [leftBar.player.trackTitle || leftBar.player.identity, leftBar.player.trackArtist].filter(Boolean).join("\n") : ""
                onClicked: if (leftBar.player?.canTogglePlaying) leftBar.player.togglePlaying()
                onScrolled: direction => {
                    if (direction > 0 && leftBar.player?.canGoNext) leftBar.player.next();
                    else if (direction < 0 && leftBar.player?.canGoPrevious) leftBar.player.previous();
                }
            }
            BarItem {
                bar: leftBar; minimumWidth: 73; glyph: ""; iconSize: 13; contentSpacing: 4
                label: App.data.temperature !== undefined && App.data.temperature !== null ? Math.round(App.data.temperature) + "°C" : "—°C"
                iconColor: App.data.temperature >= 85 ? "#dfb479" : App.palette.accent; hint: "CPU temperature"
                onClicked: leftBar.launch(["kitty", "-e", "top"])
            }
            Row {
                height: 38; leftPadding: 3; rightPadding: 3
                Repeater {
                    model: leftBar.windows
                    delegate: Item {
                        id: task
                        required property var modelData
                        readonly property string mark: modelData.appId.toLowerCase().includes("t3code") ? "t3code" : modelData.appId.startsWith("vivaldi") ? modelData.appId : ""
                        readonly property var entry: {
                            const entries = DesktopEntries.applications.values;
                            return entries.find(e => e.id === modelData.appId || e.id === modelData.appId + ".desktop")
                                || DesktopEntries.heuristicLookup(modelData.appId);
                        }
                        readonly property string iconName: entry?.icon || "application-x-executable"
                        readonly property string symbolicName: iconName.endsWith("-symbolic") ? iconName : iconName + "-symbolic"
                        width: 30; height: 38
                        Rectangle { x: 0; y: 3; width: 30; height: 32; radius: 16; color: App.palette.accent; opacity: task.modelData.activated ? 0.22 : 0 }
                        IconImage {
                            anchors.centerIn: parent; implicitSize: 20
                            source: task.mark ? "file://" + App.home + "/.local/share/icons/dynamite-waybar/apps/" + task.mark + ".png" : Quickshell.iconPath(Quickshell.hasThemeIcon(task.symbolicName) ? task.symbolicName : task.iconName)
                            layer.enabled: true
                            layer.effect: ColorOverlay { color: App.palette.accent }
                        }
                        MouseArea {
                            id: taskPointer; anchors.fill: parent; hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onEntered: leftBar.enterItem(task, "")
                            onExited: leftBar.leaveItem(task)
                            onClicked: event => { if (event.button === Qt.MiddleButton) task.modelData.close(); else task.modelData.activate(); }
                        }
                        Accessible.role: Accessible.Button; Accessible.name: modelData.title
                        Accessible.onPressAction: modelData.activate()
                        ToolTip {
        popupType: Popup.Window; y: 38
                            visible: taskPointer.containsMouse; delay: 700; text: task.modelData.title
                            contentItem: Text { text: task.modelData.title; color: App.palette.text; font.pixelSize: 12 }
                            background: Rectangle { color: App.palette.surface; radius: 8; border.color: App.palette.muted }
                        }
                    }
                }
            }
        }
    }
    Item {
        id: lowerReveal; y: 38; width: leftBar.width; height: 38 * leftBar.rowReveal
        clip: true; opacity: leftBar.rowReveal; visible: leftBar.rowReveal > 0; enabled: leftBar.musicOpen
        ConcaveCorner {
            id: lowerShoulder
            curveRadius: Math.min(12, Math.max(0, leftBar.width - lowerBar.width - background.bottomRightRadius))
            visible: false; x: lowerBar.width; y: 0; mirrored: true
            HoverHandler { id: shoulderHover; onHoveredChanged: { if (hovered) leaveMusic.stop(); else leaveMusic.restart(); } }
        }
        Rectangle {
            id: lowerBar; width: Math.round(leftBar.width * 0.95); height: 38
            color: App.palette.bg; topRightRadius: 19; bottomRightRadius: 19
            HoverHandler { id: lowerHover; onHoveredChanged: { if (hovered) leaveMusic.stop(); else leaveMusic.restart(); } }
            MusicControls {
                id: musicControls; layered: true
                anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 20
            }
        }
    }
    Item {
        id: detailClip; y: 76; width: leftBar.width; height: 50 * leftBar.detailReveal
        clip: true; opacity: leftBar.detailReveal; visible: height > 0; enabled: leftBar.musicOpen
        ConcaveCorner {
            visible: false; curveRadius: 12; x: detailBar.width; mirrored: true
            HoverHandler { id: detailShoulderHover; onHoveredChanged: { if (hovered) leaveMusic.stop(); else leaveMusic.restart(); } }
        }
        Rectangle {
            id: detailBar; width: Math.round(lowerBar.width * 0.95); height: 50
            color: App.palette.bg; topRightRadius: 19; bottomRightRadius: 19
            HoverHandler { id: detailHover; onHoveredChanged: { if (hovered) leaveMusic.stop(); else leaveMusic.restart(); } }
            MenuRow {
                x: 10; y: 8; width: parent.width - 20
                glyph: art.status === Image.Ready ? "" : "󰝚"
                label: [leftBar.player?.trackTitle || leftBar.player?.identity || "", leftBar.player?.trackArtist || ""].filter(Boolean).join(" — ")
                onClicked: { if (leftBar.player?.canRaise) leftBar.player.raise(); }
                leading: Rectangle {
                    anchors.centerIn: parent; width: 22; height: 22; radius: 6; color: "transparent"; clip: true; visible: art.status === Image.Ready
                    Image {
                        id: art; anchors.fill: parent; source: leftBar.player?.trackArtUrl || ""; fillMode: Image.PreserveAspectCrop; asynchronous: true
                        layer.enabled: true
                        layer.effect: OpacityMask { maskSource: Rectangle { width: 22; height: 22; radius: 6 } }
                    }
                }
                trailing: Text { text: leftBar.player?.identity || ""; color: App.palette.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 13; width: Math.min(implicitWidth, detailBar.width * 0.3); elide: Text.ElideRight }
            }
        }
    }

}
