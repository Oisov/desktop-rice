pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland

Scope {
    id: notices
    property bool otherMenuOpen: false
    property bool dnd: false
    signal toastReceived(var notification)
    readonly property var trackedNotifications: notificationServer.trackedNotifications.values
    property var notificationOrder: []
    readonly property var orderedNotifications: trackedNotifications.slice().sort((a,b) => {
        const ai = notificationOrder.indexOf(a.id), bi = notificationOrder.indexOf(b.id);
        return ai < 0 && bi < 0 ? b.id-a.id : ai < 0 ? 1 : bi < 0 ? -1 : ai-bi;
    })
    readonly property var notifications: ({available: true, dnd: dnd, activeCount: trackedNotifications.length, items: orderedNotifications.map(n => {
        const actions = {};
        for (const action of n.actions) actions[action.identifier] = action.text;
        return {id:n.id, app_name:n.appName, app_icon:n.appIcon, desktop_entry:n.desktopEntry,
            summary:n.summary, body:n.body, summaryText:plainText(n.summary), bodyText:plainText(n.body),
            urgency:n.urgency === NotificationUrgency.Critical ? "critical" : "normal", actions:actions};
    })})
    function plainText(value) { return value.replace(/<[^>]*>/g, "").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '\"').replace(/&#39;|&apos;/g, "'").replace(/&amp;/g, "&").replace(/\s+/g, " ").trim(); }
    function notificationById(id) { return trackedNotifications.find(n => n.id === Number(id)); }
    function invokeNotification(id, identifier) { notificationById(id)?.actions.find(a => a.identifier === identifier)?.invoke(); }
    NotificationServer {
        id: notificationServer
        keepOnReload: true; actionsSupported: true; bodySupported: true
        bodyMarkupSupported: false; imageSupported: false; persistenceSupported: true
        onNotification: notification => {
            notification.tracked = true;
            notices.notificationOrder = [notification.id].concat(notices.orderedNotifications.filter(n => n.id !== notification.id).map(n => n.id));
            // The server adds the newly tracked object after this receive handler returns.
            const id = notification.id;
            Qt.callLater(() => {
                const history = notices.orderedNotifications.slice();
                while (history.length > 100) history.pop().dismiss();
                const received = notices.notificationById(id);
                if (received) notices.toastReceived(received);
            });
        }
        Component.onCompleted: console.info("Dynamite NotificationServer ready")
    }
    function toggleDnd() { dnd = !dnd; App.action("dnd", dnd ? "on" : "off"); }
    function action(name, value) {
        const ids = name === "notifications-clear" ? trackedNotifications.map(n => n.id) : String(value).split(",");
        if (name === "notification-invoke") invokeNotification(ids[0], "default");
        for (const id of ids) notificationById(id)?.dismiss();
    }
    property var toastQueue: []
    property var toast: null
    property int displayedToastId: 0
    property real toastRemaining: 5000
    property real toastStarted: 0
    property bool toastHovered: false
    property bool toastBlocked: false
    property bool fullscreen: false
    signal toastShown()
    signal toastHidden()
    onToastHoveredChanged: {
        if (!toast) return;
        if (toastHovered) pauseToast(); else startToastTimer();
    }
    onToastBlockedChanged: {
        if (toastBlocked && toast) { interruptToast(); toastHidden(); }
        else if (!toastBlocked) Qt.callLater(showNextToast);
    }
    function pauseToast() {
        if (toastTimer.running) toastRemaining = Math.max(1, toastRemaining - (Date.now() - toastStarted));
        toastTimer.stop();
    }
    function startToastTimer() {
        if (!toast || toastHovered || notificationById(toast.id)?.urgency === NotificationUrgency.Critical) return;
        toastStarted = Date.now(); toastTimer.interval = Math.max(1, toastRemaining); toastTimer.restart();
    }
    function interruptToast() {
        if (!toast) return;
        pauseToast();
        toastQueue = [{id:toast.id, remaining:toastRemaining}].concat(toastQueue.filter(t => t.id !== toast.id));
        toast = null;
    }
    function hideToast() {
        toastTimer.stop(); toast = null;
        toastHidden();
        Qt.callLater(showNextToast);
    }
    function showNextToast() {
        if (toast || toastBlocked) return;
        while (toastQueue.length) {
            const pending = toastQueue.slice().sort((a,b) => b.id-a.id);
            const next = pending[0]; toastQueue = pending.slice(1);
            const n = notificationById(next.id);
            if (!n || (dnd && n.urgency !== NotificationUrgency.Critical)) continue;
            toast = next; displayedToastId = n.id; toastRemaining = next.remaining;
            toastShown();
            startToastTimer(); return;
        }
    }
    function activateToast(identifier) {
        const id = toast?.id;
        if (!id) return;
        if (identifier) invokeNotification(id, identifier);
        else {
            const n = notificationById(id);
            if (n?.actions.some(a => a.identifier === "default")) invokeNotification(id, "default");
            else {
                const keys = [n?.desktopEntry, n?.appName].filter(Boolean).map(k => k.toLowerCase().replace(/\.desktop$/, ""));
                const window = ToplevelManager.toplevels.values.find(t => keys.some(k => t.appId.toLowerCase().includes(k)));
                if (window) window.activate();
            }
        }
        hideToast();
    }
    Timer { id: toastTimer; onTriggered: notices.hideToast() }
    Connections {
        target: notices
        function onToastReceived(n) {
            if (notices.fullscreen || dnd && n.urgency !== NotificationUrgency.Critical) return;
            if (notices.toast?.id === n.id) notices.hideToast();
            notices.toastQueue = [{id:n.id, remaining:n.expireTimeout > 0 ? n.expireTimeout : 5000}].concat(notices.toastQueue.filter(t => t.id !== n.id));
            Qt.callLater(notices.showNextToast);
        }
        function onTrackedNotificationsChanged() {
            notices.toastQueue = notices.toastQueue.filter(t => notificationById(t.id));
            if (notices.toast && !notificationById(notices.toast.id)) notices.hideToast();
        }
        function onDndChanged() {
            if (dnd) {
                notices.toastQueue = notices.toastQueue.filter(t => notificationById(t.id)?.urgency === NotificationUrgency.Critical);
                if (notices.toast && notificationById(notices.toast.id)?.urgency !== NotificationUrgency.Critical) notices.hideToast();
            }
        }
    }
}
