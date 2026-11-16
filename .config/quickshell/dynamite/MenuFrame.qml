pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

FocusScope {
    id: frame
    required property var hostWindow
    required property Item background
    property bool leftSide: false
    property Item activeMenu: null
    property Item displayedMenu: null
    property Item hoveredItem: null
    property Item hoveredMenu: null
    property Item previousMenu: null
    property Item nextMenu: null
    property bool pinned: false
    readonly property bool open: activeMenu !== null
    readonly property bool hoveredHasMenu: hoveredMenu !== null
    readonly property Item highlightItem: (pinned ? activeMenu?.anchor : hoveredItem) || activeMenu?.anchor || null
    property real hoverX: leftSide ? 10 : highlightItem ? highlightItem.x + highlightItem.parent.x : 6
    property real hoverWidth: leftSide ? 47 : highlightItem ? highlightItem.width : 42
    onHighlightItemChanged: if (leftSide) updateHighlight()
    Connections {
        target: frame.leftSide ? frame.highlightItem : null
        function onWidthChanged() { frame.updateHighlight(); }
        function onXChanged() { frame.updateHighlight(); }
    }
    function updateHighlight() {
        if (highlightItem) { hoverX = highlightItem.mapToItem(background, 0, 0).x; hoverWidth = highlightItem.width; }
    }
    readonly property bool tabAtEnd: leftSide ? hoverX + hoverWidth + 31 > width : hoverX < 31
    readonly property bool tabAtRightEnd: !leftSide && hoverX + hoverWidth > width - 12
    readonly property bool pinOnPress: activeMenu?.pinOnPress || false
    readonly property bool detailEnabled: !!activeMenu?.l3
    readonly property real contentHeight: displayedMenu?.l3?.implicitHeight || 0
    property real rowReveal: open ? 1 : 0
    property real detailReveal: activeMenu?.l3 && (activeMenu.detailVisible ?? true) && rowReveal > 0.99 ? 1 : 0
    readonly property bool expandingDetail: activeMenu?.pinnable || (leftSide && !!activeMenu?.l3) || false
    Behavior on rowReveal { NumberAnimation { duration: App.reducedMotion ? 0 : frame.open ? 180 : 140; easing.type: Easing.OutCubic } }
    Behavior on detailReveal { NumberAnimation { duration: App.reducedMotion ? 0 : frame.expandingDetail ? 180 : 140; easing.type: Easing.OutCubic } }
    readonly property alias lowerContent: lowerBar
    readonly property alias detailContent: detailBar
    readonly property alias lowerHovered: lowerHover.hovered
    readonly property alias detailHovered: detailHover.hovered
    readonly property alias lowerWidth: lowerBar.width
    readonly property Region inputMask: Region {
        item: frame.background
        Region { x: frame.leftSide ? 0 : lowerShoulder.x; y: 38; width: lowerBar.width + lowerShoulder.width; height: lowerReveal.height }
        Region { x: frame.leftSide ? 0 : detailBar.x - 12; y: 76; width: detailBar.width + 12; height: detailClip.height }
    }
    onActiveMenuChanged: {
        if (previousMenu?.closed) previousMenu.closed();
        pinned = false;
        if (activeMenu) { displayedMenu = activeMenu; if (activeMenu.opened) activeMenu.opened(); }
        previousMenu = activeMenu;
    }
    function close() { activeMenu = null; }
    function show(menu, pin, preserveHover) {
        hoverDelay.stop(); closeDelay.stop();
        if (pin && activeMenu === menu && pinned) { close(); return; }
        if (!preserveHover) { hoveredItem = null; hoveredMenu = null; }
        activeMenu = menu;
        pinned = !!pin && !!menu?.pinnable;
        if (!leftSide && !pin) menu?.refresh?.();
    }
    function enterItem(item, menu) {
        if (pinned) return;
        if (activeMenu?.interrupt) {
            if (item === activeMenu.anchor) { hoveredItem = item; hoveredMenu = menu; closeDelay.stop(); return; }
            activeMenu.interrupt(); close();
        }
        closeDelay.stop(); hoverDelay.stop(); hoveredItem = item; hoveredMenu = menu;
        if (menu) menu.anchor = item;
        if (menu && (menu.available ?? true)) {
            if (open) { activeMenu = menu; if (!leftSide) activeMenu?.refresh?.(); }
            else { nextMenu = menu; hoverDelay.restart(); }
        } else if (open) closeDelay.restart();
    }
    function leaveItem(item) {
        if (pinned || hoveredItem !== item) return;
        hoveredItem = null; hoveredMenu = null; hoverDelay.stop();
        if (activeMenu?.autoClose ?? true) closeDelay.restart();
    }
    function stopClose() { closeDelay.stop(); }
    function restartClose() { closeDelay.restart(); }
    function launch(command) { close(); App.external([App.home + "/.local/bin/bar-menu-guard"].concat(command)); }
    Timer { id: hoverDelay; interval: 150; onTriggered: if (!App.modal && (frame.nextMenu?.available ?? true)) { frame.activeMenu = frame.nextMenu; if (!frame.leftSide) frame.activeMenu?.refresh?.(); } }
    Timer { id: closeDelay; interval: frame.leftSide ? 250 : 240; onTriggered: if ((frame.activeMenu?.autoClose ?? true) && !frame.pinned && !lowerHover.hovered && !detailHover.hovered && !frame.activeMenu?.held && !(frame.hoveredItem && frame.hoveredMenu)) frame.close() }
    onPinnedChanged: {
        if (pinned) { grabDelay.restart(); focusDelay.restart(); }
        else { grabDelay.stop(); focusDelay.stop(); menuGrab.active = false; }
    }
    Timer { id: focusDelay; interval: 220; onTriggered: { frame.forceActiveFocus(); frame.activeMenu?.focusTarget?.forceActiveFocus(); } }
    Timer { id: grabDelay; interval: 100; onTriggered: if (frame.pinned) menuGrab.active = true }
    HyprlandFocusGrab { id: menuGrab; windows: [frame.hostWindow]; onCleared: frame.close() }
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: event => {
        if (!frame.pinned) return;
        if (frame.activeMenu?.key && frame.activeMenu.key(event)) { event.accepted = true; return; }
        if (event.key === Qt.Key_Escape) { frame.close(); event.accepted = true; }
    }
    Connections { target: App; function onPanelChanged() { if (App.modal) frame.close(); } }
    Rectangle {
        id: hoverPill
        parent: frame.background
        readonly property bool attached: frame.open && (frame.pinned || !frame.hoveredItem || frame.hoveredHasMenu)
        x: !frame.leftSide && attached && frame.tabAtEnd ? 0 : frame.hoverX
        width: frame.leftSide ? (attached && frame.tabAtEnd ? frame.width - frame.hoverX : frame.hoverWidth) : attached && frame.tabAtEnd ? frame.hoverX + frame.hoverWidth : attached && frame.tabAtRightEnd ? frame.width - frame.hoverX : frame.hoverWidth
        y: 2; height: attached ? 36 : 34
        topLeftRadius: 17; topRightRadius: 17
        bottomLeftRadius: attached ? 0 : 17; bottomRightRadius: bottomLeftRadius
        color: App.palette.bg
        ConcaveCorner { curveRadius: 12; inverted: true; x: -width; y: hoverPill.height - height; visible: hoverPill.attached && (frame.leftSide || !frame.tabAtEnd) }
        ConcaveCorner { curveRadius: 12; inverted: true; mirrored: true; x: hoverPill.width; y: hoverPill.height - height; visible: hoverPill.attached && (frame.leftSide ? !frame.tabAtEnd : !frame.tabAtRightEnd) }
        opacity: frame.highlightItem ? 1 : 0
        Behavior on x { NumberAnimation { duration: App.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: App.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: App.reducedMotion ? 0 : 100 } }
    }
    Item {
        id: lowerReveal;
        TapHandler { gesturePolicy: TapHandler.DragThreshold; onPressedChanged: if (pressed && frame.pinOnPress) frame.pinned = true }
        y: 38; width: frame.width; height: 38 * frame.rowReveal
        clip: true; opacity: frame.rowReveal; visible: frame.rowReveal > 0
        enabled: frame.open
        ConcaveCorner {
            id: lowerShoulder
            curveRadius: Math.min(12, Math.max(0, frame.leftSide ? frame.width - lowerBar.width - 19 : lowerBar.x - 19))
            x: frame.leftSide ? lowerBar.width : lowerBar.x - width; y: lowerBar.y; mirrored: frame.leftSide
            visible: false
            HoverHandler { onHoveredChanged: { if (hovered) frame.stopClose(); else frame.restartClose(); } }
        }
        Rectangle {
            id: lowerBar; anchors.right: frame.leftSide ? undefined : parent.right; y: 0
            width: Math.min(frame.width, Math.max(Math.round(frame.width * 0.95), frame.leftSide ? frame.hoverX + frame.hoverWidth + 31 : frame.width - frame.hoverX + 31)); height: 38
            color: App.palette.bg; topLeftRadius: frame.leftSide ? 0 : hoverPill.attached && frame.tabAtEnd ? 0 : 19; bottomLeftRadius: frame.leftSide ? 0 : 19; topRightRadius: frame.leftSide ? (hoverPill.attached && frame.tabAtEnd ? 0 : 19) : 0; bottomRightRadius: frame.leftSide ? 19 : 0
            HoverHandler { id: lowerHover; onHoveredChanged: { if (hovered) frame.stopClose(); else frame.restartClose(); } }

        }
    }
    Item {
        id: detailClip;
        TapHandler { gesturePolicy: TapHandler.DragThreshold; onPressedChanged: if (pressed && frame.pinOnPress) frame.pinned = true }
        y: 76; width: frame.width
        height: detailBar.height * frame.detailReveal; clip: true; opacity: frame.detailReveal; visible: height > 0
        enabled: frame.detailEnabled
        Rectangle {
            id: detailBar; anchors.right: frame.leftSide ? undefined : parent.right; width: Math.round(lowerBar.width * 0.95)
            height: frame.contentHeight
            color: App.palette.bg; topLeftRadius: frame.leftSide ? 0 : 19; bottomLeftRadius: frame.leftSide ? 0 : 19; topRightRadius: frame.leftSide ? 19 : 0; bottomRightRadius: frame.leftSide ? 19 : 0
            HoverHandler { id: detailHover; onHoveredChanged: { if (hovered) frame.stopClose(); else frame.restartClose(); } }

        }
    }
}
