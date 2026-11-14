pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Item {
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 16; spacing: 10
        GridLayout {
            columns: 3; columnSpacing: 10; rowSpacing: 8; Layout.fillWidth: true
            ShellButton { Layout.fillWidth: true; text: "Wi-Fi"; glyph: "󰤨"; detail: App.data.network?.ssid || (App.data.network?.enabled ? "Disconnected" : "Off"); active: App.data.network?.enabled || false; enabled: App.data.network?.available || false; onClicked: App.action("wifi", active ? "off" : "on"); onSecondaryClicked: App.external([App.home+"/.local/bin/wifi-menu"]) }
            ShellButton { Layout.fillWidth: true; text: "Focus"; glyph: "󰂛"; detail: active ? "On" : "Off"; active: App.data.notifications?.dnd || false; enabled: App.data.notifications?.available || false; onClicked: App.action("focus") }
            ShellButton { small: true; text: "Lock"; glyph: "󰌾"; onClicked: App.external(["loginctl", "lock-session"]) }
            ShellButton { Layout.fillWidth: true; text: "Bluetooth"; glyph: "󰂯"; detail: !App.adapter ? "Unavailable" : active ? "On" : "Off"; active: App.adapter?.enabled || false; enabled: App.adapter !== null; onClicked: App.adapter.enabled = !App.adapter.enabled; onSecondaryClicked: App.external(["systemsettings", "kcm_bluetooth"]) }
            ShellButton { Layout.fillWidth: true; text: "Keep awake"; glyph: "󰒲"; detail: active ? "On" : "Off"; active: App.keepAwake; onClicked: App.keepAwake = !App.keepAwake }
            ShellButton { small: true; text: "Power menu"; glyph: "󰐥"; onClicked: App.external([App.home+"/.local/bin/hypr-power-menu"]) }
        }
        Level { Layout.fillWidth: true; title: "Sound"; glyph: App.data.audio?.muted ? "󰖁" : "󰕾"; level: App.data.audio?.volume || 0; available: App.data.audio?.available || false; onChanged: value => App.action("volume", value); onIconClicked: App.action("mute"); onSettingsClicked: App.external(["pavucontrol"]) }
        Level { Layout.fillWidth: true; title: "Display"; glyph: "󰃠"; minimum: 5; level: App.data.brightness?.value || 5; available: App.data.brightness?.available || false; onChanged: value => App.action("brightness", value); onIconClicked: App.action("brightness", level > 50 ? 30 : 100); onSettingsClicked: App.external(["systemsettings", "kcm_powerdevilprofilesconfig"]) }
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: 18; color: App.palette.surface
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 8
                ShellText { text: "Notifications"; color: App.palette.muted; font.pixelSize: 11 }
                ListView {
                    id: notices; Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 12
                    model: App.data.notifications?.items || []; boundsBehavior: Flickable.StopAtBounds
                    delegate: Column {
                        id: notice
                        required property var modelData
                        width: notices.width; spacing: 3
                        ShellText { width: parent.width; text: notice.modelData.summary || notice.modelData.app_name; font.pixelSize: 12; font.weight: Font.Medium }
                        ShellText { width: parent.width; text: notice.modelData.body || ""; font.pixelSize: 11; color: App.palette.muted; maximumLineCount: 2; wrapMode: Text.Wrap }
                    }
                    ScrollBar.vertical: ScrollBar { }
                    ShellText { text: App.data.notifications?.available ? "No notifications" : "Notifications unavailable"; color: App.palette.muted; font.pixelSize: 12; visible: notices.count === 0 }
                }
            }
        }
    }
    Keys.onEscapePressed: App.close()
}
