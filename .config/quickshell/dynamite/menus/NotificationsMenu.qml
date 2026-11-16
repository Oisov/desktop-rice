pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import ".."

Item {
    id: menu
    property Item anchor: null
    readonly property bool pinnable: true
    readonly property bool pinOnPress: true
    readonly property bool detailVisible: notificationGroups.length > 0
    function key(event) {
        if ([Qt.Key_Up, Qt.Key_Down].includes(event.key)) {
            const count = notificationGroups.length;
            if (count) { currentNotification = currentNotification < 0 ? (event.key === Qt.Key_Up ? count - 1 : 0) : (currentNotification + (event.key === Qt.Key_Up ? count - 1 : 1)) % count; notificationList.positionViewAtIndex(currentNotification, ListView.Contain); }
        } else if (event.key === Qt.Key_Delete) dismissNotification(notificationGroups[Math.max(0, currentNotification)]);
        else if ([Qt.Key_Return, Qt.Key_Enter].includes(event.key)) activateNotification(notificationGroups[Math.max(0, currentNotification)]);
        else return false;
        return true;
    }
    required property var frame
    function opened() { currentNotification = -1; App.refresh(); }
    readonly property var notifications: Notifications.notifications?.items || []
    readonly property bool dnd: Notifications.notifications?.dnd || false
    readonly property var notificationGroups: {
        const groups = [];
        for (const item of notifications) {
            const key = JSON.stringify([item.app_name, item.summary, item.body]);
            const group = groups.find(g => g.key === key);
            if (group) { group.ids.push(item.id); if (item.urgency === "critical") group.critical = true; }
            else groups.push({key: key, item: item, ids: [item.id], critical: item.urgency === "critical"});
        }
        return groups;
    }
    property int currentNotification: -1
    onNotificationGroupsChanged: currentNotification = Math.min(currentNotification, notificationGroups.length - 1)
    function dismissNotification(group) { if (group) App.action("notification-dismiss", group.ids.join(",")); }
    function activateNotification(group) {
        if (!group) return;
        const item = group.item;
        if (Object.keys(item.actions || {}).includes("default")) App.action("notification-invoke", group.ids.join(","));
        else {
            const keys = [item.desktop_entry, item.app_name].filter(Boolean).map(k => k.toLowerCase().replace(/\.desktop$/, ""));
            const window = ToplevelManager.toplevels.values.find(t => keys.some(k => t.appId.toLowerCase() === k || t.appId.toLowerCase().includes(k)));
            if (window) window.activate();
            dismissNotification(group);
        }
    }
    property Item l2: RowLayout {
            visible: menu.frame.displayedMenu === menu
            anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 18; spacing: 12
            ShellButton {
                small: true; implicitWidth: 32; implicitHeight: 32; padding: 0; glyph: "󰂚"; text: "Notifications"; focusPolicy: Qt.NoFocus
                enabled: false; opacity: 1

                background: Item { }
                contentItem: Text { text: parent.glyph; color: App.palette.accent; font.family: "Symbols Nerd Font"; font.pixelSize: 18; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            RowLayout {
                Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: 0
                Text {
                    text: menu.notifications.length === 0 ? "No notifications" : menu.notifications.length + (menu.notifications.length === 1 ? " notification" : " notifications")
                    color: App.palette.text; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 13
                }
                Text {
                    Layout.fillWidth: true; elide: Text.ElideRight; text: menu.dnd ? " · Do not disturb" : ""
                    color: App.palette.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 13
                }
            }
            ShellButton {
                small: true; implicitWidth: 32; implicitHeight: 32; padding: 0; active: menu.dnd; glyph: "󰂛"; text: "Do Not Disturb"; focusPolicy: Qt.NoFocus
                Accessible.checkable: true; Accessible.checked: active
                onClicked: App.action("focus")

                background: Item { }
                contentItem: Text { text: parent.glyph; color: App.palette.accent; font.family: "Symbols Nerd Font"; font.pixelSize: 18; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            ShellButton {
                visible: menu.notifications.length > 0; small: true; implicitWidth: 32; implicitHeight: 32; padding: 0; glyph: "󰎟"; text: "Clear all"; focusPolicy: Qt.NoFocus
                onClicked: App.action("notifications-clear")

                background: Item { }
                contentItem: Text { text: parent.glyph; color: App.palette.accent; font.family: "Symbols Nerd Font"; font.pixelSize: 18; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
    property Item l3: Item {
        anchors.fill: parent
        implicitHeight: 4 + Math.min(6, notificationGroups.length) * 34
            ListView {
                id: notificationList; visible: menu.frame.displayedMenu === menu
                x: 10; y: 2; width: parent.width - 20; height: Math.min(6, count) * 34; clip: true
                model: menu.notificationGroups; boundsBehavior: Flickable.StopAtBounds
                delegate: MenuRow {
                    id: notificationRow
                    required property var modelData
                    required property int index
                    readonly property var item: modelData.item
                    readonly property var entry: {
                        const appId = item.desktop_entry || item.app_name;
                        return DesktopEntries.applications.values.find(e => e.id === appId || e.id === appId + ".desktop") || DesktopEntries.heuristicLookup(appId);
                    }
                    readonly property string iconName: entry?.icon || item.app_icon || ""
                    readonly property string symbolicName: iconName.endsWith("-symbolic") ? iconName : iconName + "-symbolic"
                    readonly property string mark: (item.desktop_entry || item.app_name).toLowerCase().includes("t3code") ? "t3code" : (item.desktop_entry || "").startsWith("vivaldi") ? item.desktop_entry : ""
                    width: notificationList.width; marquee: true; hoverHighlight: true
                    selected: index === menu.currentNotification
                    glyph: notificationIcon.status === Image.Ready ? "" : "󰂚"
                    iconColor: modelData.critical ? "#e18593" : App.palette.accent
                    label: (item.summaryText || item.app_name) + (item.bodyText ? " — " + item.bodyText : "")
                    onClicked: menu.activateNotification(modelData)
                    leading: IconImage {
                        id: notificationIcon; anchors.centerIn: parent; implicitSize: 18
                        source: notificationRow.mark ? "file://" + App.home + "/.local/share/icons/dynamite-waybar/apps/" + notificationRow.mark + ".png" : notificationRow.iconName ? (notificationRow.iconName.startsWith("/") ? "file://" + notificationRow.iconName : Quickshell.iconPath(Quickshell.hasThemeIcon(notificationRow.symbolicName) ? notificationRow.symbolicName : notificationRow.iconName, true)) : ""
                        visible: status === Image.Ready
                        layer.enabled: true; layer.effect: ColorOverlay { color: notificationRow.iconColor }
                    }
                    trailing: [
                        Text { anchors.verticalCenter: parent.verticalCenter; visible: notificationRow.modelData.ids.length > 1; text: "×" + notificationRow.modelData.ids.length; color: App.palette.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 13 },
                        ShellButton {
                            anchors.verticalCenter: parent.verticalCenter; small: true; padding: 0; implicitWidth: 26; implicitHeight: 26; focusPolicy: Qt.NoFocus
                            glyph: "󰅖"; text: "Dismiss notification"
                            onClicked: menu.dismissNotification(notificationRow.modelData)

                background: Item { }
                contentItem: Text { text: parent.glyph; color: App.palette.accent; font.family: "Symbols Nerd Font"; font.pixelSize: 18; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    ]
                }
            }
    }
}
