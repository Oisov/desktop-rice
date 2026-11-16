pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import ".."

Item {
    id: menu
    property Item anchor: null
    readonly property bool pinnable: true
    function key(event) {
        if ([Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].includes(event.key)) choosePower((powerIndex + ([Qt.Key_Left, Qt.Key_Up].includes(event.key) ? 4 : 1)) % 5);
        else if ([Qt.Key_Return, Qt.Key_Enter].includes(event.key)) activatePower(powerIndex);
        else return false;
        return true;
    }
    function refresh() { App.refresh(); }
    required property var frame
    function opened() { armedPower = -1; confirmTimer.stop(); }
    function closed() { armedPower = -1; confirmTimer.stop(); }
    property int powerIndex: 0
    property bool awakeHovered: false
    property int armedPower: -1
    readonly property var powerNames: ["Lock", "Suspend", "Log out", "Restart", "Shut down"]
    readonly property var powerGlyphs: ["󰌾", "󰒲", "󰍃", "󰜉", "󰐥"]
    function armTimer() { confirmTimer.restart(); }
    function choosePower(index) {
        if (powerIndex !== index) { armedPower = -1; confirmTimer.stop(); }
        powerIndex = index;
    }
    function activatePower(index) {
        choosePower(index);
        if (index >= 2 && armedPower !== index) { armedPower = index; confirmTimer.restart(); return; }
        const commands = [["hyprlock"], ["systemctl", "suspend"], ["hyprctl", "eval", "hl.dispatch(hl.dsp.exit())"], ["systemctl", "reboot"], ["systemctl", "poweroff"]];
        frame.close(); Quickshell.execDetached(commands[index]);
    }
    Timer { id: confirmTimer; interval: 4000; onTriggered: menu.armedPower = -1 }
    property Item l2: Row {
            visible: menu.frame.displayedMenu === menu; anchors.fill: parent
            Item {
                width: menu.frame.lowerWidth / 7; height: 38
                ShellButton { anchors.centerIn: parent; small: true; implicitWidth: 32; implicitHeight: 32; padding: 0; glyph: "󰒲"; text: "Keep awake"; active: App.keepAwake; focusPolicy: Qt.NoFocus; onHoveredChanged: menu.awakeHovered = hovered; onClicked: App.keepAwake = !App.keepAwake }
            }
            Item { width: menu.frame.lowerWidth / 7; height: 38 }
            Repeater {
                model: 5
                delegate: Item {
                    required property int index
                    width: menu.frame.lowerWidth / 7; height: 38
                    ShellButton {
                        anchors.centerIn: parent; small: true; implicitWidth: 32; implicitHeight: 32
                        glyph: menu.powerGlyphs[parent.index]; text: menu.powerNames[parent.index]; focusPolicy: Qt.NoFocus
                        onHoveredChanged: if (hovered) menu.choosePower(parent.index)
                        onClicked: menu.activatePower(parent.index)
                        background: Rectangle { radius: 16; color: menu.armedPower === parent.parent.index ? "#e18593" : App.tone(App.palette.surface, parent.hovered, parent.down) }
                    }
                }
            }
        }
    property Item l3: Item {
        anchors.fill: parent
        implicitHeight: 38
            MenuRow {
                visible: menu.frame.displayedMenu === menu; x: 10; y: 2; width: parent.width - 20
                glyph: menu.awakeHovered ? "󰒲" : menu.powerGlyphs[menu.powerIndex]
                iconColor: menu.armedPower >= 0 ? "#e18593" : App.palette.accent
                label: menu.awakeHovered ? "Keep awake · " + (App.keepAwake ? "On" : "Off") : menu.powerNames[menu.powerIndex] + (menu.armedPower >= 0 ? "? Click again" : "")
                onClicked: { if (menu.awakeHovered) App.keepAwake = !App.keepAwake; else menu.activatePower(menu.powerIndex); }
            }
    }
}
