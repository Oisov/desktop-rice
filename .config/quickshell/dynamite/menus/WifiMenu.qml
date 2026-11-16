pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import ".."

Item {
    id: menu
    property Item anchor: null
    readonly property bool pinnable: true
    function key(event) {
        if (event.key === Qt.Key_Escape && passwordNetwork) { passwordNetwork = null; wifiSearch.text = ""; }
        else if ([Qt.Key_Up, Qt.Key_Down].includes(event.key)) {
            const count = filteredNetworks.length;
            if (count) { currentNetwork = currentNetwork < 0 ? (event.key === Qt.Key_Up ? count - 1 : 0) : (currentNetwork + (event.key === Qt.Key_Up ? count - 1 : 1)) % count; networkList.positionViewAtIndex(currentNetwork, ListView.Contain); }
        } else if ([Qt.Key_Return, Qt.Key_Enter].includes(event.key)) {
            if (passwordNetwork) { wifiCall(["connect", passwordNetwork.ssid, "", wifiSearch.text]); passwordNetwork = null; wifiSearch.text = ""; }
            else activateNetwork(filteredNetworks[Math.max(0, currentNetwork)]);
        } else return false;
        return true;
    }
    function refresh() { App.refresh(); }
    required property var frame
    function opened() { passwordNetwork = null; wifiSearch.text = ""; wifiError = ""; wifiSearch.focus = false; if (App.data.network?.wifiAvailable) wifiCall(["list"]); }
    function closed() { passwordNetwork = null; wifiSearch.text = ""; wifiError = ""; wifiSearch.focus = false; }
    readonly property Item focusTarget: wifiSearch
    property var networks: []
    property bool radio: true
    property string wifiError: ""
    property var passwordNetwork: null
    property var wifiQueue: []
    readonly property var filteredNetworks: networks.filter(n => passwordNetwork || n.ssid.toLowerCase().includes(wifiSearch.text.toLowerCase()))
    property int currentNetwork: -1
    function setSearch(query) { passwordNetwork = null; wifiSearch.text = query; }
    function passwordFor(ssid) { const n = networks.find(n => n.ssid === ssid); if (n && n.secured && !n.uuid) activateNetwork(n); }
    function wifiCall(args) {
        if (wifiProcess.running) { wifiQueue = wifiQueue.concat([args]); return; }
        wifiProcess.command = ["python3", App.helper, "wifi"].concat(args); wifiProcess.running = true;
    }
    function activateNetwork(network) {
        if (!network) return;
        if (network.secured && !network.uuid) { frame.pinned = true; passwordNetwork = network; wifiSearch.text = ""; wifiSearch.forceActiveFocus(); }
        else wifiCall(["connect", network.ssid, network.uuid]);
    }
    Process {
        id: wifiProcess
        stdout: StdioCollector { onStreamFinished: {
            try {
                const result = JSON.parse(text);
                if (result.ok) { menu.networks = result.networks; menu.radio = result.radio; if (wifiProcess.command[3] !== "list") menu.wifiError = ""; menu.currentNetwork = -1; }
                else { menu.wifiError = result.error; if (wifiProcess.command[3] !== "list") menu.wifiQueue = menu.wifiQueue.concat([["list"]]); }
            } catch (e) { menu.wifiError = "Could not read Wi-Fi response"; }
        } }
        onExited: {
            App.refresh();
            if (menu.wifiQueue.length) {
                const next = menu.wifiQueue[0]; menu.wifiQueue = menu.wifiQueue.slice(1);
                Qt.callLater(() => menu.wifiCall(next));
            }
        }
    }
    property Item l2: RowLayout {
            visible: menu.frame.displayedMenu === menu
            anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 18; spacing: 12
            ShellButton { visible: !!App.data.network?.wifiAvailable; small: true; implicitWidth: 32; implicitHeight: 32; glyph: menu.passwordNetwork ? "󰌆" : "󰍉"; text: menu.passwordNetwork ? "Password" : "Search"; focusPolicy: Qt.NoFocus }
            TextField {
                id: wifiSearch; visible: !!App.data.network?.wifiAvailable; Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0; clip: true; background: null; padding: 0
                font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 13; color: App.palette.text
                Accessible.name: menu.passwordNetwork ? "Password for " + menu.passwordNetwork.ssid : "Search networks"
                placeholderTextColor: App.palette.muted
                placeholderText: menu.passwordNetwork ? "Password for " + menu.passwordNetwork.ssid : "Search"
                echoMode: menu.passwordNetwork ? TextInput.Password : TextInput.Normal
                onTextChanged: menu.currentNetwork = -1
                onPressed: menu.frame.pinned = true
            }
            ShellButton { visible: !!App.data.network?.wifiAvailable; small: true; implicitWidth: 32; implicitHeight: 32; glyph: "󰑐"; text: "Rescan"; focusPolicy: Qt.NoFocus; onClicked: menu.wifiCall(["rescan"]) }
            ShellButton {
                visible: menu.networks.some(n => n.connected); small: true; implicitWidth: 32; implicitHeight: 32; glyph: "󰅖"; text: "Disconnect"; focusPolicy: Qt.NoFocus
                onClicked: { const n = menu.networks.find(n => n.connected); if (n?.activeUuid) menu.wifiCall(["disconnect", n.activeUuid]); }
            }
            Text { visible: !App.data.network?.wifiAvailable; Layout.fillWidth: true; text: App.data.network?.connection || App.data.network?.device || ""; color: App.palette.text; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 13; elide: Text.ElideRight }
            ShellButton { visible: !!App.data.settings?.network?.length; small: true; implicitWidth: 32; implicitHeight: 32; glyph: "󰅂"; text: "Network settings"; onClicked: App.settings("network") }
            ShellButton { small: true; implicitWidth: 32; implicitHeight: 32; padding: 0; visible: App.adapter !== null; active: App.adapter?.enabled || false; enabled: App.adapter !== null; glyph: "󰂯"; text: "Bluetooth"; focusPolicy: Qt.NoFocus; onClicked: App.adapter.enabled = !App.adapter.enabled }
            ShellButton { small: true; implicitWidth: 32; implicitHeight: 32; padding: 0; visible: !!App.data.network?.wifiAvailable; active: menu.radio; glyph: menu.radio ? "󰖩" : "󰖪"; text: "Wi-Fi radio"; focusPolicy: Qt.NoFocus; onClicked: menu.wifiCall(["radio", menu.radio ? "off" : "on"]) }
        }
    property Item l3: Item {
        anchors.fill: parent
        implicitHeight: 4 + Math.min(6, menu.filteredNetworks.length + (menu.wifiError ? 1 : 0)) * 34
        Column {

                visible: menu.frame.displayedMenu === menu; x: 10; y: 2; width: parent.width - 20
                MenuRow { width: parent.width; visible: menu.wifiError !== ""; height: visible ? 34 : 0; glyph: "󰀦"; iconColor: "#e18593"; label: menu.wifiError }
                ListView {
                    id: networkList; width: parent.width; height: Math.min(menu.wifiError ? 5 : 6, count) * 34; clip: true
                    model: menu.filteredNetworks
                    delegate: MenuRow {
                        required property var modelData
                        required property int index
                        width: networkList.width
                        glyph: modelData.signal < 25 ? "󰤟" : modelData.signal < 50 ? "󰤢" : modelData.signal < 75 ? "󰤥" : "󰤨"
                        label: modelData.ssid; selected: modelData.connected || index === menu.currentNetwork
                        onClicked: menu.activateNetwork(modelData)
                        trailing: [
                            Rectangle { width: 6; height: 6; radius: 3; anchors.verticalCenter: parent.verticalCenter; visible: !!modelData.uuid || modelData.connected; color: modelData.connected ? App.palette.accent : "transparent"; border.width: 1; border.color: App.palette.accent },
                            Text { text: "󰌾"; visible: modelData.secured; color: App.palette.muted; font.family: "Symbols Nerd Font"; font.pixelSize: 16 }
                        ]
                    }
                }
            }
    }
}
