import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property string glyph: ""
    property string label: ""
    property color labelColor: App.palette.text
    property color iconColor: App.palette.accent
    property bool selected: false
    property alias leading: leadingSlot.data
    property alias trailing: trailingSlot.data
    signal clicked()
    implicitHeight: 34; height: 34; radius: 17
    property bool hoverHighlight: true
    // Scroll an overflowing label on hover instead of eliding it.
    property bool marquee: false
    // Scroll without pointing at the row, e.g. while its menu is held open by hovering the bar item.
    property bool scrollNow: false
    color: selected ? App.palette.surface : hoverHighlight ? App.tone(App.palette.bg, hover.hovered, pointer.pressed) : App.palette.bg
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.onPressAction: clicked()
    MouseArea { id: pointer; anchors.fill: parent; onClicked: root.clicked() }
    HoverHandler { id: hover }
    Rectangle { x: 0; y: 5; width: 3; height: parent.height - 10; radius: 2; color: App.palette.accent; visible: root.selected }
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 12; spacing: 4
        Item {
            id: leadingSlot; Layout.preferredWidth: 28; Layout.fillHeight: true
            Text { anchors.centerIn: parent; text: root.glyph; color: root.iconColor; font.family: "Symbols Nerd Font"; font.pixelSize: 16 }
        }
        Item {
            id: labelBox; Layout.fillWidth: true; Layout.fillHeight: true; clip: true
            Text {
                id: labelText
                readonly property real gap: 48
                readonly property real overflow: implicitWidth - labelBox.width
                readonly property bool scrolling: root.marquee && (hover.hovered || root.scrollNow) && overflow > 0
                anchors.verticalCenter: parent.verticalCenter
                width: scrolling ? implicitWidth : labelBox.width
                text: root.label; elide: scrolling ? Text.ElideNone : Text.ElideRight
                color: root.labelColor; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 13
                onScrollingChanged: if (!scrolling) x = 0
                // Second copy trails the first, so scrolling one copy-width lands seamlessly back at the start.
                Text {
                    visible: labelText.scrolling; x: labelText.implicitWidth + labelText.gap
                    text: labelText.text; color: labelText.color; font: labelText.font
                }
                SequentialAnimation on x {
                    running: labelText.scrolling && !App.reducedMotion; loops: Animation.Infinite
                    NumberAnimation { from: 0; to: -(labelText.implicitWidth + labelText.gap); duration: (labelText.implicitWidth + labelText.gap) * 30 }
                }
            }
        }
        Row { id: trailingSlot; spacing: 6; Layout.alignment: Qt.AlignVCenter }
    }
}
