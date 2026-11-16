pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import ".."

Item {
    id: menu
    required property var frame
    property Item anchor: null
    property var cores: []
    Process {
        command: ["python3", App.helper, "cpu", "--cores"]
        running: menu.frame.activeMenu === menu
        stdout: SplitParser { onRead: line => {
            try { menu.cores = JSON.parse(line).cores; }
            catch (e) { App.error = "Could not read per-core CPU usage"; }
        } }
    }
    property Item l2: RowLayout {
        visible: menu.frame.displayedMenu === menu
        anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 18; spacing: 12
        Text {
            text: "󰍛"; color: App.palette.accent
            font.family: "Symbols Nerd Font"; font.pixelSize: 17
            Layout.preferredWidth: 32; horizontalAlignment: Text.AlignHCenter
        }
        Item {
            id: coreRow
            Layout.fillWidth: true; Layout.fillHeight: true
            readonly property real gap: 5
            readonly property real barWidth: menu.cores.length ? (width - gap * (menu.cores.length - 1)) / menu.cores.length : 0
            Repeater {
                model: menu.cores
                delegate: Rectangle {
                    required property real modelData
                    required property int index
                    x: index * (coreRow.barWidth + coreRow.gap); anchors.verticalCenter: parent.verticalCenter
                    width: coreRow.barWidth; height: 20; radius: 3; color: App.palette.surface
                    Rectangle {
                        // A 2 px floor keeps idle cores visible as a baseline.
                        anchors.bottom: parent.bottom; width: parent.width; radius: parent.radius
                        height: Math.max(2, parent.height * parent.modelData / 100)
                        color: parent.modelData >= 90 ? "#dfb479" : App.palette.accent
                        Behavior on height { NumberAnimation { duration: App.reducedMotion ? 0 : 300; easing.type: Easing.OutCubic } }
                    }
                    Accessible.role: Accessible.ProgressBar
                    Accessible.name: "CPU " + (index + 1)
                    Accessible.description: Math.round(modelData) + "%"
                }
            }
        }
        Text {
            text: App.healthSample.memory?.MemTotal > 0
                ? ((App.healthSample.memory.MemTotal - App.healthSample.memory.MemAvailable) / 1048576).toFixed(1)
                    + " / " + Math.round(App.healthSample.memory.MemTotal / 1048576) + " GB" : "— GB"
            color: App.healthLevels.memory ? App.healthColor(App.healthLevels.memory) : App.palette.text
            font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 13
        }
        Text {
            text: App.healthSample.temperature != null ? Math.round(App.healthSample.temperature) + "°C" : "—°C"
            color: App.healthLevels.temp ? App.healthColor(App.healthLevels.temp) : App.palette.text
            font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 13
        }
    }
}
