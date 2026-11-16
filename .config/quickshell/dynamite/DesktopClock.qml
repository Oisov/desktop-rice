import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    anchors { bottom: true; right: true }
    margins { bottom: 40; right: 48 }
    implicitWidth: 176
    implicitHeight: 264
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "dynamite-desktop-clock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    SystemClock { id: clock; precision: SystemClock.Minutes }
    Column {
        anchors.fill: parent
        Repeater {
            model: ["hh", "mm"]
            Text {
                required property string modelData
                width: 176; height: 132
                text: Qt.formatDateTime(clock.date, modelData)
                font.family: "Barlow Condensed"
                font.weight: Font.Light
                font.features: { "tnum": 1 }
                font.pixelSize: 152
                color: App.palette.text
                style: Text.Outline
                styleColor: "#99000000"
                opacity: 0.8
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Accessible.role: Accessible.StaticText
                Accessible.name: text
            }
        }
    }
}
