import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets

Item {
    id: root
    property string appId: ""
    property color tint: App.palette.accent
    property int size: 22
    readonly property string mark: appId.toLowerCase().includes("t3code") ? "t3code" : appId.startsWith("vivaldi") ? appId.replace(/\.desktop$/, "") : ""
    readonly property var entry: DesktopEntries.applications.values.find(e => e.id === appId || e.id === appId + ".desktop") || DesktopEntries.heuristicLookup(appId)
    readonly property string name: entry?.icon || ""
    readonly property string symbolic: name.endsWith("-symbolic") ? name : name + "-symbolic"
    readonly property bool flat: !!mark || !!name && Quickshell.hasThemeIcon(symbolic)
    readonly property alias source: icon.source
    implicitWidth:size; implicitHeight:size
    IconImage {
        id:icon; anchors.fill:parent; implicitSize:root.size
        source:root.mark ? "file://" + App.home + "/.local/share/icons/dynamite-waybar/apps/" + root.mark + ".png" : root.name ? Quickshell.iconPath(root.flat ? root.symbolic : root.name, true) : ""
        visible:!!source.toString() && status !== Image.Error
        layer.enabled:true; layer.effect:root.flat ? flatEffect : shadedEffect
    }
    Component { id:flatEffect; ColorOverlay { color:root.tint } }
    Component { id:shadedEffect; MultiEffect { colorization:1.0; colorizationColor:root.tint } }
    ShellText { anchors.centerIn:parent; visible:!icon.visible; text:"󰀻"; color:root.tint; font.pixelSize:root.size }
}
