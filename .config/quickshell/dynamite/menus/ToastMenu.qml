pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import ".."

Item {
    id: menu
    function hideToast() { Notifications.hideToast(); }
    readonly property int displayedToastId: Notifications.displayedToastId
    readonly property var toastQueue: Notifications.toastQueue
    readonly property var toast: Notifications.toast
    property Item anchor: null
    readonly property bool autoClose: false
    readonly property bool detailVisible: toastRows > 0
    function interrupt() { Notifications.interruptToast(); }
    required property var frame
    function activateToast(identifier) { Notifications.activateToast(identifier); }
    readonly property var toastItem: Notifications.notifications.items.find(n => n.id === displayedToastId) || null
    readonly property var toastActions: Notifications.notificationById(displayedToastId)?.actions.filter(a => a.identifier !== "default").slice(0, 3) || []
    readonly property int toastRows: (toastItem?.bodyText ? 1 : 0) + (toastActions.length ? 1 : 0)
    property Item l2: MenuRow {
            id: toastRow
            visible: menu.frame.displayedMenu === menu
            x: 10; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 20
            readonly property var item: menu.toastItem
                    readonly property var entry: {
                        const appId = item?.desktop_entry || item?.app_name;
                        return DesktopEntries.applications.values.find(e => e.id === appId || e.id === appId + ".desktop") || DesktopEntries.heuristicLookup(appId);
                    }
                    readonly property string iconName: entry?.icon || item?.app_icon || ""
                    readonly property string symbolicName: iconName.endsWith("-symbolic") ? iconName : iconName + "-symbolic"
                    readonly property string mark: (item?.desktop_entry || item?.app_name || "").toLowerCase().includes("t3code") ? "t3code" : (item?.desktop_entry || "").startsWith("vivaldi") ? item?.desktop_entry : ""
            marquee: true; scrollNow: true
            label: item?.summaryText || item?.app_name || ""
            glyph: toastIcon.status === Image.Ready ? "" : "󰂚"
            iconColor: item?.urgency === "critical" ? "#e18593" : App.palette.accent
            onClicked: menu.activateToast("")
            leading: IconImage {
                id: toastIcon; anchors.centerIn: parent; implicitSize: 18
                source: toastRow.mark ? "file://" + App.home + "/.local/share/icons/dynamite-waybar/apps/" + toastRow.mark + ".png" : toastRow.iconName ? (toastRow.iconName.startsWith("/") ? "file://" + toastRow.iconName : Quickshell.iconPath(Quickshell.hasThemeIcon(toastRow.symbolicName) ? toastRow.symbolicName : toastRow.iconName, true)) : ""
                visible: status === Image.Ready
                layer.enabled: true; layer.effect: IconTint { color: toastRow.iconColor }
            }
            trailing: [
                Text { anchors.verticalCenter: parent.verticalCenter; visible: menu.toastQueue.length > 0; text: "+" + menu.toastQueue.length; color: App.palette.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 13 },
                ShellButton {
                    anchors.verticalCenter: parent.verticalCenter; small: true; padding: 0; implicitWidth: 26; implicitHeight: 26; focusPolicy: Qt.NoFocus
                    glyph: "󰅖"; text: "Dismiss notification"
                    onClicked: { if (menu.toast) Notifications.notificationById(menu.toast.id)?.dismiss(); Notifications.hideToast(); }
                    background: Item { }
                    contentItem: Text { text: parent.glyph; color: App.palette.accent; font.family: "Symbols Nerd Font"; font.pixelSize: 18; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            ]
        }
    property Item l3: Item {
        anchors.fill: parent
        implicitHeight: 4 + toastRows * 34
            Column {
                visible: menu.frame.displayedMenu === menu; x: 10; y: 2; width: parent.width - 20
                MenuRow {
                    width: parent.width; visible: !!menu.toastItem?.bodyText; height: visible ? 34 : 0
                    label: menu.toastItem?.bodyText || ""; marquee: true; scrollNow: true; hoverHighlight: false
                }
                Item {
                    width: parent.width; height: menu.toastActions.length ? 34 : 0
                    Row {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                        Repeater {
                            model: menu.toastActions
                            delegate: Button {
                                required property var modelData
                                height: 26; leftPadding: 12; rightPadding: 12; topPadding: 0; bottomPadding: 0
                                focusPolicy: Qt.NoFocus; hoverEnabled: true
                                text: modelData.text
                                onClicked: menu.activateToast(modelData.identifier)
                                background: Rectangle { radius: 13; color: App.tone(App.palette.surface, parent.hovered, parent.down) }
                                contentItem: Text { text: parent.text; color: App.palette.text; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                    }
                }
            }
    }
}
