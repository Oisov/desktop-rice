import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: music
    property var player: App.player
    property bool layered: false
    property real playhead: 0
    readonly property bool seeking: timeline.pressed || stripTimeline.pressed
    implicitHeight: 44
    function refreshPosition() { if (timeline?.pressed || stripTimeline?.pressed) return; playhead = player?.positionSupported ? Math.max(0, player.position) : 0; }
    onPlayerChanged: refreshPosition()
    Connections {
        target: music.player
        function onPositionChanged() { music.refreshPosition(); }
        function onPositionSupportedChanged() { music.refreshPosition(); }
        function onLengthChanged() { music.refreshPosition(); }
        function onTrackTitleChanged() { music.refreshPosition(); }
    }
    Timer { interval: 1000; running: music.visible && !!music.player; repeat: true; triggeredOnStart: true; onTriggered: music.refreshPosition() }
    RowLayout {
        visible: !music.layered
        anchors.fill: parent; spacing: 8
        Image {
            Layout.preferredWidth: 26; Layout.preferredHeight: 26
            source: music.player?.trackArtUrl || ""; asynchronous: true; fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready
        }
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            Column {
                width: parent.width; y: 4; spacing: 0
                ShellText { width: parent.width; text: music.player?.trackTitle || music.player?.identity || "No media"; font.pixelSize: 12 }
                ShellText { width: parent.width; text: music.player?.trackArtist || ""; font.pixelSize: 10; color: App.palette.muted }
            }
            Slider {
                id: timeline
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.bottomMargin: 1
                height: 8; padding: 0; from: 0; to: Math.max(1, music.player?.length || 0)
                value: Math.min(music.playhead, to)
                visible: !!music.player?.lengthSupported && !!music.player?.positionSupported && music.player.length > 0
                enabled: music.player?.canSeek || false
                Accessible.name: "Track position"
                onPressedChanged: if (!pressed && enabled && music.player) music.player.position = value
                background: Rectangle {
                    y: (timeline.height - height) / 2; width: timeline.availableWidth; height: 2; radius: 1; color: App.palette.surface
                    Rectangle { width: timeline.visualPosition * parent.width; height: parent.height; radius: 1; color: App.palette.accent }
                }
                handle: Rectangle {
                    x: timeline.visualPosition * (timeline.availableWidth - width); y: (timeline.height - height) / 2
                    width: 6; height: 6; radius: 3; color: App.palette.accent; visible: timeline.hovered || timeline.pressed
                }
            }
        }
        RowLayout {
            spacing: 3
            ShellButton { small: true; glyph: "󰒮"; text: "Previous track"; implicitWidth: 26; implicitHeight: 28; enabled: music.player?.canGoPrevious || false; onClicked: music.player.previous() }
            ShellButton { small: true; glyph: music.player?.isPlaying ? "󰏤" : "󰐊"; text: "Play or pause"; implicitWidth: 30; implicitHeight: 30; enabled: music.player?.canTogglePlaying || false; onClicked: music.player.togglePlaying() }
            ShellButton { small: true; glyph: "󰒭"; text: "Next track"; implicitWidth: 26; implicitHeight: 28; enabled: music.player?.canGoNext || false; onClicked: music.player.next() }
        }
    }
    RowLayout {
        visible: music.layered; anchors.fill: parent; spacing: 8
        ShellButton { small: true; glyph: "󰒮"; text: "Previous track"; implicitWidth: 32; implicitHeight: 32; enabled: music.player?.canGoPrevious || false; onClicked: music.player.previous() }
        ShellButton { small: true; glyph: music.player?.isPlaying ? "󰏤" : "󰐊"; text: "Play or pause"; implicitWidth: 32; implicitHeight: 32; enabled: music.player?.canTogglePlaying || false; onClicked: music.player.togglePlaying() }
        ShellButton { small: true; glyph: "󰒭"; text: "Next track"; implicitWidth: 32; implicitHeight: 32; enabled: music.player?.canGoNext || false; onClicked: music.player.next() }
        Slider {
            id: stripTimeline; Layout.fillWidth: true; height: 16; padding: 0; from: 0; to: Math.max(1, music.player?.length || 0)
            value: Math.min(music.playhead, to); enabled: music.player?.canSeek || false
            Accessible.name: "Track position"
            onPressedChanged: if (!pressed && enabled && music.player) music.player.position = value
            background: Rectangle {
                y: (stripTimeline.height - height) / 2; width: stripTimeline.availableWidth; height: 2; radius: 1; color: App.palette.surface
                Rectangle { width: stripTimeline.visualPosition * parent.width; height: parent.height; radius: 1; color: App.palette.accent }
            }
            handle: Rectangle {
                x: stripTimeline.visualPosition * (stripTimeline.availableWidth - width); y: (stripTimeline.height - height) / 2
                width: 6; height: 6; radius: 3; color: App.palette.accent; visible: stripTimeline.hovered || stripTimeline.pressed
            }
        }
        Text {
            readonly property int seconds: Math.floor(music.playhead)
            text: Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0")
            font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12; color: App.palette.muted
        }
    }

}
