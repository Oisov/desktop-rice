pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

Item {
    id: menu
    property Item anchor: null
    function refresh() { App.refresh(); }
    required property var frame
    property string kind: "brightness"
    readonly property bool volume: kind === "volume"
    readonly property real level: volume ? (App.data.audio?.volume || 0) : (App.data.brightness?.value || 5)
    readonly property string volumeGlyph: App.data.audio?.muted ? "󰝟" : "󰕾"
    readonly property bool held: slider.pressed
    function settings(kind) { frame.close(); App.settings(kind); }
    property Item l2: RowLayout {
            visible: menu.frame.displayedMenu === menu
            anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 18; spacing: 12
            ShellButton {
                visible: menu.volume || !!App.data.settings?.brightness?.length
                glyph: menu.volume ? menu.volumeGlyph : "󰃠"; text: menu.volume ? "Mute" : "Brightness settings"
                small: true; implicitWidth: 32; implicitHeight: 32
                onClicked: { if (menu.volume) App.action("mute"); else menu.settings("brightness"); }
            }
            Slider {
                id: slider; Layout.fillWidth: true; Layout.fillHeight: true; from: menu.volume ? 0 : 5; to: 100; stepSize: 1
                enabled: menu.volume ? !!App.data.audio?.available : !!App.data.brightness?.available
                value: menu.level
                Behavior on value { enabled: !slider.pressed; NumberAnimation { duration: App.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }
                Accessible.name: menu.volume ? "Volume" : "Brightness"
                onMoved: { pendingKind = menu.kind; pending = value; if (!throttle.running) throttle.start(); }
                onPressedChanged: if (!pressed) { flush(); if (!menu.frame.pinned && !menu.frame.lowerHovered) menu.frame.restartClose(); }
                property string pendingKind: ""
                property real pending: -1
                function flush() {
                    throttle.stop();
                    if (pending >= 0) { App.action(pendingKind, pending); pending = -1; }
                }
                Timer { id: throttle; interval: 50; onTriggered: slider.flush() }
                background: Rectangle {
                    x: slider.leftPadding; y: slider.topPadding + slider.availableHeight / 2 - 4
                    width: slider.availableWidth; height: 8; radius: 4; color: App.palette.surface
                    Rectangle { width: slider.visualPosition * parent.width; height: parent.height; radius: 4; color: App.palette.accent }
                }
                handle: Rectangle {
                    x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                    y: slider.topPadding + slider.availableHeight / 2 - height / 2
                    width: 16; height: 16; radius: 8; color: App.palette.text
                }
            }
            ShellButton { visible: !!App.data.settings?.[menu.kind]?.length; glyph: "󰅂"; text: menu.volume ? "Sound settings" : "Brightness settings"; small: true; implicitWidth: 28; implicitHeight: 32; onClicked: menu.settings(menu.kind) }
        }
}
