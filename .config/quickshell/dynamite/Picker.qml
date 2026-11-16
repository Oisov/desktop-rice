pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Item {
    id: root
    property bool wallpaper: false
    readonly property real desiredHeight: App.barHeight + 38 + (wallpaper ? 182 : 88)
    property var slots: ["morning","day","evening","night"]
    property int slot: {
        const now = new Date(); const minutes = now.getHours()*60 + now.getMinutes();
        return minutes < 300 ? 3 : minutes < 570 ? 0 : minutes < 990 ? 1 : minutes < 1200 ? 2 : 3;
    }
    readonly property var wallpaperTokens: wallpaperSearch.text.toLowerCase().trim().split(/\s+/).filter(t=>t && !slots.includes(t))
    readonly property var choices: wallpaper ? (App.wallpapers[slots[slot]] || []).filter(w=> {
        const terms=[w.name,...(w.keywords || [])].join(" ").toLowerCase();
        return wallpaperTokens.every(t=>terms.includes(t));
    }) : App.palettes.filter(t=>t.name.toLowerCase().includes(search.text.toLowerCase()))
    readonly property var selected: choices[strip.currentIndex] || null
    function isApplied(choice) { return wallpaper ? choice.path === App.appliedWallpaper : choice.id === App.appliedTheme; }
    function activate() { if (wallpaper) wallpaperSearch.forceActiveFocus(); else search.forceActiveFocus(); }
    // Arrows browse without applying; Enter or a click applies.
    function step(delta) {
        if (!choices.length) return;
        strip.currentIndex = Math.max(0, Math.min(choices.length - 1, strip.currentIndex + delta));
        strip.positionViewAtIndex(strip.currentIndex, ListView.Contain);
    }
    function sync() {
        strip.currentIndex = Math.max(0, choices.findIndex(isApplied));
        strip.forceLayout();
        strip.positionViewAtIndex(strip.currentIndex, ListView.Center);
    }
    function setSlot(index) { if (wallpaper) { previewEnter.stop(); previewLeave.stop(); App.previewWallpaper = ""; } slot = Math.max(0, Math.min(slots.length - 1, index)); Qt.callLater(sync); }
    function apply() { if (selected && !App.busy && !isApplied(selected)) App.action(wallpaper ? "wallpaper" : "theme", wallpaper ? selected.path : selected.id); }
    property string pendingPreview: ""
    Timer { id: previewEnter; interval: 140; onTriggered: if (root.wallpaper && !App.busy) App.previewWallpaper = root.pendingPreview }
    Timer { id: previewLeave; interval: 100; onTriggered: App.previewWallpaper = "" }
    Component.onCompleted: sync()
    Component.onDestruction: if (wallpaper) App.previewWallpaper = ""
    Connections { target: App; function onWallpapersChanged() { if (root.wallpaper) Qt.callLater(root.sync); } }
    Keys.onLeftPressed: step(-1)
    Keys.onRightPressed: step(1)
    Keys.onUpPressed: if (wallpaper) setSlot(slot - 1)
    Keys.onDownPressed: if (wallpaper) setSlot(slot + 1)
    Keys.onReturnPressed: apply()
    Keys.onEnterPressed: apply()
    Keys.onEscapePressed: App.close()
    ColumnLayout {
        anchors.fill: parent; spacing: 0
        RowLayout {
            visible:!root.wallpaper; Layout.fillWidth:true; Layout.preferredHeight:38
            Layout.leftMargin:16; Layout.rightMargin:16; spacing:8
            ShellText { text:"󰍉"; color:App.palette.accent; font.pixelSize:18; Layout.preferredWidth:28 }
            Search {
                id:search; Layout.fillWidth:true; placeholderText:"Themes"; Accessible.name:"Search themes"
                font.family:"JetBrainsMono Nerd Font Propo"; font.pixelSize:13; implicitHeight:38; background:null; padding:0
                onTextChanged: { strip.currentIndex=0; strip.positionViewAtBeginning(); }
                onAccepted:root.apply()
                Keys.onLeftPressed:root.step(-1)
                Keys.onRightPressed:root.step(1)
                Keys.onEscapePressed:App.close()
            }
        }
        Item {
            visible:root.wallpaper; Layout.fillWidth:true; Layout.preferredHeight:38
            RowLayout {
                x:16; height:38; width:Math.max(160,(parent.width-periods.implicitWidth)/2-32); spacing:8
                ShellText { text:"󰍉"; color:App.palette.accent; font.pixelSize:18; Layout.preferredWidth:28 }
                Search {
                    id:wallpaperSearch; Layout.fillWidth:true; placeholderText:"Wallpapers"; Accessible.name:"Search wallpapers"
                    font.family:"JetBrainsMono Nerd Font Propo"; font.pixelSize:13; implicitHeight:38; background:null; padding:0
                    onTextChanged: {
                        const period=root.slots.findIndex(p=>text.toLowerCase().split(/\s+/).includes(p));
                        if (period >= 0 && root.slot !== period) root.setSlot(period);
                        strip.currentIndex=0; strip.positionViewAtBeginning();
                    }
                    onAccepted:root.apply()
                    Keys.onLeftPressed:root.step(-1)
                    Keys.onRightPressed:root.step(1)
                    Keys.onUpPressed:root.setSlot(root.slot-1)
                    Keys.onDownPressed:root.setSlot(root.slot+1)
                    Keys.onEscapePressed:App.close()
                }
            }
            Row {
            id:periods; anchors.centerIn:parent; height:38; spacing:6
            Accessible.role: Accessible.PageTabList; Accessible.name: "Time of day"
            Repeater {
                model: root.slots
                Rectangle {
                    id: segment
                    required property string modelData
                    required property int index
                    readonly property bool chosen: root.slot === index
                    width: label.implicitWidth + 28; height: 32; radius: 16; anchors.verticalCenter:parent.verticalCenter; anchors.verticalCenterOffset:3
                    color: chosen ? App.palette.surface : "transparent"
                    ShellText { id: label; anchors.centerIn: parent; text: segment.modelData.charAt(0).toUpperCase() + segment.modelData.slice(1); font.pixelSize: 12; font.weight: Font.Medium; color: segment.chosen ? App.palette.accent : App.palette.text }
                    MouseArea { id: press; anchors.fill: parent; hoverEnabled: true; onClicked: { root.setSlot(segment.index); root.activate(); } }
                    Accessible.role: Accessible.PageTab; Accessible.name: label.text; Accessible.selected: chosen
                    Accessible.onPressAction: root.setSlot(index)
                }
            }
        }
        }
        ListView {
            id: strip; Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins:16; orientation: ListView.Horizontal; spacing: 12; clip: true
            model: root.choices; currentIndex: 0; boundsBehavior: Flickable.StopAtBounds
            highlightFollowsCurrentItem: false
            onWidthChanged: Qt.callLater(root.sync)  // centre on the applied card once the panel has its real width
            delegate: Rectangle {
                id: card
                required property var modelData
                required property int index
                readonly property bool applied: root.isApplied(modelData)
                readonly property bool current: ListView.isCurrentItem
                width: root.wallpaper ? 180 : 168; height: root.wallpaper ? 150 : 56; radius: root.wallpaper ? 14 : 12
                color: root.wallpaper ? App.palette.surface : modelData.bg
                // applied > keyboard cursor > hover; the ring is the only state mark.
                border.width: applied || current || tap.containsMouse ? 2 : 1
                border.color: applied || (!root.wallpaper && current) ? App.palette.accent : current ? App.palette.text : tap.containsMouse ? App.palette.muted : App.palette.surface
                Accessible.role: Accessible.Button; Accessible.name: modelData.name; Accessible.checked: applied
                Accessible.onPressAction: { strip.currentIndex = index; root.apply(); }
                Image {
                    visible: root.wallpaper; anchors.fill: parent; anchors.margins: 5
                    source: root.wallpaper ? card.modelData.url : ""; asynchronous: true
                    sourceSize: Qt.size(360,220); fillMode: Image.PreserveAspectCrop
                }
                Column {
                    visible: !root.wallpaper; anchors.centerIn: parent; spacing: root.wallpaper ? 14 : 8
                    Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 5
                        Repeater { model: card.modelData.swatches || []; Rectangle { required property var modelData; width: 12; height: 12; radius: 6; color: modelData } }
                    }
                    ShellText { anchors.horizontalCenter: parent.horizontalCenter; text: card.modelData.name; color: card.modelData.text || App.palette.text; font.pixelSize: 12 }
                }
                MouseArea { id: tap; anchors.fill: parent; hoverEnabled: true
                    onEntered: if (root.wallpaper) { previewLeave.stop(); root.pendingPreview = card.modelData.url; previewEnter.restart(); }
                    onExited: if (root.wallpaper) { previewEnter.stop(); previewLeave.restart(); }
                    onClicked: { strip.currentIndex = card.index; root.forceActiveFocus(); root.apply(); } }
            }
            // A vertical wheel scrolls the strip sideways; it never changes the selection.
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const angle = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y) ? event.angleDelta.x : event.angleDelta.y;
                    const pixels = Math.abs(event.pixelDelta.x) > Math.abs(event.pixelDelta.y) ? event.pixelDelta.x : event.pixelDelta.y;
                    // Wayland reports wheel notches as ±120 with a token 15 px; touchpads scroll by their pixels.
                    const delta = angle % 120 === 0 && angle !== 0 ? angle / 120 * 96 : pixels || angle;
                    strip.contentX = Math.max(strip.originX, Math.min(strip.originX + strip.contentWidth - strip.width, strip.contentX - delta));
                }
            }
            ShellText { anchors.centerIn: parent; visible: strip.count===0; text: root.wallpaper ? "No wallpapers in this folder" : "No matching themes"; color: App.palette.muted }
        }
    }
}
