pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "menus"

PanelWindow {
    id: stripWindow
    property bool fullscreen: false
    property bool behindWindow: false
    property color baseColor: App.palette.bg
    property alias menuFrame: frame
    property alias wifi: wifiMenu
    property alias power: powerMenu
    property alias battery: batteryMenu
    property alias notifications: notificationsMenu
    property alias toast: toastMenu
    property alias calendar: calendarMenu
    property alias tray: trayMenu
    property alias brightness: sliderMenu
    property alias volume: sliderMenu
    property alias brightnessAnchor: brightnessButton
    property alias volumeAnchor: volumeButton
    function trayAt(index) { return trayItems.itemAt(index); }
    SystemClock { id: barClock; precision: SystemClock.Minutes }
    anchors { top: true; right: true }
    margins.top: App.barTop
    implicitWidth: row.implicitWidth + 16
    Binding { target: App; property: "sideWidth"; value: stripWindow.implicitWidth }
    implicitHeight: 38 + 38 + 4 + 38 + 30 + 6 * 30
    color: "transparent"
    visible: !fullscreen && App.barsShown
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: behindWindow ? WlrLayer.Bottom : WlrLayer.Top
    WlrLayershell.namespace: "dynamite-right-bar"
    WlrLayershell.keyboardFocus: frame.pinned ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: frame.inputMask
    onFullscreenChanged: if (fullscreen) { frame.close(); frame.hoveredItem = null; }
    Rectangle {
        id: topBar; x: App.barJoined ? App.barHeight / 2 : 0; width: stripWindow.width - x; height: 38
        color: App.barFill; topLeftRadius: App.barJoined ? 0 : 19; bottomLeftRadius: topLeftRadius
        Row {
            id: row; z: 1; x: topBar.width - implicitWidth - 10; height: 38; spacing: 7
            Repeater {
                id: trayItems
                model: SystemTray.items.values.filter(item => !["nm_applet", "nm-applet"].includes(item.id))
                delegate: Item {
                    id: tray
                    required property var modelData
                    visible: !["nm_applet", "nm-applet"].includes(modelData.id)
                    width: visible ? 18 + 2 * App.itemPadding : 0; height: 38
                    IconImage {
                        id: trayImage; anchors.centerIn: parent; implicitSize: 18
                        source: tray.modelData.icon
                        layer.enabled: true
                        layer.effect: IconTint { color: App.palette.accent }
                    }
                    MouseArea {
                        id: trayPointer; anchors.fill: parent; hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onEntered: { trayMenu.source = tray; frame.enterItem(tray, trayMenu); }
                        onExited: frame.leaveItem(tray)
                        onClicked: event => {
                            frame.show(null, false);
                            if (event.button === Qt.RightButton || tray.modelData.onlyMenu) tray.modelData.display(stripWindow, tray.x + row.x, 38);
                            else if (event.button === Qt.MiddleButton) tray.modelData.secondaryActivate();
                            else tray.modelData.activate();
                        }
                        onWheel: event => tray.modelData.scroll(event.angleDelta.y, false)
                    }
                    Accessible.role: Accessible.Button; Accessible.name: modelData.tooltipTitle || modelData.title
                    Accessible.onPressAction: modelData.activate()
                }
            }
            BarItem {
                id: wifiButton
                visible: !!App.data.network?.available || App.adapter !== null
                bar: frame; glyph: App.data.network?.kind === "ethernet" ? "󰈀" : App.data.network?.ssid ? "󰤨" : "󰤭"
                label: { const ssid = App.data.network?.kind === "ethernet" ? "" : App.data.network?.ssid || ""; return ssid.length > 12 ? ssid.slice(0, 12) + "…" : ssid; } hint: App.data.network?.connected ? App.data.network.connection || App.data.network.device : "Network disconnected"; menu: wifiMenu
                onClicked: button => { if (button === Qt.RightButton) App.settings("network"); else if (button === Qt.LeftButton) frame.show(wifiMenu, true); }
            }
            BarItem {
                id: volumeButton
                visible: !!App.data.audio?.available
                bar: frame; labelReserve: "100%"; glyph: sliderMenu.volumeGlyph; iconSize: 20; iconBox: 22
                label: (App.data.audio?.available ? App.data.audio.volume : "—") + "%"; hint: "Volume"; menu: sliderMenu
                onClicked: button => {
                    if (button === Qt.RightButton) sliderMenu.settings("volume");
                    else App.action("mute");
                }
                onScrolled: direction => App.action("volume", Math.max(0, Math.min(100, (App.data.audio?.volume || 0) + direction * 5)))
            }
            BarItem {
                id: brightnessButton
                visible: !!App.data.brightness?.available
                bar: frame; labelReserve: "100%"; glyph: "󰃠"; iconSize: 17; label: (App.data.brightness?.available ? App.data.brightness.value : "—") + "%"
                hint: "Brightness"; menu: sliderMenu
                onClicked: button => button === Qt.RightButton ? sliderMenu.settings("brightness") : Quickshell.execDetached([App.home + "/.local/bin/bar-menu-guard", "qs", "-c", "dynamite", "ipc", "call", "dynamite", "slider", "brightness"])
                onScrolled: direction => App.action("brightness", Math.max(5, Math.min(100, (App.data.brightness?.value || 5) + direction * 5)))
            }
            BarItem {
                id: batteryButton
                visible: App.hasBattery
                menu: batteryMenu
                bar: frame; labelReserve: "100%"; glyph: App.batteryGlyph; label: App.battery; hint: "Battery"
                iconSize: 18
                alertColor: UPower.displayDevice?.state === UPowerDeviceState.Charging ? "transparent" : parseInt(App.battery) <= 15 ? "#e18593" : parseInt(App.battery) <= 30 ? "#dfb479" : "transparent"
                iconColor: alertColor.a > 0 ? alertColor : App.palette.accent
                onClicked: button => { if (button === Qt.RightButton) App.settings("battery"); }
            }
            BarItem {
                id: notificationsButton
                menu: notificationsMenu
                bar: frame; glyph: Notifications.notifications?.dnd ? "󰂛" : "󰂚"; iconSize: 18; iconBox: 20
                hint: Notifications.notifications?.dnd ? "Do not disturb" : "Notifications"
                alertColor: (Notifications.notifications?.items || []).some(n => n.urgency === "critical") ? "#e18593" : "transparent"
                iconColor: alertColor.a > 0 ? alertColor : App.palette.accent
                onClicked: button => App.action(button === Qt.RightButton ? "notifications-clear" : "focus")
            }
            BarItem {
                id: powerButton
                bar: frame; glyph: "󰐥"; iconSize: 20; hint: "Power menu"; menu: powerMenu
                onClicked: frame.show(powerMenu, true)
            }
            BarItem {
                id: clockButton
                bar: frame; label: Qt.formatDateTime(barClock.date, "HH:mm")
                hint: Qt.formatDate(barClock.date, "dddd d MMMM yyyy"); menu: calendarMenu
                onClicked: button => { if (button === Qt.LeftButton) frame.show(calendarMenu, true); }
            }
        }
    }

    MenuFrame { id: frame; anchors.fill: parent; hostWindow: stripWindow; background: topBar
        onActiveMenuChanged: {
            if (activeMenu !== toastMenu && Notifications.toast) Notifications.interruptToast();
            if (!activeMenu) Qt.callLater(Notifications.showNextToast);
        }
    }
    SliderMenu { id: sliderMenu; frame: frame; anchor: brightnessButton; kind: anchor === volumeButton ? "volume" : "brightness"; l2.parent: frame.lowerContent }
    WifiMenu { id: wifiMenu; frame: frame; anchor: wifiButton; l2.parent: frame.lowerContent; l3.parent: frame.detailContent }
    PowerMenu { id: powerMenu; frame: frame; anchor: powerButton; l2.parent: frame.lowerContent; l3.parent: frame.detailContent }
    BatteryMenu { id: batteryMenu; frame: frame; anchor: batteryButton; l2.parent: frame.lowerContent }
    NotificationsMenu { id: notificationsMenu; frame: frame; anchor: notificationsButton; l2.parent: frame.lowerContent; l3.parent: frame.detailContent }
    ToastMenu { id: toastMenu; frame: frame; anchor: notificationsButton; l2.parent: frame.lowerContent; l3.parent: frame.detailContent }
    CalendarMenu { id: calendarMenu; frame: frame; anchor: clockButton; l2.parent: frame.lowerContent; l3.parent: frame.detailContent }
    TitleMenu { id: trayMenu; frame: frame; l2.parent: frame.lowerContent }
    Binding { target: Notifications; property: "toastHovered"; value: frame.lowerHovered || frame.detailHovered || frame.hoveredItem === notificationsButton }
    Binding { target: Notifications; property: "toastBlocked"; value: App.modal || Notifications.otherMenuOpen || (frame.hoveredItem !== null && frame.hoveredItem !== notificationsButton) || !App.barsShown || stripWindow.fullscreen || (frame.activeMenu !== null && frame.activeMenu !== toastMenu) }
    Binding { target: Notifications; property: "fullscreen"; value: stripWindow.fullscreen }
    Connections {
        target: Notifications
        function onToastShown() { frame.show(toastMenu, false); }
        function onToastHidden() { if (frame.activeMenu === toastMenu) frame.close(); }
    }
}
