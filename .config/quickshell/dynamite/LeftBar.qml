pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "menus"

PanelWindow {
    id: leftBar
    property bool fullscreen: false
    property bool behindWindow: false
    property color baseColor: App.palette.bg
    readonly property var player: App.player
    property alias menuFrame: frame
    property alias music: musicMenu
    property alias cpu: cpuMenu
    property alias task: taskMenu
    function taskAt(index) { return taskItems.itemAt(index); }
    // Most recently focused first; windows never focused keep their open order after those.
    property var focusOrder: []
    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() { const t = ToplevelManager.activeToplevel; if (t) leftBar.focusOrder = [t].concat(leftBar.focusOrder.filter(x => x !== t)).slice(0, 50); }
    }
    readonly property var windows: {
        const all = ToplevelManager.toplevels.values.filter(t => !["wofi", "Mattermost.Desktop"].includes(t.appId) && !t.appId.toLowerCase().includes("mattermost"));
        const rank = t => { const i = focusOrder.indexOf(t); return i < 0 ? focusOrder.length + all.indexOf(t) : i; };
        return all.slice().sort((a, b) => rank(a) - rank(b)).slice(0, 5);
    }
    anchors { top: true; left: true }
    margins.top: App.barTop
    implicitWidth: Math.max(App.sideWidth, 16 + launcherButton.width + cpuButton.width + windowIcons.width + row.spacing * 3 + 120)
    implicitHeight: 38 + 38 + 38
    color: "transparent"
    visible: !fullscreen && App.barsShown
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: behindWindow ? WlrLayer.Bottom : WlrLayer.Top
    WlrLayershell.namespace: "dynamite-left-bar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    onVisibleChanged: if (!visible) { frame.hoveredItem = null; frame.close(); }
    mask: frame.inputMask
    Rectangle {
        id: background; width: leftBar.width - (App.barJoined ? App.barHeight / 2 : 0); height: 38
        color: App.barFill
        topRightRadius: App.barJoined ? 0 : 19; bottomRightRadius: topRightRadius
        Row {
            id: row; z: 1; x: 10; height: 38; spacing: 7
            BarItem {
                id: launcherButton
                bar: frame; width: 47; glyph: ""; iconSize: 19; hint: "Applications"
                onClicked: button => frame.launch(button === Qt.RightButton ? ["dolphin"] : [App.home + "/.local/bin/dynamite", "toggle", "launcher"])
            }
            BarItem {
                id: mediaButton
                menu: musicMenu
                bar: frame; width: Math.max(0, leftBar.width - 16 - launcherButton.width - cpuButton.width - windowIcons.width - row.spacing * 3); glyph: leftBar.player ? (leftBar.player.isPlaying ? "" : "") : ""; iconSize: 12
                label: leftBar.player?.trackTitle || "No media"; maximumLabelWidth: Math.max(0, width - 2 * App.itemPadding - 12 - contentSpacing)
                hint: leftBar.player ? [leftBar.player.trackTitle || leftBar.player.identity, leftBar.player.trackArtist].filter(Boolean).join("\n") : ""
                onClicked: if (leftBar.player?.canTogglePlaying) leftBar.player.togglePlaying()
                onScrolled: direction => {
                    if (direction > 0 && leftBar.player?.canGoNext) leftBar.player.next();
                    else if (direction < 0 && leftBar.player?.canGoPrevious) leftBar.player.previous();
                }
            }
            BarItem {
                id: cpuButton
                bar: frame; glyph: "󰍛"; iconSize: 17; menu: cpuMenu; contentSpacing: 4
                label: App.healthLabel
                alertColor: App.healthColor(App.healthLevel); iconColor: alertColor.a > 0 ? alertColor : App.palette.accent; hint: App.healthHint
                onClicked: frame.launch(["kitty", "-e", "htop", "--sort-key", App.healthCulprit === "memory" ? "PERCENT_MEM" : "PERCENT_CPU"])
            }
            Row {
                id: windowIcons
                height: 38; leftPadding: 3; rightPadding: 3
                Repeater {
                    id: taskItems
                    model: leftBar.windows
                    delegate: Item {
                        id: task
                        required property var modelData
                        readonly property url iconSource: taskImage.source
                        width: 20 + 2 * App.itemPadding; height: 38
                        AppIcon { id:taskImage; anchors.centerIn:parent; size:20; appId:task.modelData.appId }
                        MouseArea {
                            id: taskPointer; anchors.fill: parent; hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onEntered: { taskMenu.source = task; frame.enterItem(task, taskMenu); }
                            onExited: frame.leaveItem(task)
                            onClicked: event => { if (event.button === Qt.MiddleButton) task.modelData.close(); else task.modelData.activate(); }
                        }
                        Accessible.role: Accessible.Button; Accessible.name: modelData.title
                        Accessible.onPressAction: modelData.activate()
                    }
                }
            }
        }
    }
    CpuMenu { id: cpuMenu; frame: frame; anchor: cpuButton; l2.parent: frame.lowerContent }
    MusicMenu { id: musicMenu; frame: frame; anchor: mediaButton; l2.parent: frame.lowerContent; l3.parent: frame.detailContent }
    TitleMenu { id: taskMenu; frame: frame; task: true; l2.parent: frame.lowerContent }
    MenuFrame { id: frame; anchors.fill: parent; hostWindow: leftBar; background: background; leftSide: true }
}
