pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.UPower
import ".."

Item {
    id: menu
    property Item anchor: null
    function refresh() { App.refresh(); }
    required property var frame
    readonly property string batteryStatus: {
        const device = UPower.displayDevice;
        if (!device?.isPresent) return "";
        if (device.state === UPowerDeviceState.FullyCharged || (device.state === UPowerDeviceState.PendingCharge && device.percentage >= 0.99)) return "Fully charged";
        if (device.state === UPowerDeviceState.Charging) {
            const time = batteryTime(device.timeToFull);
            return "Charging" + (time ? " · full in " + time : "");
        }
        const time = batteryTime(device.timeToEmpty);
        return time ? time + " left" : "On battery";
    }
    function batteryTime(seconds) {
        if (!Number.isFinite(seconds) || seconds <= 0) return "";
        const minutes = Math.max(1, Math.floor(seconds / 60));
        const hours = Math.floor(minutes / 60);
        return [hours ? hours + " h" : "", minutes % 60 ? minutes % 60 + " min" : ""].filter(Boolean).join(" ");
    }
    property Item l2: RowLayout {
            visible: menu.frame.displayedMenu === menu
            anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 18; spacing: 12
            ShellButton {
                glyph: App.batteryGlyph; text: "Battery"; small: true; implicitWidth: 32; implicitHeight: 32
                enabled: false
                opacity: 1
                background: Rectangle { radius: height / 2; color: App.palette.surface }
            }
            Text {
                Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight
                text: menu.batteryStatus; color: App.palette.text
                font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 13
            }
            Text {
                visible: Math.abs(UPower.displayDevice.changeRate) >= 0.05
                text: Math.abs(UPower.displayDevice.changeRate).toFixed(1) + " W"; color: App.palette.muted
                font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12
            }
            ShellButton { visible: !!App.data.settings?.battery?.length; glyph: "󰅂"; text: "Energy information"; small: true; implicitWidth: 28; implicitHeight: 32; onClicked: App.settings("battery") }
        }
}
