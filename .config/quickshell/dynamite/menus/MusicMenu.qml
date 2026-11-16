pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import ".."

Item {
    id: menu
    required property var frame
    property Item anchor: null
    readonly property var player: App.player
    readonly property bool available: !!player
    readonly property bool held: musicControls.seeking
    onPlayerChanged: if (!player && frame.activeMenu === menu) frame.close()
    readonly property var playerWindow: {
        const keys = [player?.desktopEntry, player?.identity].filter(Boolean).map(k => k.toLowerCase());
        return ToplevelManager.toplevels.values.find(t => keys.some(k => t.appId.toLowerCase().includes(k))) || null;
    }
    function jumpToPlayer() { if (playerWindow) playerWindow.activate(); else if (player?.canRaise) player.raise(); }
    property Item l2: MusicControls {
                id: musicControls; layered: true; visible: menu.frame.displayedMenu === menu
                anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 20
            }
    property Item l3: Item {
        anchors.fill: parent; implicitHeight: 38
        visible: menu.frame.displayedMenu === menu
            MenuRow {
                x: 10; y: 2; width: parent.width - 20
                glyph: art.status === Image.Ready ? "" : "󰝚"
                label: [menu.player?.trackTitle || menu.player?.identity || "", menu.player?.trackArtist || ""].filter(Boolean).join(" — ")
                onClicked: menu.jumpToPlayer()
                leading: Rectangle {
                    anchors.centerIn: parent; width: 22; height: 22; radius: 6; color: "transparent"; clip: true; visible: art.status === Image.Ready
                    Rectangle { id: artMask; width: 22; height: 22; radius: 6; visible: false; layer.enabled: true }
                    Image {
                        id: art; anchors.fill: parent; source: menu.player?.trackArtUrl || ""; fillMode: Image.PreserveAspectCrop; asynchronous: true
                        layer.enabled: true
                        layer.effect: MultiEffect { autoPaddingEnabled: false; maskEnabled: true; maskSource: artMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                    }
                }
                id: trackRow; hoverHighlight: false; marquee: true; scrollNow: menu.frame.activeMenu === menu
                trailing: [
                    ShellButton {
                        anchors.verticalCenter: parent.verticalCenter; small: true; padding: 0; implicitWidth: 26; implicitHeight: 26; focusPolicy: Qt.NoFocus
                        glyph: copiedTimer.running ? "󰄬" : "󰆏"; text: "Copy title"
                        onClicked: { Quickshell.execDetached(["wl-copy", "--", trackRow.label]); copiedTimer.restart(); }
                        Timer { id: copiedTimer; interval: 1200 }
                    },
                    ShellButton {
                        anchors.verticalCenter: parent.verticalCenter; small: true; padding: 0; implicitWidth: 26; implicitHeight: 26; focusPolicy: Qt.NoFocus
                        glyph: "󰁔"; text: "Go to player window"; visible: !!menu.playerWindow || !!menu.player?.canRaise
                        onClicked: menu.jumpToPlayer()
                    }
                ]
            }
    }
}
