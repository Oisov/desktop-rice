pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell.Widgets
import ".."

Item {
    id: menu
    property Item anchor: null
    function refresh() { if (!task) App.refresh(); }
    required property var frame
    property bool task: false
    property Item source: null
    onSourceChanged: { anchor = source; if (task && !source && frame.activeMenu === menu) frame.close(); }
    property Item l2: MenuRow {
            visible: menu.frame.displayedMenu === menu
            x: 10; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 20
            hoverHighlight: false; marquee: true; scrollNow: !menu.task && menu.frame.activeMenu === menu
            label: (menu.task ? "" : menu.source?.modelData?.tooltipTitle) || menu.source?.modelData?.title || ""
            leading: IconImage {
                anchors.centerIn: parent; implicitSize: 18; source: menu.task ? menu.source?.iconSource || "" : menu.source?.modelData?.icon || ""
                layer.enabled: true; layer.effect: ColorOverlay { color: App.palette.accent }
            }
            trailing: ShellButton {
                visible: menu.task; anchors.verticalCenter: parent.verticalCenter; small: true; padding: 0; implicitWidth: 26; implicitHeight: 26; focusPolicy: Qt.NoFocus
                glyph: "󰅖"; text: "Close window"
                onClicked: menu.source?.modelData.close()
            }
        }
}
