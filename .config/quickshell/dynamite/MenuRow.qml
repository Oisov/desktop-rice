import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property string glyph: ""
    property string label: ""
    property color iconColor: App.palette.accent
    property bool selected: false
    property alias leading: leadingSlot.data
    property alias trailing: trailingSlot.data
    signal clicked()
    implicitHeight: 34; height: 34; radius: 17
    color: selected ? App.palette.surface : App.tone(App.palette.bg, pointer.containsMouse, pointer.pressed)
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.onPressAction: clicked()
    Rectangle { x: 0; y: 5; width: 3; height: parent.height - 10; radius: 2; color: App.palette.accent; visible: root.selected }
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 12; spacing: 4
        Item {
            id: leadingSlot; Layout.preferredWidth: 28; Layout.fillHeight: true
            Text { anchors.centerIn: parent; text: root.glyph; color: root.iconColor; font.family: "Symbols Nerd Font"; font.pixelSize: 16 }
        }
        Text { Layout.fillWidth: true; text: root.label; elide: Text.ElideRight; color: App.palette.text; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 13 }
        Row { id: trailingSlot; spacing: 6; Layout.alignment: Qt.AlignVCenter }
    }
    MouseArea { id: pointer; anchors.fill: parent; hoverEnabled: true; onClicked: root.clicked() }
}
