import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Item {
    id: store

    DankCalendarConstants { id: constants }

    // Configurable properties
    property int refreshInterval: constants.defaultRefreshInterval
    property int lookAheadDays: constants.defaultLookAheadDays
    property int nowWindowMinutes: constants.defaultNowWindowMinutes
    property int agendaPastDays: constants.defaultAgendaPastDays
    property int agendaFutureDays: constants.defaultAgendaFutureDays
    property var notificationManager: null
    property bool eventReminderEnabled: true
    property int eventReminderMinutes: 5
    property var notifiedEventKeys: ({})

    readonly property bool use24HourClock: (typeof SettingsData !== "undefined" && SettingsData) ? (SettingsData.use24HourClock ?? true) : true
    readonly property bool padHours12Hour: (typeof SettingsData !== "undefined" && SettingsData) ? (SettingsData.padHours12Hour ?? false) : false

    function formatTime(time) {
        if (!time) return "";
        var d = (time instanceof Date) ? time : new Date(time);
        if (!store.use24HourClock) {
            return store.padHours12Hour ? Qt.formatTime(d, "hh:mm AP") : Qt.formatTime(d, "h:mm AP");
        }
        return Qt.formatTime(d, "HH:mm");
    }

    onAgendaPastDaysChanged: {
        store.agendaLoading = true;
        if (!fetchAgendaProc.running) fetchAgendaProc.running = true;
    }
    onAgendaFutureDaysChanged: {
        store.agendaLoading = true;
        if (!fetchAgendaProc.running) fetchAgendaProc.running = true;
    }

    // State
    property string eventSummary: ""
    property string eventCleanSummary: ""
    property var eventTags: []
    property string eventStart: ""
    property string eventEnd: ""
    property bool eventAllDay: false
    property string eventLocation: ""
    property string eventDescription: ""
    property string eventMeetingUrl: ""
    property string eventUrl: ""
    property bool isLoading: true

    property real countdownNow: Date.now()
    property real remainingMs: {
        if (!eventStart) return -1;
        return eventDate(eventStart, eventAllDay).getTime() - countdownNow;
    }
    property bool isNow: {
        if (!eventStart || nowWindowMinutes <= 0) return false;
        var startMs = eventDate(eventStart, eventAllDay).getTime();
        var nowWindowMs = nowWindowMinutes * 60000;
        return countdownNow >= startMs && countdownNow <= (startMs + nowWindowMs);
    }
    property bool isLessThanOneMin: !isNow && remainingMs > 0 && remainingMs < 60000
    property bool hasEvent: eventSummary !== ""
    property string timeText: formatTimeRemaining()
    property string compactTimeText: formatCompactTimeRemaining()
    property color timeColor: Theme.primary

    property var agendaEvents: []
    property var agendaModel: []
    property int agendaContentHeight: 0
    property int agendaTodayOffset: 0
    property bool agendaLoading: true
    property bool hasSyncError: false
    property string syncErrorMessage: ""

    readonly property int upcomingCount: {
        var n = 0;
        for (var i = 0; i < agendaEvents.length; i++) {
            var ev = agendaEvents[i];
            if (eventDate(ev.end || ev.start, ev.allDay).getTime() >= countdownNow)
                n++;
        }
        return n;
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            store.countdownNow = Date.now();
            store.checkUpcomingEventReminder();
        }
    }

    Timer {
        id: refreshTimer
        interval: store.refreshInterval
        running: true
        repeat: true
        onTriggered: store.refreshAll()
    }

    Process {
        id: fetchNextProc
        command: [constants.coreScriptPath, "agenda", "next", "--lookahead", String(store.lookAheadDays), "--now-window", String(store.nowWindowMinutes)]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var trimmed = (text || "").trim();
                if (!trimmed) return;
                try {
                    var payload = JSON.parse(trimmed);
                    store.applyEventPayload(payload);
                    store.isLoading = false;
                    store.hasSyncError = false;
                } catch (e) {
                    console.warn("[CalendarStore] next parse error:", e);
                    store.isLoading = false;
                }
            }
        }
        onExited: (code) => {
            store.isLoading = false;
            if (code !== 0) {
                store.hasSyncError = true;
                store.syncErrorMessage = "日历服务连接异常";
            }
        }
    }

    Process {
        id: fetchAgendaProc
        command: [constants.coreScriptPath, "agenda", "get", "--past", String(store.agendaPastDays), "--future", String(store.agendaFutureDays)]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var trimmed = (text || "").trim();
                if (!trimmed) return;
                try {
                    var events = JSON.parse(trimmed);
                    if (Array.isArray(events)) {
                        events.sort((a, b) => {
                            var dayA = store.dateKey(store.eventDate(a.start, a.allDay));
                            var dayB = store.dateKey(store.eventDate(b.start, b.allDay));
                            if (dayA !== dayB) return dayA - dayB;
                            if ((a.allDay === true) !== (b.allDay === true)) return a.allDay ? -1 : 1;
                            return store.eventDate(a.start, a.allDay) - store.eventDate(b.start, b.allDay);
                        });
                        store.agendaEvents = events;
                        store.agendaModel = store.buildAgenda(events);
                        store.agendaLoading = false;
                        store.hasSyncError = false;
                    }
                } catch (e) {
                    console.warn("[CalendarStore] agenda parse error:", e);
                    store.agendaLoading = false;
                }
            }
        }
        onExited: (code) => {
            store.agendaLoading = false;
            if (code !== 0) {
                store.hasSyncError = true;
                store.syncErrorMessage = "同步失败，请检查日历服务";
            }
        }
    }

    function refreshAll() {
        store.isLoading = true;
        store.agendaLoading = true;
        Quickshell.execDetached(["dcal", "ipc", "accounts.refresh"]);
        if (!fetchNextProc.running) fetchNextProc.running = true;
        if (!fetchAgendaProc.running) fetchAgendaProc.running = true;
    }

    function formatTimeRemaining() {
        if (!hasEvent) return "";
        if (isNow) return "Now";
        if (isLessThanOneMin) return "<1m";
        if (remainingMs < 0) return "";
        var totalMinutes = Math.floor(remainingMs / 60000);
        var days = Math.floor(totalMinutes / 1440);
        var hours = Math.floor((totalMinutes % 1440) / 60);
        var minutes = totalMinutes % 60;
        var parts = [];
        if (days > 0) parts.push(days + "d");
        if (hours > 0) parts.push(hours + "h");
        if (minutes > 0) parts.push(minutes + "m");
        return parts.join("") || "<1m";
    }

    function formatCompactTimeRemaining() {
        if (!hasEvent) return "";
        if (isNow) return "Now";
        if (isLessThanOneMin) return "<1m";
        if (remainingMs < 0) return "";
        var totalMinutes = Math.floor(remainingMs / 60000);
        var days = Math.floor(totalMinutes / 1440);
        if (days > 0) return days + "d";
        var hours = Math.floor(totalMinutes / 60);
        if (hours > 0) return hours + "h";
        return Math.max(1, totalMinutes) + "m";
    }

    function applyEventPayload(payload) {
        eventSummary = payload.summary || "";
        eventCleanSummary = payload.cleanSummary || payload.summary || "";
        eventTags = payload.tags || [];
        eventStart = payload.start || "";
        eventEnd = payload.end || "";
        eventAllDay = payload.allDay === true;
        eventLocation = payload.location || "";
        eventDescription = payload.description || "";
        eventMeetingUrl = payload.meetingUrl || "";
        eventUrl = payload.url || "";
        store.checkUpcomingEventReminder();
    }

    function checkUpcomingEventReminder() {
        if (!eventReminderEnabled || !notificationManager || !hasEvent || !eventStart) return;
        var thresholdMs = (eventReminderMinutes || 5) * 60000;
        if (remainingMs > 0 && remainingMs <= thresholdMs) {
            var evKey = (eventStart || "") + "_" + (eventSummary || "");
            if (!notifiedEventKeys[evKey]) {
                var newKeys = Object.assign({}, notifiedEventKeys);
                newKeys[evKey] = true;
                notifiedEventKeys = newKeys;

                var minsLeft = Math.max(1, Math.round(remainingMs / 60000));
                var timeStr = "";
                try {
                    var d = eventDate(eventStart, eventAllDay);
                    timeStr = store.formatTime(d);
                } catch(e) {}

                var bodyText = "将在 " + minsLeft + " 分钟后开始" + (timeStr ? (" (" + timeStr + ")") : "");
                if (eventLocation) bodyText += "\n地点: " + eventLocation;

                notificationManager.notify(
                    "📅 日程即将开始: " + (eventCleanSummary || eventSummary),
                    bodyText,
                    "com.danklinux.dankcalendar",
                    "info"
                );
            }
        }
    }

    function eventDate(iso, allDay) {
        if (!iso) return new Date();
        var d = new Date(iso);
        if (allDay === true) {
            return new Date(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
        }
        return d;
    }

    function formatLocalDate(d, fmt) {
        return Qt.formatDateTime(d, fmt);
    }

    function dateKey(d) {
        return d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate();
    }

    function buildAgenda(events) {
        var rows = [];
        var height = 0;
        var todayOffset = -1;
        var today = new Date();
        var todayKey = dateKey(today);
        var lastDayKey = -1;
        var lastWeekKey = -1;

        for (var i = 0; i < events.length; i++) {
            var d = eventDate(events[i].start, events[i].allDay);
            var k = dateKey(d);
            if (k !== lastDayKey) {
                if (todayOffset < 0 && k >= todayKey) todayOffset = height;
                var wk = d.getFullYear() * 100 + Math.floor(d.getDate() / 7);
                if (wk !== lastWeekKey) {
                    rows.push({ kind: "week", label: formatLocalDate(d, "MMMM yyyy") });
                    height += 28;
                    lastWeekKey = wk;
                }
                var isToday = (k === todayKey);
                var dayLabel = isToday ? "Today, " + formatLocalDate(d, "d MMMM") : formatLocalDate(d, "dddd d MMMM");
                rows.push({ kind: "day", label: dayLabel, isToday: isToday });
                height += 32;
                lastDayKey = k;
            }
            rows.push({ kind: "event", ev: events[i] });
            height += 52;
        }

        if (todayOffset < 0) {
            todayOffset = Math.max(0, height - 380);
        }
        store.agendaContentHeight = height;
        store.agendaTodayOffset = Math.max(0, todayOffset);
        return rows;
    }

    function eventTimeLabel(ev) {
        if (ev.allDay) return "All day";
        var s = eventDate(ev.start, false);
        var label = store.formatTime(s);
        if (ev.end) {
            label += "–" + store.formatTime(eventDate(ev.end, false));
        }
        return label;
    }

    function eventPhase(ev) {
        var now = store.countdownNow;
        var s = eventDate(ev.start, ev.allDay).getTime();
        var e = ev.end ? eventDate(ev.end, ev.allDay).getTime() : s + 3600000;
        if (now < s) return "future";
        if (now >= s && now <= e) return "now";
        return "past";
    }

    function getEventMeetingUrl(ev) {
        if (!ev) return "";
        var m = String(ev.meetingUrl || "").trim();
        if (/^https?:\/\/[^\s/]+(?:[/?#][^\s]*)?$/i.test(m)) return m;

        var loc = String(ev.location || "").trim();
        var locMatch = loc.match(/https?:\/\/(?:[a-zA-Z0-9-]+\.)*(?:zoom\.us|meet\.google\.com|teams\.microsoft\.com|voovmeeting\.com|meeting\.tencent\.com|webex\.com|feishu\.cn|dingtalk\.com)[^\s]*/i);
        if (locMatch) return locMatch[0];

        if (/^https?:\/\/[^\s/]+(?:[/?#][^\s]*)?$/i.test(loc)) return loc;

        var desc = String(ev.description || "");
        var descMatch = desc.match(/https?:\/\/(?:[a-zA-Z0-9-]+\.)*(?:zoom\.us|meet\.google\.com|teams\.microsoft\.com|voovmeeting\.com|meeting\.tencent\.com|webex\.com|feishu\.cn|dingtalk\.com)[^\s<>"')]+/i);
        if (descMatch) return descMatch[0];

        var u = String(ev.url || "").trim();
        if (/https?:\/\/(?:[a-zA-Z0-9-]+\.)*(?:zoom\.us|meet\.google\.com|teams\.microsoft\.com|voovmeeting\.com|meeting\.tencent\.com|webex\.com|feishu\.cn|dingtalk\.com)/i.test(u)) return u;

        return "";
    }

    function deleteEvent(ev) {
        if (!ev || !ev.id) return;
        if (ev.recurringId && ev.start) {
            store.agendaEvents = store.agendaEvents.filter(e => !(e.id === ev.id && e.start === ev.start));
        } else {
            store.agendaEvents = store.agendaEvents.filter(e => e.id !== ev.id);
        }
        store.agendaModel = store.buildAgenda(store.agendaEvents);
        var cmdArgs = ["dcal", "ipc", "events.delete", "id=" + ev.id];
        if (ev.recurringId && ev.start) {
            cmdArgs.push("occurrenceStart=" + ev.start);
        }
        Quickshell.execDetached(cmdArgs);
    }

    Component.onCompleted: {
        refreshAll();
    }
}
