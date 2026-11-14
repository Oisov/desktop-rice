import QtQuick
import Quickshell
import Quickshell.Wayland
PanelWindow {
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "dynamite-wallpaper-preview"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    mask: Region {}
    visible: App.panel === "wallpapers" && App.previewWallpaper !== ""
    Image {
        id: preview; anchors.fill: parent
        source: App.previewWallpaper; asynchronous: true
        fillMode: Image.PreserveAspectCrop
    }
}
