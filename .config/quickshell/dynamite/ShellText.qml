import QtQuick
import QtQuick.Controls
Text {
    id: label
    color: App.palette.text
    font.family: "Inter"
    font.pixelSize: 14
    elide: Text.ElideRight
    textFormat: Text.PlainText
    // Elided text reveals itself on hover; nothing is created for text that fits.
    HoverHandler { id: hover; enabled: label.truncated }
    Loader {
        active: label.truncated && hover.hovered
        sourceComponent: ToolTip {
            visible: true; delay: 500; text: label.text
            contentItem: Text { text: label.text; color: App.palette.text; font.family: "Inter"; font.pixelSize: 12; wrapMode: Text.Wrap }
            background: Rectangle { color: App.palette.surface; radius: 10; border.width: 1; border.color: Qt.tint(App.palette.surface, "#40" + App.palette.accent.slice(1)) }
        }
    }
}
