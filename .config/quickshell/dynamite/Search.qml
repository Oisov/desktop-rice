import QtQuick
import QtQuick.Controls
TextField {
    id: input
    color: App.palette.text
    font.family: "Inter"; font.pixelSize: 14
    placeholderTextColor: App.palette.muted
    selectByMouse: true
    leftPadding: 14; rightPadding: 12
    implicitHeight: 42
    background: Rectangle { color: App.palette.surface; radius: 12; border.width: input.activeFocus ? 1 : 0; border.color: App.palette.accent }
}
