pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import ".."

Item {
    id: menu
    property Item anchor: null
    readonly property bool pinnable: true
    function key(event) {
        if ([Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down, Qt.Key_Home].includes(event.key)) {
            if (event.key === Qt.Key_Home) calendarToday();
            else moveCalendar(event.key === Qt.Key_Left ? -1 : event.key === Qt.Key_Right ? 1 : event.key === Qt.Key_Up ? -12 : 12);
        } else if ([Qt.Key_Return, Qt.Key_Enter].includes(event.key)) calendarToday();
        else return false;
        return true;
    }
    function refresh() { App.refresh(); }
    required property var frame
    function opened() { calendarHovered = null; calendarToday(); }
    function closed() { calendarHovered = null; }
    SystemClock { id: calendarClock; precision: SystemClock.Minutes }
    property date calendarMonth: new Date(calendarClock.date.getFullYear(), calendarClock.date.getMonth(), 1, 12)
    property var calendarHovered: null
    readonly property bool calendarCurrent: calendarMonth.getFullYear() === calendarClock.date.getFullYear() && calendarMonth.getMonth() === calendarClock.date.getMonth()
    readonly property date calendarStart: {
        const d = new Date(calendarMonth.getTime());
        d.setDate(1 - (d.getDay() + 6) % 7);
        return d;
    }
    function setCalendarMonth(year, month) {
        if (year < 1 || year > 9999 || month < 1 || month > 12) return;
        calendarMonth = new Date(year, month - 1, 1, 12); calendarHovered = null;
    }
    function moveCalendar(months) {
        const d = new Date(calendarMonth.getTime()); d.setMonth(d.getMonth() + months);
        setCalendarMonth(d.getFullYear(), d.getMonth() + 1);
    }
    function calendarToday() { setCalendarMonth(calendarClock.date.getFullYear(), calendarClock.date.getMonth() + 1); }
    function calendarDay(offset) { const d = new Date(calendarStart.getTime()); d.setDate(d.getDate() + offset); return d; }
    function sameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate(); }
    function easter(year) {
        const a = year % 19, b = Math.floor(year / 100), c = year % 100;
        const d = Math.floor(b / 4), e = b % 4, f = Math.floor((b + 8) / 25), g = Math.floor((b - f + 1) / 3);
        const h = (19 * a + b - d - g + 15) % 30, i = Math.floor(c / 4), k = c % 4;
        const l = (32 + 2 * e + 2 * i - h - k) % 7, m = Math.floor((a + 11 * h + 22 * l) / 451);
        const n = h + l - 7 * m + 114;
        return new Date(year, Math.floor(n / 31) - 1, n % 31 + 1, 12);
    }
    function holiday(date) {
        const fixed = {"1-1":"Nyttårsdag", "5-1":"Arbeidernes dag", "5-17":"Grunnlovsdag", "12-25":"1. juledag", "12-26":"2. juledag"};
        const name = fixed[(date.getMonth() + 1) + "-" + date.getDate()];
        if (name) return name;
        const sunday = easter(date.getFullYear());
        const offset = Math.round((Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()) - Date.UTC(sunday.getFullYear(), sunday.getMonth(), sunday.getDate())) / 86400000);
        return ({"-3":"Skjærtorsdag", "-2":"Langfredag", "0":"1. påskedag", "1":"2. påskedag", "39":"Kristi himmelfartsdag", "49":"1. pinsedag", "50":"2. pinsedag"})[offset] || "";
    }
    readonly property string calendarInfo: {
        const date = calendarHovered || calendarClock.date, name = holiday(date);
        return App.longDate(date) + (name ? " · " + name : "");
    }
    property Item l2: MenuRow {
            visible: menu.frame.displayedMenu === menu
            x: 10; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 20
            glyph: "󰃭"; hoverHighlight: false; marquee: true; scrollNow: true
            label: menu.calendarInfo
        }
    property Item l3: Item {
        anchors.fill: parent
        implicitHeight: 252
            Column {
                id: calendarGrid
                visible: menu.frame.displayedMenu === menu
                x: 10; y: 2; width: parent.width - 20
                RowLayout {
                    width: parent.width; height: 38; spacing: 6
                    ShellButton { small: true; implicitWidth: 28; implicitHeight: 32; glyph: "󰄽"; text: "Previous year"; focusPolicy: Qt.NoFocus; onClicked: menu.moveCalendar(-12) }
                    ShellButton { small: true; implicitWidth: 28; implicitHeight: 32; glyph: "󰅁"; text: "Previous month"; focusPolicy: Qt.NoFocus; onClicked: menu.moveCalendar(-1) }
                    Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: menu.calendarMonth.toLocaleDateString(Qt.locale(), "MMMM yyyy"); color: App.palette.text; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 13 }
                    ShellButton { small: true; implicitWidth: 28; implicitHeight: 32; glyph: "󰅂"; text: "Next month"; focusPolicy: Qt.NoFocus; onClicked: menu.moveCalendar(1) }
                    ShellButton { small: true; implicitWidth: 28; implicitHeight: 32; glyph: "󰄾"; text: "Next year"; focusPolicy: Qt.NoFocus; onClicked: menu.moveCalendar(12) }
                    ShellButton { visible: !menu.calendarCurrent; small: true; implicitWidth: 28; implicitHeight: 32; glyph: "󰃭"; text: "Today"; focusPolicy: Qt.NoFocus; onClicked: menu.calendarToday() }
                }
                Item {
                    width: parent.width; height: 30 + 6 * 30
                    MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; onWheel: event => { menu.moveCalendar(event.angleDelta.y > 0 ? -1 : 1); event.accepted = true; } }
                    Column {
                        anchors.fill: parent
                        Row {
                            width: parent.width; height: 30
                            Repeater {
                                model: 8
                                Text {
                                    required property int index
                                    width: calendarGrid.width / 8; height: 30
                                    text: {
                                        if (index === 0) return "Wk";
                                        const narrow = Qt.locale().dayName(index, Locale.NarrowFormat);
                                        // The C locale uses digits for narrow day names.
                                        return /^\d+$/.test(narrow) ? Qt.locale().dayName(index, Locale.ShortFormat).slice(0, 1) : narrow;
                                    }
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                    font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12; color: App.palette.muted
                                }
                            }
                        }
                        Repeater {
                            model: 6
                            Row {
                                id: calendarWeek
                                required property int index
                                width: calendarGrid.width; height: 30
                                Text { width: calendarGrid.width / 8; height: 30; text: App.isoWeek(menu.calendarDay(calendarWeek.index * 7)); color: App.palette.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                Repeater {
                                    model: 7
                                    Item {
                                        id: dayCell
                                        required property int index
                                        readonly property date date: menu.calendarDay(calendarWeek.index * 7 + index)
                                        readonly property bool today: menu.sameDay(date, calendarClock.date)
                                        width: calendarGrid.width / 8; height: 30
                                        opacity: date.getMonth() === menu.calendarMonth.getMonth() ? 1 : 0.5
                                        Rectangle { anchors.centerIn: parent; width: 26; height: 26; radius: 13; color: App.palette.surface; visible: dayCell.today }
                                        Text {
                                            anchors.centerIn: parent; text: dayCell.date.getDate()
                                            color: dayCell.today ? App.palette.accent : dayCell.date.getMonth() !== menu.calendarMonth.getMonth() ? App.palette.muted : dayCell.date.getDay() === 0 || menu.holiday(dayCell.date) ? "#e18593" : App.palette.text
                                            font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 13; font.weight: dayCell.today ? Font.DemiBold : Font.Normal
                                        }
                                        HoverHandler { onHoveredChanged: { if (hovered) menu.calendarHovered = dayCell.date; else if (menu.calendarHovered && menu.sameDay(menu.calendarHovered, dayCell.date)) menu.calendarHovered = null; } }
                                    }
                                }
                            }
                        }
                    }
                }
            }
    }
}
