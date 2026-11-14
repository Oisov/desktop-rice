import QtQuick
import QtQuick.Controls
Button {
    id: control
    property bool active: false
    property string glyph: ""
    property string detail: ""
    property bool small: false
    signal secondaryClicked()
    implicitHeight: small ? 36 : 58
    implicitWidth: small ? 40 : 180
    hoverEnabled: true
    Accessible.name: text + (detail ? ", " + detail : "")
    background: Rectangle {
        radius: height / 2
        color: App.tone(control.active ? Qt.darker(App.palette.accent, 2.7) : App.palette.surface, control.hovered, control.down)
        border.width: control.visualFocus ? 2 : 0
        border.color: App.palette.accent
        opacity: control.enabled ? 1 : 0.4
    }
    contentItem: Row {
        spacing: 10
        leftPadding: control.small ? 0 : 12
        Rectangle {
            width: control.small ? control.availableWidth : 34; height: 34; radius: 17
            anchors.verticalCenter: parent.verticalCenter
            color: control.active ? App.palette.accent : "transparent"
            ShellText { anchors.centerIn: parent; text: control.glyph; font.family: "Symbols Nerd Font"; font.pixelSize: 18; color: control.active ? App.palette.bg : App.palette.accent }
        }
        Column {
            visible: !control.small; anchors.verticalCenter: parent.verticalCenter
            ShellText { text: control.text; font.weight: Font.Medium }
            ShellText { text: control.detail; font.pixelSize: 11; color: App.palette.muted; visible: text !== "" }
        }
    }
    TapHandler { acceptedButtons: Qt.RightButton; onTapped: control.secondaryClicked() }
}
