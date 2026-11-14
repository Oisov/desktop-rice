pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Widgets

PanelWindow {
    id: stripWindow
    property bool fullscreen: false
    property Item hoveredItem: null
    property string hoveredKind: ""
    readonly property Item highlightItem: (clickMenu ? (sliderKind === "wifi" ? wifiButton : powerButton) : hoveredItem) || (sliderKind === "brightness" ? brightnessButton : sliderKind === "volume" ? volumeButton : null)
    property real hoverX: 6
    property real hoverWidth: 42
    property color baseColor: App.palette.bg
    onHighlightItemChanged: if (highlightItem) { hoverX = highlightItem.mapToItem(topBar, 0, 0).x; hoverWidth = highlightItem.width; }
    property string sliderKind: ""
    property string displayedSliderKind: "brightness"
    onSliderKindChanged: {
        if (sliderKind !== "") displayedSliderKind = sliderKind;
        armedPower = -1; confirmTimer.stop(); passwordNetwork = null; wifiSearch.text = ""; wifiError = "";
        if (sliderKind === "wifi") wifiCall(["list"]);
        wifiSearch.focus = false;
    }
    readonly property bool clickMenu: sliderKind === "wifi" || sliderKind === "power"
    readonly property bool thirdLayer: displayedSliderKind === "wifi" || displayedSliderKind === "power"
    property real detailReveal: clickMenu && rowReveal > 0.99 ? 1 : 0
    Behavior on detailReveal { NumberAnimation { duration: App.reducedMotion ? 0 : stripWindow.clickMenu ? 180 : 140; easing.type: Easing.OutCubic } }
    property var networks: []
    property bool radio: true
    property string wifiError: ""
    property var passwordNetwork: null
    property var wifiQueue: []
    readonly property var filteredNetworks: networks.filter(n => passwordNetwork || n.ssid.toLowerCase().includes(wifiSearch.text.toLowerCase()))
    property int currentNetwork: -1
    property int powerIndex: 0
    property int armedPower: -1
    readonly property var powerNames: ["Lock", "Suspend", "Log out", "Restart", "Shut down"]
    readonly property var powerGlyphs: ["󰌾", "󰒲", "󰍃", "󰜉", "󰐥"]
    function showMenu(kind) { hoverDelay.stop(); closeDelay.stop(); hoveredItem = null; sliderKind = sliderKind === kind ? "" : kind; }
    function menuState() { return JSON.stringify({kind: sliderKind, query: passwordNetwork ? "" : wifiSearch.text, password: passwordNetwork?.ssid || "", focus: wifiSearch.activeFocus, scopeFocus: menuFocus.activeFocus, networks: networks.length, filtered: filteredNetworks.length, powerIndex: powerIndex, armed: armedPower}); }
    function setSearch(query) { passwordNetwork = null; wifiSearch.text = query; }
    function passwordFor(ssid) { const n = networks.find(n => n.ssid === ssid); if (n && n.secured && !n.uuid) activateNetwork(n); }
    function armTimer() { confirmTimer.restart(); }
    function wifiCall(args) {
        if (wifiProcess.running) { wifiQueue = wifiQueue.concat([args]); return; }
        wifiProcess.command = ["python3", App.helper, "wifi"].concat(args); wifiProcess.running = true;
    }
    function activateNetwork(network) {
        if (!network) return;
        if (network.secured && !network.uuid) { passwordNetwork = network; wifiSearch.text = ""; wifiSearch.forceActiveFocus(); }
        else wifiCall(["connect", network.ssid, network.uuid]);
    }
    function choosePower(index) {
        if (powerIndex !== index) { armedPower = -1; confirmTimer.stop(); }
        powerIndex = index;
    }
    function activatePower(index) {
        choosePower(index);
        if (index >= 2 && armedPower !== index) { armedPower = index; confirmTimer.restart(); return; }
        const commands = [["hyprlock"], ["systemctl", "suspend"], ["hyprctl", "eval", "hl.dispatch(hl.dsp.exit())"], ["systemctl", "reboot"], ["systemctl", "poweroff"]];
        sliderKind = ""; Quickshell.execDetached(commands[index]);
    }
    Timer { id: confirmTimer; interval: 4000; onTriggered: stripWindow.armedPower = -1 }
    Process {
        id: wifiProcess
        stdout: StdioCollector { onStreamFinished: {
            try {
                const result = JSON.parse(text);
                if (result.ok) { stripWindow.networks = result.networks; stripWindow.radio = result.radio; if (wifiProcess.command[3] !== "list") stripWindow.wifiError = ""; stripWindow.currentNetwork = -1; }
                else { stripWindow.wifiError = result.error; if (wifiProcess.command[3] !== "list") stripWindow.wifiQueue = stripWindow.wifiQueue.concat([["list"]]); }
            } catch (e) { stripWindow.wifiError = "Could not read Wi-Fi response"; }
        } }
        onExited: {
            App.refresh();
            if (stripWindow.wifiQueue.length) {
                const next = stripWindow.wifiQueue[0]; stripWindow.wifiQueue = stripWindow.wifiQueue.slice(1);
                Qt.callLater(() => stripWindow.wifiCall(next));
            }
        }
    }
    onClickMenuChanged: {
        if (clickMenu) { grabDelay.restart(); focusDelay.restart(); }
        else { grabDelay.stop(); focusDelay.stop(); menuGrab.active = false; }
    }
    Timer { id: focusDelay; interval: 220; onTriggered: { menuFocus.forceActiveFocus(); if (stripWindow.sliderKind === "wifi") wifiSearch.forceActiveFocus(); } }
    Timer { id: grabDelay; interval: 100; onTriggered: if (stripWindow.clickMenu) menuGrab.active = true }
    HyprlandFocusGrab { id: menuGrab; windows: [stripWindow]; onCleared: stripWindow.sliderKind = "" }
    FocusScope {
        id: menuFocus; anchors.fill: parent
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: event => {
            if (!stripWindow.clickMenu) return;
            if (event.key === Qt.Key_Escape) {
                if (stripWindow.passwordNetwork) { stripWindow.passwordNetwork = null; wifiSearch.text = ""; }
                else stripWindow.sliderKind = "";
            } else if (stripWindow.sliderKind === "power" && [Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].includes(event.key)) {
                stripWindow.choosePower((stripWindow.powerIndex + ([Qt.Key_Left, Qt.Key_Up].includes(event.key) ? 4 : 1)) % 5);
            } else if (stripWindow.sliderKind === "wifi" && [Qt.Key_Up, Qt.Key_Down].includes(event.key)) {
                const count = stripWindow.filteredNetworks.length;
                if (count) { stripWindow.currentNetwork = stripWindow.currentNetwork < 0 ? (event.key === Qt.Key_Up ? count - 1 : 0) : (stripWindow.currentNetwork + (event.key === Qt.Key_Up ? count - 1 : 1)) % count; networkList.positionViewAtIndex(stripWindow.currentNetwork, ListView.Contain); }
            } else if ([Qt.Key_Return, Qt.Key_Enter].includes(event.key)) {
                if (stripWindow.sliderKind === "power") stripWindow.activatePower(stripWindow.powerIndex);
                else if (stripWindow.passwordNetwork) {
                    stripWindow.wifiCall(["connect", stripWindow.passwordNetwork.ssid, "", wifiSearch.text]);
                    stripWindow.passwordNetwork = null; wifiSearch.text = "";
                } else stripWindow.activateNetwork(stripWindow.filteredNetworks[Math.max(0, stripWindow.currentNetwork)]);
            } else return;
            event.accepted = true;
        }
    }
    property real rowReveal: sliderKind !== "" ? 1 : 0
    Behavior on rowReveal { NumberAnimation { duration: App.reducedMotion ? 0 : stripWindow.sliderKind !== "" ? 180 : 140; easing.type: Easing.OutCubic } }
    readonly property bool volume: displayedSliderKind === "volume"
    readonly property real level: volume ? (App.data.audio?.volume || 0) : (App.data.brightness?.value || 5)
    readonly property string volumeGlyph: App.data.audio?.muted ? "󰝟" : levelGlyph(App.data.audio?.volume || 0)
    function levelGlyph(value) { return value < 34 ? "󰕿" : value < 67 ? "󰖀" : "󰕾"; }
    function enterItem(item, kind) {
        if (clickMenu) return;
        closeDelay.stop(); hoverDelay.stop(); hoveredItem = item; hoveredKind = kind;
        if (kind && sliderKind) showSlider(kind);
        else if (kind) { nextKind = kind; hoverDelay.restart(); }
        else if (sliderKind) closeDelay.restart();
    }
    function leaveItem(item) {
        if (clickMenu || hoveredItem !== item) return;
        hoveredItem = null; hoveredKind = "";
        hoverDelay.stop(); closeDelay.restart();
    }
    function settings(kind) {
        launch(kind === "volume" ? ["pavucontrol"] : ["systemsettings", "kcm_powerdevilprofilesconfig"]);
    }
    function launch(command) {
        sliderKind = ""; App.external([App.home + "/.local/bin/bar-menu-guard"].concat(command));
    }
    function requestSlider(kind) {
        Quickshell.execDetached([App.home + "/.local/bin/bar-menu-guard", "qs", "-c", "dynamite", "ipc", "call", "dynamite", "slider", kind]);
    }
    function showSlider(kind) { hoverDelay.stop(); closeDelay.stop(); sliderKind = kind; App.refresh(); }
    property string nextKind: ""
    anchors { top: true; right: true }
    margins.top: 10
    implicitWidth: row.implicitWidth + 16
    // Keep the layer surface fixed: resizing it on hover makes Wayland reconfigure the top row.
    implicitHeight: 38 + 38 + 16 + 6 * 34
    color: "transparent"
    visible: !fullscreen && App.barsShown
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "dynamite-right-bar"
    WlrLayershell.keyboardFocus: clickMenu ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region {
        item: topBar
        Region { x: lowerShoulder.x; y: lowerReveal.y; width: lowerBar.width + lowerShoulder.width; height: lowerReveal.height }
        Region { x: detailBar.x - 12; y: detailClip.y; width: detailBar.width + 12; height: detailClip.height }
    }
    onFullscreenChanged: if (fullscreen) { sliderKind = ""; hoveredItem = null; }
    Connections { target: App; function onPanelChanged() { if (App.modal) stripWindow.sliderKind = ""; } }
    Timer { id: hoverDelay; interval: 100; onTriggered: stripWindow.showSlider(stripWindow.nextKind) }
    Timer { id: closeDelay; interval: 240; onTriggered: { if (!stripWindow.clickMenu && !lowerHover.hovered && !slider.pressed && !(stripWindow.hoveredItem && stripWindow.hoveredKind)) stripWindow.sliderKind = ""; } }
    Rectangle {
        id: topBar; width: stripWindow.width; height: 38
        color: Qt.rgba(stripWindow.baseColor.r, stripWindow.baseColor.g, stripWindow.baseColor.b, 0.8); topLeftRadius: 19; bottomLeftRadius: 19
        Rectangle {
            id: hoverPill
            readonly property bool attached: stripWindow.sliderKind !== "" && (stripWindow.clickMenu || !stripWindow.hoveredItem || stripWindow.hoveredKind !== "")
            x: stripWindow.hoverX
            width: stripWindow.hoverWidth
            y: 2; height: attached ? 36 : 34
            topLeftRadius: 17; topRightRadius: 17
            bottomLeftRadius: attached ? 0 : 17; bottomRightRadius: bottomLeftRadius
            color: App.palette.bg
            ConcaveCorner { curveRadius: 12; inverted: true; x: -width; y: hoverPill.height - height; visible: hoverPill.attached }
            ConcaveCorner { curveRadius: 12; inverted: true; mirrored: true; x: hoverPill.width; y: hoverPill.height - height; visible: hoverPill.attached }
            opacity: stripWindow.highlightItem ? 1 : 0
            Behavior on x { NumberAnimation { duration: App.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: App.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: App.reducedMotion ? 0 : 100 } }
        }
        Row {
            id: row; x: 6; height: 38; spacing: 7
            Repeater {
                model: SystemTray.items.values.filter(item => !["nm_applet", "nm-applet"].includes(item.id))
                delegate: Item {
                    id: tray
                    required property var modelData
                    visible: !["nm_applet", "nm-applet"].includes(modelData.id)
                    width: visible ? 42 : 0; height: 38
                    IconImage {
                        id: trayImage; anchors.centerIn: parent; implicitSize: 18
                        source: tray.modelData.icon
                        layer.enabled: true
                        layer.effect: ColorOverlay { color: App.palette.accent }
                    }
                    MouseArea {
                        id: trayPointer; anchors.fill: parent; hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onEntered: stripWindow.enterItem(tray, "")
                        onExited: stripWindow.leaveItem(tray)
                        onClicked: event => {
                            stripWindow.sliderKind = "";
                            if (event.button === Qt.RightButton || tray.modelData.onlyMenu) tray.modelData.display(stripWindow, tray.x + row.x, 38);
                            else if (event.button === Qt.MiddleButton) tray.modelData.secondaryActivate();
                            else tray.modelData.activate();
                        }
                        onWheel: event => tray.modelData.scroll(event.angleDelta.y, false)
                    }
                    Accessible.role: Accessible.Button; Accessible.name: modelData.tooltipTitle || modelData.title
                    Accessible.onPressAction: modelData.activate()
                    ToolTip {
        popupType: Popup.Window; y: 38
                        visible: trayPointer.containsMouse; delay: 700; text: tray.modelData.tooltipTitle || tray.modelData.title
                        contentItem: Text { text: tray.modelData.tooltipTitle || tray.modelData.title; color: App.palette.text; font.pixelSize: 12 }
                        background: Rectangle { color: App.palette.surface; radius: 8; border.color: App.palette.muted }
                    }
                }
            }
            BarItem {
                id: brightnessButton
                bar: stripWindow; minimumWidth: 70; glyph: "󰃠"; label: (App.data.brightness?.available ? App.data.brightness.value : "—") + "%"
                hint: "Brightness"; sliderKind: "brightness"
                onClicked: button => button === Qt.RightButton ? stripWindow.settings("brightness") : stripWindow.requestSlider("brightness")
                onScrolled: direction => App.action("brightness", Math.max(5, Math.min(100, (App.data.brightness?.value || 5) + direction * 5)))
            }
            BarItem {
                id: volumeButton
                bar: stripWindow; minimumWidth: 67; glyph: stripWindow.volumeGlyph; iconSize: 19
                iconColor: App.data.audio?.muted ? App.palette.muted : App.palette.accent
                label: (App.data.audio?.available ? App.data.audio.volume : "—") + "%"; hint: "Volume"; sliderKind: "volume"
                onClicked: button => {
                    if (button === Qt.RightButton) stripWindow.settings("volume");
                    else if (button === Qt.MiddleButton) App.action("mute");
                    else stripWindow.requestSlider("volume");
                }
                onScrolled: direction => App.action("volume", Math.max(0, Math.min(100, (App.data.audio?.volume || 0) + direction * 5)))
            }
            BarItem {
                id: wifiButton
                bar: stripWindow; minimumWidth: 127; glyph: App.data.network?.ssid ? "󰤨" : "󰤭"
                iconColor: App.data.network?.ssid ? App.palette.accent : App.palette.muted
                label: (App.data.network?.ssid || "").slice(0, 20); hint: App.data.network?.ssid || "Wi-Fi disconnected"
                onClicked: button => { if (button === Qt.RightButton) stripWindow.launch(["systemsettings", "kcm_networkmanagement"]); else if (button === Qt.LeftButton) stripWindow.showMenu("wifi"); }
            }
            BarItem {
                bar: stripWindow; minimumWidth: 73; glyph: App.batteryGlyph; label: App.battery; hint: "Battery"
                iconColor: parseInt(App.battery) <= 15 ? "#e18593" : parseInt(App.battery) <= 30 ? "#dfb479" : App.palette.accent
                onClicked: button => stripWindow.launch(button === Qt.RightButton ? ["kcmshell6", "kcm_energyinfo"] : ["systemsettings", "kcm_powerdevilprofilesconfig"])
            }
            BarItem {
                bar: stripWindow; minimumWidth: 39; glyph: App.data.notifications?.dnd ? "󰂛" : "󰂚"; iconSize: 16
                hint: App.data.notifications?.dnd ? "Do not disturb" : "Notifications"
                iconColor: App.data.notifications?.dnd ? App.palette.muted : App.palette.accent
                onClicked: button => stripWindow.launch(["makoctl"].concat(button === Qt.MiddleButton ? ["mode", "-t", "do-not-disturb"] : button === Qt.RightButton ? ["dismiss"] : ["restore"]))
            }
            BarItem {
                id: powerButton
                bar: stripWindow; minimumWidth: 40; glyph: "󰐥"; iconSize: 18; hint: "Power menu"
                onClicked: stripWindow.showMenu("power")
            }
        }
    }
    Item {
        id: lowerReveal; parent: menuFocus; y: 38; width: stripWindow.width; height: 38 * stripWindow.rowReveal
        clip: true; opacity: stripWindow.rowReveal; visible: stripWindow.rowReveal > 0
        enabled: stripWindow.sliderKind !== ""
    ConcaveCorner {
        id: lowerShoulder
        curveRadius: Math.min(12, Math.max(0, lowerBar.x - topBar.bottomLeftRadius))
        x: lowerBar.x - width; y: lowerBar.y
        visible: false
        HoverHandler { onHoveredChanged: { if (hovered) closeDelay.stop(); else closeDelay.restart(); } }
    }
    Rectangle {
        id: lowerBar; anchors.right: parent.right; y: 0
        width: Math.round(stripWindow.width * 0.95); height: 38
        color: App.palette.bg; topLeftRadius: 19; bottomLeftRadius: 19
        HoverHandler { id: lowerHover; onHoveredChanged: { if (hovered) closeDelay.stop(); else closeDelay.restart(); } }
        RowLayout {
            visible: !stripWindow.thirdLayer
            anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 18; spacing: 12
            ShellButton {
                glyph: stripWindow.volume ? stripWindow.volumeGlyph : "󰃠"; text: stripWindow.volume ? "Mute" : "Brightness settings"
                small: true; implicitWidth: 32; implicitHeight: 32
                onClicked: { if (stripWindow.volume) App.action("mute"); else stripWindow.settings("brightness"); }
            }
            Slider {
                id: slider; Layout.fillWidth: true; from: stripWindow.volume ? 0 : 5; to: 100; stepSize: 1
                enabled: stripWindow.volume ? !!App.data.audio?.available : !!App.data.brightness?.available
                value: stripWindow.level
                Behavior on value { enabled: !slider.pressed; NumberAnimation { duration: App.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }
                Accessible.name: stripWindow.volume ? "Volume" : "Brightness"
                onMoved: { pendingKind = stripWindow.sliderKind; pending = value; if (!throttle.running) throttle.start(); }
                onPressedChanged: if (!pressed) { flush(); if (!stripWindow.clickMenu && !lowerHover.hovered) closeDelay.restart(); }
                property string pendingKind: ""
                property real pending: -1
                function flush() {
                    throttle.stop();
                    if (pending >= 0) { App.action(pendingKind, pending); pending = -1; }
                }
                Timer { id: throttle; interval: 50; onTriggered: slider.flush() }
                background: Rectangle {
                    x: slider.leftPadding; y: slider.topPadding + slider.availableHeight / 2 - 4
                    width: slider.availableWidth; height: 8; radius: 4; color: App.palette.surface
                    Rectangle { width: slider.visualPosition * parent.width; height: parent.height; radius: 4; color: App.palette.accent }
                }
                handle: Rectangle {
                    x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                    y: slider.topPadding + slider.availableHeight / 2 - height / 2
                    width: 16; height: 16; radius: 8; color: App.palette.text
                }
            }
            ShellButton { glyph: "󰅂"; text: stripWindow.volume ? "Sound settings" : "Brightness settings"; small: true; implicitWidth: 28; implicitHeight: 32; onClicked: stripWindow.settings(stripWindow.displayedSliderKind) }
        }

        RowLayout {
            visible: stripWindow.displayedSliderKind === "wifi"
            anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 18; spacing: 12
            ShellButton { small: true; implicitWidth: 32; implicitHeight: 32; glyph: "󰖩"; text: "Wi-Fi"; focusPolicy: Qt.NoFocus }
            TextField {
                id: wifiSearch; Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0; clip: true; background: null; padding: 0
                font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 13; color: App.palette.text
                Accessible.name: stripWindow.passwordNetwork ? "Password for " + stripWindow.passwordNetwork.ssid : "Search networks"
                placeholderTextColor: App.palette.muted
                placeholderText: stripWindow.passwordNetwork ? "Password for " + stripWindow.passwordNetwork.ssid : "Search"
                echoMode: stripWindow.passwordNetwork ? TextInput.Password : TextInput.Normal
                onTextChanged: stripWindow.currentNetwork = -1
            }
            ShellButton { small: true; implicitWidth: 32; implicitHeight: 32; glyph: "󰑐"; text: "Rescan"; focusPolicy: Qt.NoFocus; onClicked: stripWindow.wifiCall(["rescan"]) }
            ShellButton {
                visible: stripWindow.networks.some(n => n.connected); small: true; implicitWidth: 32; implicitHeight: 32; glyph: "󰖪"; text: "Disconnect"; focusPolicy: Qt.NoFocus
                onClicked: { const n = stripWindow.networks.find(n => n.connected); if (n?.activeUuid) stripWindow.wifiCall(["disconnect", n.activeUuid]); }
            }
            ShellButton { small: true; implicitWidth: 32; implicitHeight: 32; glyph: stripWindow.radio ? "󰖩" : "󰖪"; opacity: stripWindow.radio ? 1 : 0.4; text: "Wi-Fi radio"; focusPolicy: Qt.NoFocus; onClicked: stripWindow.wifiCall(["radio", stripWindow.radio ? "off" : "on"]) }
        }
        Row {
            visible: stripWindow.displayedSliderKind === "power"; anchors.fill: parent
            Repeater {
                model: 5
                delegate: Item {
                    required property int index
                    width: lowerBar.width / 5; height: 38
                    ShellButton {
                        anchors.centerIn: parent; small: true; implicitWidth: 32; implicitHeight: 32
                        glyph: stripWindow.powerGlyphs[parent.index]; text: stripWindow.powerNames[parent.index]; focusPolicy: Qt.NoFocus
                        onHoveredChanged: if (hovered) stripWindow.choosePower(parent.index)
                        onClicked: stripWindow.activatePower(parent.index)
                        background: Rectangle { radius: 16; color: stripWindow.armedPower === parent.parent.index ? "#e18593" : App.tone(App.palette.surface, parent.hovered, parent.down) }
                    }
                }
            }
        }
    }
    }
    Item {
        id: detailClip; parent: menuFocus; y: 76; width: stripWindow.width
        height: detailBar.height * stripWindow.detailReveal; clip: true; opacity: stripWindow.detailReveal; visible: height > 0
        enabled: stripWindow.clickMenu
        ConcaveCorner { visible: false; x: detailBar.x - width; y: 0; curveRadius: 12 }
        Rectangle {
            id: detailBar; anchors.right: parent.right; width: Math.round(lowerBar.width * 0.95)
            height: 16 + (stripWindow.displayedSliderKind === "power" ? 34 : Math.min(6, stripWindow.filteredNetworks.length + (stripWindow.wifiError ? 1 : 0)) * 34)
            color: App.palette.bg; topLeftRadius: 19; bottomLeftRadius: 19
            Column {
                visible: stripWindow.displayedSliderKind === "wifi"; x: 10; y: 8; width: parent.width - 20
                MenuRow { width: parent.width; visible: stripWindow.wifiError !== ""; height: visible ? 34 : 0; glyph: "󰀦"; iconColor: "#e18593"; label: stripWindow.wifiError }
                ListView {
                    id: networkList; width: parent.width; height: Math.min(stripWindow.wifiError ? 5 : 6, count) * 34; clip: true
                    model: stripWindow.filteredNetworks
                    delegate: MenuRow {
                        required property var modelData
                        required property int index
                        width: networkList.width
                        glyph: modelData.signal < 25 ? "󰤟" : modelData.signal < 50 ? "󰤢" : modelData.signal < 75 ? "󰤥" : "󰤨"
                        label: modelData.ssid; selected: modelData.connected || index === stripWindow.currentNetwork
                        onClicked: stripWindow.activateNetwork(modelData)
                        trailing: [
                            Rectangle { width: 6; height: 6; radius: 3; anchors.verticalCenter: parent.verticalCenter; visible: !!modelData.uuid || modelData.connected; color: modelData.connected ? App.palette.accent : "transparent"; border.width: 1; border.color: App.palette.accent },
                            Text { text: "󰌾"; visible: modelData.secured; color: App.palette.muted; font.family: "Symbols Nerd Font"; font.pixelSize: 16 }
                        ]
                    }
                }
            }
            MenuRow {
                visible: stripWindow.displayedSliderKind === "power"; x: 10; y: 8; width: parent.width - 20
                glyph: stripWindow.powerGlyphs[stripWindow.powerIndex]
                iconColor: stripWindow.armedPower >= 0 ? "#e18593" : App.palette.accent
                label: stripWindow.powerNames[stripWindow.powerIndex] + (stripWindow.armedPower >= 0 ? "? Click again" : "")
                onClicked: stripWindow.activatePower(stripWindow.powerIndex)
            }
        }
    }

}
