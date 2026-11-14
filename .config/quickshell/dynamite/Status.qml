import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
Item {
    SystemClock { id: clock; precision: SystemClock.Minutes }
    RowLayout {
        anchors.fill: parent; anchors.margins: 12; anchors.bottomMargin: App.player ? 20 : 12; spacing: 24
        ColumnLayout {
            Layout.fillWidth: true; Layout.preferredWidth: 160; spacing: 10
            ShellText { Layout.fillWidth: true; text: Hyprland.activeToplevel?.title || "Desktop"; font.pixelSize: 12 }
            Workspaces { }
        }
        ColumnLayout {
            Layout.fillWidth: true; Layout.preferredWidth: 300; spacing: 10
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                ShellText { text: Qt.formatDateTime(clock.date, "HH:mm"); font.pixelSize: 24; font.weight: Font.DemiBold }
                ShellText { text: Qt.formatDateTime(clock.date, "ddd, d MMM"); font.pixelSize: 12; color: App.palette.muted }
            }
            Rectangle {
                visible: App.player !== null; Layout.fillWidth: true; Layout.preferredHeight: 58; radius: 18; color: App.palette.surface
                MusicControls { anchors.fill: parent; anchors.margins: 7 }
            }
        }
        ColumnLayout {
            Layout.preferredWidth: 120; spacing: 10
            ShellText { Layout.alignment: Qt.AlignRight; text: App.data.notifications?.activeCount ? App.data.notifications.activeCount + " notifications" : "All caught up"; font.pixelSize: 11; color: App.palette.muted }
            RowLayout {
                Layout.alignment: Qt.AlignRight; spacing: 6
                ShellText { text: (App.data.network?.ssid ? "󰤨  " : "󰤭  ") + App.batteryGlyph; color: App.palette.accent; font.pixelSize: 18; font.family: "Symbols Nerd Font" }
                ShellText { text: App.battery; font.pixelSize: 18 }
            }
        }
    }
}
