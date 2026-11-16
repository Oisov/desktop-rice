pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Hyprland

Item {
    id: root
    property alias query: search.text
    readonly property bool searchFocused: search.activeFocus
    property var learned: []
    property var aliases: ({})
    property var history: ({})
    property var appIds: []
    property var binds: []
    property var bindUse: ({})
    property var files: []
    property string calculator: ""
    property int current: 0
    property var lockedRows: null
    property string armed: ""
    property string status: ""
    readonly property bool empty: !query.trim()
    readonly property bool bindMode: query.startsWith("?")
    readonly property bool fileMode: query.startsWith("/")
    readonly property int resultCount: entries.length
    readonly property var selected: navigation[current] || null
    readonly property real desiredHeight: App.barHeight + 38 + 12 + Math.min(8 * 34, empty ? (hoverColumn.visible ? hoverColumn.height : workspaceColumn.height) + entries.length * 34 : entries.length * 34)
    readonly property var windows: Hyprland.toplevels.values.filter(t => t.wayland)
    readonly property var groups: {
        const ids = [...new Set(windows.map(t => t.workspace?.id).filter(x => x > 0))];
        return ids.sort((a,b) => (b === Hyprland.focusedWorkspace?.id) - (a === Hyprland.focusedWorkspace?.id) || a-b)
            .map(id => ({id:id, windows:windows.filter(t => t.workspace?.id === id)}));
    }
    function windowRow(t) { return {id:t.address, type:"window", window:t, label:t.wayland.title, appId:t.wayland.appId, trailing:String(t.workspace?.id || "")}; }
    function bindFor(row) {
        if (row.type === "bind") return row;
        const command = row.type === "app" ? Array.from(row.entry.command || []).join(" ") : row.command || ({lock:"hyprlock",suspend:"systemctl suspend",logout:"exit",restart:"systemctl reboot",shutdown:"systemctl poweroff"})[row.action || row.id] || "";
        const normalized = cmd => cmd.trim().replace(/\s+%[a-zA-Z]/g, "").replace(/^(?:[^ ]*\/)/, "").replace(/\s+/g," ");
        return binds.find(b => !b.submap && (row.type === "window" ? String(b.workspace) === String(row.window.workspace?.id) : command && (normalized(b.command) === normalized(command) || (row.action || row.id) === "logout" && (b.expression || "").includes("hl.dsp.exit("))));
    }
    // Dynamic programming keeps the best alignment, with fzf-style run and boundary bonuses.
    function tokenScore(needle, text) {
        const lower=text.toLowerCase(), n=needle.length;
        if (!n) return 0;
        const boundary=i => i === 0 || /[\s_./-]/.test(text[i-1]) || /[a-z]/.test(text[i-1]) && /[A-Z]/.test(text[i]);
        let previous=[];
        for (let q=0; q<n; q++) {
            const next=[];
            for (let i=0; i<text.length; i++) {
                next[i]=-Infinity;
                if (lower[i] !== needle[q]) continue;
                const bonus=boundary(i) ? 8 : 0;
                if (q === 0) { if (boundary(i)) next[i]=16+bonus*2-i*0.1; }
                else for (let j=0; j<i; j++) {
                    if (!Number.isFinite(previous[j])) continue;
                    const gap=i-j-1;
                    // Short tokens start at a boundary and cannot cross into another word.
                    if (n<4 && /[\s_./-]/.test(text.slice(j+1,i))) continue;
                    next[i]=Math.max(next[i], previous[j]+16+bonus+(gap === 0 ? 8 : -3-gap*2));
                }
            }
            previous=next;
        }
        const best=Math.max(...previous);
        if (best < n*16) return -1;
        if (lower.startsWith(needle)) return best+10000;
        for (let i=0; i<lower.length; i++) if (boundary(i) && lower.startsWith(needle,i)) return best+5000;
        return best;
    }
    function typoScore(needle, text) {
        if (needle.length < 4) return -1;
        const limit=needle.length >= 7 ? 2 : 1;
        for (const word of text.toLowerCase().split(/[^\p{L}\p{N}]+/u)) {
            if (!word) continue;
            const candidate=word.slice(0,needle.length+limit), d=[];
            for (let i=0;i<=needle.length;i++) {
                d[i]=[i];
                for (let j=1;j<=candidate.length;j++) {
                    if (!i) { d[i][j]=j; continue; }
                    d[i][j]=Math.min(d[i-1][j]+1,d[i][j-1]+1,d[i-1][j-1]+(needle[i-1] === candidate[j-1] ? 0 : 1));
                    if (i>1 && j>1 && needle[i-1] === candidate[j-2] && needle[i-2] === candidate[j-1]) d[i][j]=Math.min(d[i][j],d[i-2][j-2]+1);
                }
            }
            for (let j=Math.max(1,needle.length-limit);j<=candidate.length;j++) if (d[needle.length][j]<=limit) return 200-d[needle.length][j]*50;
        }
        return -1;
    }
    function score(needle, row) {
        const tokens=needle.toLowerCase().trim().split(/\s+/).filter(Boolean);
        let total=0;
        for (const token of tokens) {
            // File names use one rule: any in-order letter match, the same rule the helper uses to fetch them.
            if (row.type === "file") {
                const label=row.label.toLowerCase(); let at=0, first=-1;
                for (const c of token) { at=label.indexOf(c,at); if (at < 0) return -1; if (first < 0) first=at; at++; }
                // Tighter, earlier, shorter matches rank higher.
                total+=Math.max(1, 1000 - 10*(at-first-token.length) - 5*first - label.length); continue;
            }
            const name=Math.max(tokenScore(token,row.label),typoScore(token,row.label));
            if (name >= 0) { total+=100000+name; continue; }
            if (row.type === "bind") {
                const best=Math.max(...(row.fields || []).filter(Boolean).map(f=>tokenScore(token,f)));
                if (best < 0) return -1;
                total+=best; continue;
            }
            const words=(row.fields || []).filter(Boolean).join(" ").toLowerCase().split(/[^\p{L}\p{N}]+/u);
            if (!words.some(word=>word.startsWith(token))) return -1;
            total+=100;
        }
        return total;
    }
    readonly property var actions: {
        const rows = [
            ["lock","Lock","󰌾"], ["suspend","Suspend","󰒲"], ["logout","Log out","󰍃"], ["restart","Restart","󰜉"], ["shutdown","Shut down","󰐥"],
            ["dnd","DND " + (Notifications.dnd ? "off" : "on"),"󰂛"], ["wifi","Wi-Fi " + (App.data.network?.enabled ? "off" : "on"),"󰤨"],
            ["bluetooth","Bluetooth " + (App.adapter?.enabled ? "off" : "on"),"󰂯"], ["awake","Keep awake " + (App.keepAwake ? "off" : "on"),"󰒲"], ["mute","Mute","󰝟"]
        ].filter(a => (a[0] !== "wifi" || App.data.network?.wifiAvailable)
            && (a[0] !== "bluetooth" || App.adapter !== null)
            && (a[0] !== "mute" || App.data.audio?.available)).map(a => ({id:"action:"+a[0], action:a[0], type:"action", label:a[1], glyph:a[2]}));
        ["themes","wallpapers","launcher"].forEach(name => rows.push({id:"action:"+name,type:"panel",label:name[0].toUpperCase()+name.slice(1),command:"~/.local/bin/dynamite toggle "+name,glyph:name === "themes" ? "󰏘" : name === "wallpapers" ? "󰸉" : "󰍉"}));
        App.palettes.forEach(t => rows.push({id:"theme:"+t.id, type:"theme", label:"Theme " + t.name, value:t.id, glyph:"󰏘"}));
        ["morning","day","evening","night"].forEach(p => rows.push({id:"wallpaper:"+p, type:"wallpaper", label:"Wallpaper " + p, value:p, glyph:"󰸉"}));
        return rows;
    }
    function preference(row) {
        const q=query.toLowerCase().trim().replace(/\s+/g," ");
        if (aliases[q] === row.id) return 100000000;
        return learned.filter(r => r.id === row.id && r.query.startsWith(q)).reduce((best,r) => Math.max(best,1000000+r.count*100+Math.max(0,100-(Date.now()/1000-r.last)/86400)),-1);
    }
    readonly property var entries: {
        const apps = DesktopEntries.applications.values.filter(e => !e.noDisplay && root.appIds.includes(e.id.replace(/\.desktop$/, ""))).map(e => ({id:e.id, type:"app", entry:e, label:e.name, appId:e.id,
            fields:[e.genericName,e.comment,...(e.keywords || []),e.id]}));
        if (empty) return apps.filter(a => (history[a.id] || 0) > 0).sort((a,b) => (history[b.id] || 0)-(history[a.id] || 0) || a.label.localeCompare(b.label)).slice(0,6);
        let rows = bindMode ? binds : fileMode ? files.map(f => Object.assign({},f,{type:"file",glyph:fileGlyph(f.path),trailing:f.parent})) : windows.map(windowRow).concat(apps,actions);
        const needle = fileMode || bindMode ? query.slice(1) : query;
        rows = rows.map(r => Object.assign({},r,{rank:Math.max(score(needle, r),preference(r))}))
            .filter(r => r.rank >= 0).sort((a,b) => b.rank-a.rank || (a.type === "window" ? -1 : b.type === "window" ? 1 : 0) ||
                ((history[b.id] || 0) + (b.recent || 0)*0.2) - ((history[a.id] || 0) + (a.recent || 0)*0.2) || a.label.localeCompare(b.label));
        if (!fileMode && !bindMode) {
            if (calculator) rows.unshift({id:"calculator", type:"calculator", label:"= " + calculator, value:calculator, glyph:"󰃬"});
            rows.push({id:"web",type:"web",label:"Search the web for “" + query + "”",value:query,glyph:"󰖟"});
        }
        return rows.map((row,index)=>({row:row,index:index})).sort((a,b)=>preference(b.row)-preference(a.row) || a.index-b.index).map(item=>item.row);
    }
    // Keyboard navigation follows what is shown: a hovered dot's windows, otherwise every workspace.
    readonly property var shownGroups: App.hoveredWorkspace > 0 ? groups.filter(x => x.id === App.hoveredWorkspace) : groups
    Connections { target: App; function onHoveredWorkspaceChanged() { root.lockedRows=null; root.current=0; } }
    readonly property var candidates: (empty ? shownGroups.reduce((all,g) => all.concat(g.windows.map(windowRow)),[]) : []).concat(entries)
    onCandidatesChanged: {
        if (lockedRows !== null) {
            const added=candidates.filter(r => !lockedRows.some(old => old.id === r.id));
            if (added.length) lockedRows=lockedRows.concat(added);
        }
    }
    readonly property var navigation: lockedRows === null ? candidates : lockedRows
    readonly property var displayedEntries: lockedRows === null ? entries : navigation.filter(r => !empty || r.type !== "window")
    function fileGlyph(path) { const ext=path.split('.').pop().toLowerCase(); return ext === "pdf" ? "󰈦" : ["png","jpg","jpeg","webp","svg"].includes(ext) ? "󰈟" : ["mp4","mkv","webm"].includes(ext) ? "󰈫" : "󰈙"; }
    function activate() { search.forceActiveFocus(); }
    function pin() { App.pinOverview(); }
    function step(delta) {
        if (!navigation.length) return;
        if (lockedRows === null) lockedRows=candidates.slice();
        current=(current+delta+navigation.length)%navigation.length;
        if (empty && current < navigation.length-entries.length) { scroll.contentY=0; status=selected.label; }
        else { const i=current-(empty ? navigation.length-entries.length : 0); scroll.contentY=Math.max(0, Math.min(scroll.contentHeight-scroll.height, (empty ? (hoverColumn.visible ? hoverColumn.height : workspaceColumn.height) : 0)+i*34-scroll.height+34)); status=""; }
    }
    function run(row, folder) {
        if (!row) return; pin();
        const action=row.action || row.id;
        // Keybind rows that end the session need the same second Enter as the power actions.
        const destructive=["logout","restart","shutdown"].includes(action) || (row.type === "bind" && /exit|reboot|poweroff|shutdown/i.test([row.expression,row.command,row.dispatcher,row.label].join(" ")));
        if (destructive && armed !== row.id) { armed=row.id; confirm.restart(); return; }
        Quickshell.execDetached(["python3",App.helper,"record-choice",query,row.id]);
        const hint=bindFor(row);
        if (hint && (bindUse[hint.id] || 0) < 3) App.teach(hint.keys);
        if (row.type === "bind") Quickshell.execDetached(["python3",App.helper,"run-bind",row.id]);
        else if (row.type === "panel") { const name=row.id.slice(7); Qt.callLater(() => { if (App.panel !== name) App.toggle(name); }); return; }
        else if (row.type === "window") row.window.wayland.activate();
        else if (row.type === "app") { if (row.entry.runInTerminal) Quickshell.execDetached(["kitty","-e"].concat(Array.from(row.entry.command))); else row.entry.execute(); }
        else if (row.type === "file") { Quickshell.execDetached(folder ? ["dolphin","--select",row.path] : ["xdg-open",row.path]); }
        else if (row.type === "calculator") Quickshell.execDetached(["python3","-c","import subprocess,sys; subprocess.run(['wl-copy'],input=sys.argv[1].encode(),check=True)",row.value]);
        else if (row.type === "web") Quickshell.execDetached(["xdg-open","https://duckduckgo.com/?q="+encodeURIComponent(row.value)]);
        else if (row.type === "theme") App.action("theme",row.value);
        else if (row.type === "wallpaper") App.action("wallpaper-period",row.value);
        else if (action === "dnd") Notifications.toggleDnd();
        else if (action === "wifi") App.action("wifi",App.data.network?.enabled ? "off" : "on");
        else if (action === "bluetooth") { if (App.adapter) App.adapter.enabled=!App.adapter.enabled; }
        else if (action === "awake") App.keepAwake=!App.keepAwake;
        else if (action === "mute") App.action("mute");
        else { const commands={lock:["hyprlock"],suspend:["systemctl","suspend"],logout:["hyprctl","eval","hl.dispatch(hl.dsp.exit())"],restart:["systemctl","reboot"],shutdown:["systemctl","poweroff"]}; Quickshell.execDetached(commands[action]); }
        App.close();
    }
    Timer { id: confirm; interval: 4000; onTriggered: root.armed="" }
    Timer { id: debounce; interval: 120; onTriggered: root.request() }
    function request() { if (!lookup.running) { lookup.command=["python3",App.helper,"search",query]; lookup.running=true; } }
    Process {
        id: lookup
        stdout: StdioCollector { onStreamFinished: { try { const r=JSON.parse(text); if (r.ok && r.query === root.query) { root.files=r.files; root.calculator=r.calculator || ""; } } catch(e) { App.error="Could not read search response"; } } }
        onExited: if (command[3] !== root.query) debounce.restart()
    }
    Process { id:bindReader; command:["python3",App.helper,"binds"]; running:true; stdout: StdioCollector { onStreamFinished: { try { const r=JSON.parse(text); root.binds=r.binds || []; root.bindUse=r.bindUse || {}; } catch(e) { App.error="Could not read binds"; } } } }
    Process { id:learningReader; command:["python3",App.helper,"learning"]; running:true; stdout: StdioCollector { onStreamFinished: { try { const r=JSON.parse(text); root.history=r.frecency || {}; root.learned=r.learned || []; root.aliases=r.aliases || {}; } catch(e) {} } } }
    Process { command:["python3",App.helper,"overview-apps"]; running:true; stdout: StdioCollector { onStreamFinished: { try { root.appIds=JSON.parse(text).appIds || []; } catch(e) { App.error="Could not read app catalogue"; } } } }
    Connections {
        target:App
        function onPanelChanged() {
            if (App.panel === "overview") {
                root.query=""; root.lockedRows=null; root.current=0;
                if (!bindReader.running) bindReader.running=true;
                if (!learningReader.running) learningReader.running=true;
                if (App.overviewPinned) Qt.callLater(root.activate);
            }
        }
    }
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 0; spacing: 0
        Rectangle {
            Layout.fillWidth:true; Layout.preferredHeight: 38
            color:"transparent"
            topLeftRadius:0; topRightRadius:0; bottomLeftRadius:0; bottomRightRadius:0
            RowLayout {
                anchors.fill:parent; anchors.leftMargin:16; anchors.rightMargin:16; spacing:8
                ShellText { text:"󰍉"; color:App.palette.accent; font.pixelSize:18; Layout.preferredWidth:28 }
        Search {
            id: search; Layout.fillWidth:true; placeholderText:"Search"; Accessible.name:"Search windows, apps, actions or /files"; font.family:"JetBrainsMono Nerd Font Propo"; font.pixelSize:13
            background: null
            padding:0
            onPressed: root.pin()
            onTextChanged: { root.lockedRows=null; root.current=0; root.armed=""; root.files=[]; root.calculator=""; debounce.restart(); }
            Keys.onPressed: event => {
                if ([Qt.Key_Return,Qt.Key_Enter].includes(event.key)) { root.run(root.selected,!!(event.modifiers & Qt.ControlModifier)); event.accepted=true; }
                else if ([Qt.Key_Up,Qt.Key_Left,Qt.Key_Down,Qt.Key_Right].includes(event.key) && (event.key === Qt.Key_Up || event.key === Qt.Key_Down || root.empty)) { root.step(event.key === Qt.Key_Up || event.key === Qt.Key_Left ? -1 : 1); event.accepted=true; }
                else if (event.key === Qt.Key_Escape) { App.close(); event.accepted=true; }
            }
        }
                ShellText { visible:root.empty; text:root.status || "/ files   ? keys"; color:App.palette.muted; font.pixelSize:12 }
            }
        }
        Rectangle {
            Layout.alignment:Qt.AlignHCenter; Layout.preferredWidth:parent.width; Layout.fillHeight:true
            color:"transparent"; topLeftRadius:0; topRightRadius:0; bottomLeftRadius:19; bottomRightRadius:19
        Flickable {
            id: scroll; anchors.fill:parent; anchors.margins:6; contentHeight:content.height; clip:true; boundsBehavior:Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            Column {
                id: content; width:scroll.width
                Column {
                    // Hovering a dot lists that workspace's windows, one row each.
                    id: hoverColumn; width:parent.width; visible:root.empty && App.hoveredWorkspace > 0; height:visible ? implicitHeight : 0
                    Repeater {
                        model:(root.groups.find(g => g.id === App.hoveredWorkspace) || {windows:[]}).windows
                        MenuRow {
                            id: hoverRow; required property var modelData; width:hoverColumn.width
                            label:modelData.wayland.title; hoverHighlight:true; selected:root.selected?.id === modelData.address && App.overviewPinned
                            leading: AppIcon { anchors.centerIn:parent; appId:hoverRow.modelData.wayland.appId; size:22 }
                            onClicked:root.run(root.windowRow(modelData),false)
                        }
                    }
                }
                Column {
                    id: workspaceColumn; width:parent.width; visible:root.empty && !hoverColumn.visible; height:visible ? implicitHeight : 0
                    Repeater {
                        model:root.groups
                        Row {
                            id: group; required property var modelData; width:workspaceColumn.width; height:Math.max(38,workspaceIcons.implicitHeight); spacing:0
                            ShellText { width:20; anchors.verticalCenter:parent.verticalCenter; text:group.modelData.id; color:group.modelData.id === Hyprland.focusedWorkspace?.id ? App.palette.accent : App.palette.muted; font.pixelSize:13 }
                            Flow {
                                id:workspaceIcons
                                width:parent.width-20; spacing:8
                                Repeater {
                                    model:group.modelData.windows
                                    Item {
                                        id: windowIcon; required property var modelData; width:22; height:38
                                        readonly property bool chosen: root.selected?.id === modelData.address
                                        Rectangle { x:0; y:34; width:22; height:2; color:App.palette.accent; visible:windowIcon.chosen && App.overviewPinned }
                                        AppIcon { anchors.centerIn:parent; appId:windowIcon.modelData.wayland.appId; size:22 }
                                        MouseArea { anchors.fill:parent; hoverEnabled:true; onEntered: { root.status=windowIcon.modelData.wayland.title; root.current=root.navigation.findIndex(r=>r.id===windowIcon.modelData.address); } onExited:root.status=""; onClicked:root.run(root.windowRow(windowIcon.modelData),false) }
                                        Accessible.role:Accessible.Button; Accessible.name:modelData.wayland.title; Accessible.onPressAction:root.run(root.windowRow(modelData),false)
                                    }
                                }
                            }
                        }
                    }
                }
                Repeater {
                    model:root.displayedEntries
                    MenuRow {
                        id: result; required property var modelData; required property int index; width:content.width
                        property color rowTone:modelData.type === "bind" ? App.palette.muted : modelData.type === "window" ? App.palette.accent : App.palette.text
                        iconColor:rowTone; labelColor:rowTone
                        glyph:modelData.glyph || ""; label:modelData.label + (root.armed === modelData.id ? " · Click again" : "")
                        selected:root.selected?.id === modelData.id && App.overviewPinned
                        leading: AppIcon { anchors.centerIn:parent; appId:result.modelData.appId || ""; visible:!!appId; size:22; tint:result.rowTone }
                        trailing: ShellText { text:root.bindFor(result.modelData)?.keys || result.modelData.trailing || ""; width:Math.min(170,implicitWidth); color:App.palette.muted; font.pixelSize:12 }
                        HoverHandler { onHoveredChanged: if (hovered) root.current=(root.empty ? root.navigation.length-root.displayedEntries.length : 0)+result.index }
                        onClicked:root.run(modelData,false)
                    }
                }
            }
        }
        }
        ShellText { visible:false; Layout.fillWidth:true; Layout.preferredHeight:16; text:root.status; color:App.palette.muted; font.pixelSize:11 }
    }
    TapHandler { gesturePolicy:TapHandler.DragThreshold; onPressedChanged:if (pressed) root.pin() }
}
