pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
Row {
    id: root
    property bool barIsland: false
    spacing: 5
    readonly property var entries: {
        let ids = [1,2,3,4,5];
        for (const w of Hyprland.workspaces.values) if (w.id > 5 && !ids.includes(w.id)) ids.push(w.id);
        return ids.sort((a,b)=>a-b);
    }
    Repeater {
        model: root.entries
        Rectangle {
            id: dot
            required property var modelData
            readonly property bool current: Hyprland.focusedWorkspace?.id === modelData
            readonly property var workspace: Hyprland.workspaces.values.find(w => w.id === modelData) || null
            readonly property bool occupied: (workspace?.toplevels?.values?.length || 0) > 0
            readonly property bool urgent: !!workspace?.urgent
            width: current ? 22 : 9; height: 9; radius: 5
            anchors.verticalCenter: parent.verticalCenter
            // Empty stays faded; occupied is solid; attention overrides with the warning colour.
            color: urgent ? "#dfb479" : current ? App.palette.accent : App.palette.muted
            opacity: current || occupied || urgent ? 1 : hit.containsMouse ? 0.8 : 0.35
            Behavior on width { NumberAnimation { duration: App.reducedMotion ? 0 : 150 } }
            Accessible.role: Accessible.Button
            Accessible.name: "Workspace " + modelData
            Behavior on opacity { NumberAnimation { duration: App.reducedMotion ? 0 : 100 } }
            // Above the island's click-to-open surface, so a dot click only switches workspace.
            MouseArea {
                id: hit; anchors.fill: parent; anchors.margins: -4; anchors.leftMargin: -2; anchors.rightMargin: -2; hoverEnabled: true
                onEntered: App.hoveredWorkspace = dot.modelData
                onClicked: { if (root.barIsland) App.openBarOverview(dot.modelData); else { App.hoverOverview(); App.pinOverview(); } }
            }
        }
    }
}
