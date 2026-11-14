import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Item {
    id: root
    property string title
    property string glyph
    property real level: 0
    property real minimum: 0
    property bool available: true
    signal changed(real value)
    signal iconClicked()
    signal settingsClicked()
    implicitHeight: 72
    Rectangle { anchors.fill: parent; color: App.palette.surface; radius: 18; opacity: root.available ? 1 : 0.45 }
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 10; spacing: 1
        RowLayout {
            ShellText { text: root.title; Layout.fillWidth: true; font.pixelSize: 12 }
            ShellText { text: root.available ? Math.round(slider.value) + "%" : "Unavailable"; font.pixelSize: 11; color: App.palette.muted }
        }
        RowLayout {
            spacing: 8
            ShellButton { small: true; glyph: root.glyph; text: root.title; implicitWidth: 28; implicitHeight: 30; enabled: root.available; onClicked: root.iconClicked(); onSecondaryClicked: root.settingsClicked() }
            Slider {
                id: slider; Layout.fillWidth: true; from: root.minimum; to: 100; stepSize: 1; enabled: root.available
                Accessible.name: root.title
                value: root.level
                onMoved: { root.pending = value; if (!throttle.running) throttle.start(); }
                onPressedChanged: if (!pressed && root.pending >= 0) { throttle.stop(); root.changed(root.pending); root.pending = -1; }
                background: Rectangle {
                    x: slider.leftPadding; y: slider.topPadding + slider.availableHeight / 2 - height/2
                    width: slider.availableWidth; height: 16; radius: 8; color: App.palette.bg
                    Rectangle { width: slider.visualPosition * parent.width; height: parent.height; radius: 8; color: App.palette.accent }
                }
                handle: Rectangle { x: slider.leftPadding + slider.visualPosition*(slider.availableWidth-width); y: slider.topPadding + slider.availableHeight/2-height/2; width: 18; height: 18; radius: 9; color: App.palette.text; visible: slider.hovered || slider.pressed || slider.activeFocus }
            }
            ShellButton { small: true; glyph: "󰅂"; text: root.title + " settings"; implicitWidth: 26; implicitHeight: 30; onClicked: root.settingsClicked() }
        }
    }
    property real pending: -1
    Timer { id: throttle; interval: 50; onTriggered: { if (root.pending >= 0) { root.changed(root.pending); root.pending = -1; } } }
}
