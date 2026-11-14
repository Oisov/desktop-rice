pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
Item {
    id: root
    readonly property string query: search.text
    readonly property int resultCount: entries.length
    property var entries: {
        const query = search.text.trim().toLocaleLowerCase();
        let rows = [];
        for (const entry of DesktopEntries.applications.values) {
            if (entry.noDisplay) continue;
            let name = entry.name.toLocaleLowerCase();
            let description = [entry.genericName, entry.comment, ...(entry.keywords || [])].join(" ").toLocaleLowerCase();
            let rank = !query || name.startsWith(query) ? 0 : name.split(/\s+/).some(w => w.startsWith(query)) ? 1 : name.includes(query) ? 2 : description.includes(query) ? 3 : 99;
            if (rank < 99) rows.push({entry:entry, rank:rank});
        }
        return rows.sort((a,b)=>a.rank-b.rank || a.entry.name.localeCompare(b.entry.name)).map(r=>r.entry);
    }
    function activate() { search.clear(); list.currentIndex = 0; search.forceActiveFocus(); }
    function launch(index) {
        const app = entries[index]; if (!app) return;
        if (app.runInTerminal) Quickshell.execDetached(["kitty", "-e"].concat(Array.from(app.command)));
        else app.execute();
        App.close();
    }
    function step(delta) { if (entries.length) list.currentIndex = (list.currentIndex + delta + entries.length) % entries.length; }
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 16; spacing: 10
        Search {
            id: search; Layout.fillWidth: true; placeholderText: "Search applications"; Accessible.name: "Search applications"
            onTextChanged: list.currentIndex = 0
            onAccepted: root.launch(list.currentIndex)
            Keys.onDownPressed: root.step(1)
            Keys.onUpPressed: root.step(-1)
            Keys.onEscapePressed: App.close()
        }
        ListView {
            id: list; Layout.fillWidth: true; Layout.fillHeight: true; clip: true
            model: root.entries; currentIndex: 0; spacing: 3
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: App.reducedMotion ? 0 : 100
            highlight: Rectangle { radius: 12; color: App.tone(App.palette.surface, true, false) }
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                width: list.width; height: 48
                Rectangle { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: 3; height: 24; radius: 2; color: App.palette.accent; visible: row.ListView.isCurrentItem }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 12; spacing: 12
                    Image { source: Quickshell.iconPath(row.modelData.icon, "application-x-executable"); Layout.preferredWidth: 28; Layout.preferredHeight: 28; sourceSize: Qt.size(56,56); asynchronous: true }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        ShellText { Layout.fillWidth: true; text: row.modelData.name; font.weight: Font.Medium }
                        ShellText { Layout.fillWidth: true; text: row.modelData.genericName || row.modelData.comment || ""; font.pixelSize: 11; color: App.palette.muted }
                    }
                }
                MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: list.currentIndex = row.index; onClicked: root.launch(row.index) }
                Accessible.role: Accessible.Button; Accessible.name: modelData.name
                Accessible.onPressAction: root.launch(index)
            }
            ScrollBar.vertical: ScrollBar { }
            ShellText { anchors.centerIn: parent; text: "No matching applications"; visible: list.count === 0; color: App.palette.muted }
        }
    }
}
