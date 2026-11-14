import QtQuick
import QtQuick.Controls
Item {
    id: root
    property string glyph: ""
    property string label: ""
    property string hint: ""
    property real maximumLabelWidth: -1
    property real contentSpacing: 7
    property color iconColor: App.palette.accent
    property int minimumWidth: 40
    property int iconSize: 17
    property var bar
    property string sliderKind: ""
    signal clicked(int button)
    signal scrolled(int direction)
    width: Math.max(minimumWidth, content.implicitWidth + 26); height: 38
    Accessible.role: Accessible.Button
    Accessible.name: hint
    Accessible.onPressAction: clicked(Qt.LeftButton)
    Row {
        id: content; anchors.centerIn: parent; spacing: root.contentSpacing
        Text { text: root.glyph; color: root.iconColor; font.family: "Symbols Nerd Font"; font.pixelSize: root.iconSize; anchors.verticalCenter: parent.verticalCenter }
        Text { visible: text !== ""; text: root.label; width: root.maximumLabelWidth > 0 ? Math.min(implicitWidth, root.maximumLabelWidth) : implicitWidth; elide: Text.ElideRight; color: App.palette.text; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 13; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea {
        id: pointer; anchors.fill: parent; hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onEntered: root.bar.enterItem(root, root.sliderKind)
        onExited: root.bar.leaveItem(root)
        onClicked: event => root.clicked(event.button)
        onWheel: event => root.scrolled(event.angleDelta.y > 0 ? 1 : -1)
    }
    ToolTip {
        popupType: Popup.Window; y: 38
        visible: pointer.containsMouse && root.hint !== "" && root.sliderKind === ""; delay: 700; text: root.hint
        contentItem: Text { text: root.hint; color: App.palette.text; font.pixelSize: 12 }
        background: Rectangle { color: App.palette.surface; radius: 8; border.color: App.palette.muted }
    }
}
