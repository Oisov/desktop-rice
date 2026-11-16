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
    property int minimumWidth: 0
    // Widest expected label (e.g. "100%") so changing values never shift the bar.
    property string labelReserve: ""
    TextMetrics { id: reserve; text: root.labelReserve; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 13; font.weight: Font.DemiBold }
    property int iconSize: 17
    // Fixed glyph slot so swapping glyphs (e.g. muted speaker) never shifts the bar.
    property real iconBox: 0
    property bool iconBold: false
    // Warning/critical items get a faint wash of their alert colour behind them.
    property color alertColor: "transparent"
    property var bar
    property Item menu: null
    signal clicked(int button)
    signal scrolled(int direction)
    width: Math.max(minimumWidth, content.implicitWidth + 2 * App.itemPadding); height: 38
    Accessible.role: Accessible.Button
    Accessible.name: hint
    Accessible.onPressAction: clicked(Qt.LeftButton)
    readonly property bool tabbed: !!root.bar && root.bar.highlightItem === root && root.bar.open
    Rectangle { y: 2; width: root.width; height: 34; radius: 17; visible: root.alertColor.a > 0 && !root.tabbed; color: Qt.rgba(root.alertColor.r, root.alertColor.g, root.alertColor.b, 0.16) }
    Row {
        id: content; anchors.centerIn: parent; spacing: root.contentSpacing
        Text { visible: root.glyph !== ""; text: root.glyph; color: root.iconColor; font.family: "Symbols Nerd Font"; font.pixelSize: root.iconSize; anchors.verticalCenter: parent.verticalCenter; width: Math.max(implicitWidth, root.iconBox); horizontalAlignment: Text.AlignHCenter; style: root.iconBold ? Text.Outline : Text.Normal; styleColor: root.iconColor }
        Text { visible: text !== ""; text: root.label; width: root.maximumLabelWidth >= 0 ? Math.min(implicitWidth, root.maximumLabelWidth) : Math.max(implicitWidth, root.labelReserve ? reserve.advanceWidth : 0); horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; color: App.palette.text; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 13; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea {
        id: pointer; anchors.fill: parent; hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onEntered: root.bar.enterItem(root, root.menu)
        onExited: root.bar.leaveItem(root)
        onClicked: event => root.clicked(event.button)
        onWheel: event => root.scrolled(event.angleDelta.y > 0 ? 1 : -1)
    }
    ToolTip {
        popupType: Popup.Window; y: 38
        visible: pointer.containsMouse && root.hint !== "" && root.menu === null && !root.bar?.open; delay: 700; text: root.hint
        contentItem: Text { text: root.hint; color: App.palette.text; font.pixelSize: 12 }
        background: Rectangle { color: App.palette.surface; radius: 8; border.color: App.palette.muted }
    }
}
