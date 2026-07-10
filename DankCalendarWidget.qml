import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

// Next-event countdown for dcal / DankCalendar, click model borrowed from
// dms-dankmail: left click opens a popout with today's events (click one to
// open its details in DankCalendar), right click refreshes, middle click
// toggles the DankCalendar window. Hovering the pill still shows the
// next-event tooltip.
PluginComponent {
    id: root

    property string eventSummary: ""
    property string eventStart: ""
    property string eventEnd: ""
    property bool isLoading: true
    property int refreshInterval: (pluginData.refreshInterval || 30) * 1000
    property int pillMaxWidth: pluginData.pillMaxWidth || 160
    property bool dynamicWidth: pluginData.dynamicWidth ?? false
    property int lookAheadDays: pluginData.lookAheadDays || 1
    property int nowWindowMinutes: pluginData.nowWindowMinutes ?? 5
    property bool showTooltip: pluginData.showTooltip ?? true
    property real countdownNow: Date.now()
    property real remainingMs: {
        if (!eventStart)
            return -1;

        var startMs = new Date(eventStart).getTime();
        return startMs - countdownNow;
    }
    property bool isNow: {
        if (nowWindowMinutes <= 0 || eventStart === "" || remainingMs > 0)
            return false;

        var startMs = new Date(eventStart).getTime();
        var endMs = eventEnd ? new Date(eventEnd).getTime() : startMs;
        var duration = endMs - startMs;
        var maxWindow = nowWindowMinutes * 60000;
        var nowWindow = duration < maxWindow ? duration : maxWindow;
        return countdownNow < startMs + nowWindow;
    }
    property bool isLessThanOneMin: !isNow && remainingMs > 0 && remainingMs < 60000
    property bool hasEvent: eventSummary !== ""
    property string timeText: formatTimeRemaining()
    property color timeColor: isNow ? "#66BB6A" : Theme.surfaceText
    property string scriptPath: PluginService.pluginDirectory + "/dankCalendar/get-next-event"
    property string todayScriptPath: PluginService.pluginDirectory + "/dankCalendar/get-today-events"
    property var todayEvents: []
    property bool todayLoading: true

    // Left click opens the popout (automatic when popoutContent is set);
    // right click re-fetches both the countdown and today's list; middle
    // click (MouseArea in each pill) toggles the DankCalendar window.
    pillRightClickAction: () => root.refreshAll()

    function formatTimeRemaining() {
        if (!hasEvent)
            return "";

        if (isNow)
            return "Now";

        if (isLessThanOneMin)
            return "<1m";

        if (remainingMs < 0)
            return "";

        var totalMinutes = Math.floor(remainingMs / 60000);
        var days = Math.floor(totalMinutes / 1440);
        var hours = Math.floor((totalMinutes % 1440) / 60);
        var minutes = totalMinutes % 60;
        var parts = [];
        if (days > 0)
            parts.push(days + "d");

        if (hours > 0)
            parts.push(hours + "h");

        if (minutes > 0)
            parts.push(minutes + "m");

        return parts.join("") || "<1m";
    }

    function parseLine(line) {
        var idx = line.indexOf("=");
        if (idx < 0)
            return ;

        var key = line.substring(0, idx);
        var val = line.substring(idx + 1);
        switch (key) {
        case "EVENT_SUMMARY":
            eventSummary = val;
            break;
        case "EVENT_START":
            eventStart = val;
            break;
        case "EVENT_END":
            eventEnd = val;
            break;
        }
    }

    function toggleDcal() {
        Quickshell.execDetached(["dcal", "ipc", "ui.toggle", "view=day"]);
    }

    function openEvent(ev) {
        // events.list gives the occurrence start, which ui.openEvent needs
        // to resolve recurring events; for one-offs it matches and is inert.
        Quickshell.execDetached(["dcal", "ipc", "ui.openEvent", "uid=" + ev.uid, "start=" + ev.start]);
    }

    function refreshAll() {
        root.isLoading = true;
        root.todayLoading = true;
        if (!fetchProcess.running)
            fetchProcess.running = true;

        if (!todayProcess.running)
            todayProcess.running = true;

    }

    function eventTimeLabel(ev) {
        if (ev.allDay)
            return "All day";

        var label = Qt.formatTime(new Date(ev.start), "HH:mm");
        if (ev.end)
            label += "–" + Qt.formatTime(new Date(ev.end), "HH:mm");

        return label;
    }

    // "past" dims the row, "now" paints it green — both keyed off the same
    // countdownNow tick that drives the pill.
    function eventPhase(ev) {
        var startMs = new Date(ev.start).getTime();
        var endMs = ev.end ? new Date(ev.end).getTime() : startMs;
        if (root.countdownNow >= endMs)
            return "past";

        return root.countdownNow >= startMs ? "now" : "upcoming";
    }

    Process {
        id: fetchProcess

        command: ["bash", root.scriptPath, String(root.lookAheadDays), String(root.nowWindowMinutes)]
        running: false
        onExited: (exitCode, exitStatus) => {
            console.log("[dankCalendar] script exited:", exitCode, "summary:", root.eventSummary, "start:", root.eventStart);
            root.isLoading = false;
        }

        stdout: SplitParser {
            onRead: (data) => {
                return root.parseLine(data.trim());
            }
        }

        stderr: SplitParser {
            onRead: (data) => {
                return console.warn("[dankCalendar]", data);
            }
        }

    }

    Process {
        id: todayProcess

        command: ["bash", root.todayScriptPath]
        running: false
        onExited: (exitCode, exitStatus) => {
            root.todayLoading = false;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                var events = [];
                try {
                    events = JSON.parse(text).events || [];
                } catch (e) {
                    console.warn("[dankCalendar] today-events parse failed:", e);
                }
                events.sort((a, b) => {
                    if ((a.allDay === true) !== (b.allDay === true))
                        return a.allDay ? -1 : 1;

                    return new Date(a.start) - new Date(b.start);
                });
                root.todayEvents = events;
            }
        }

        stderr: SplitParser {
            onRead: (data) => {
                return console.warn("[dankCalendar]", data);
            }
        }

    }

    Timer {
        interval: root.refreshInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!fetchProcess.running)
                fetchProcess.running = true;

            if (!todayProcess.running)
                todayProcess.running = true;

        }
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.countdownNow = Date.now();
        }
    }

    function showEventTooltip(pill) {
        if (!root.showTooltip || !pill || !root.parentScreen)
            return ;

        var screen = root.parentScreen;
        var edge = root.axis?.edge ?? (root.isVertical ? "left" : "top");
        var gap = (root.barConfig?.spacing ?? 4) + Theme.spacingXS;
        var center = pill.mapToItem(null, pill.width / 2, pill.height / 2);
        var side, anchorX, anchorY;
        if (edge === "left") {
            side = "right";
            anchorX = root.barThickness + gap;
            anchorY = center.y;
        } else if (edge === "right") {
            side = "left";
            anchorX = screen.width - root.barThickness - gap;
            anchorY = center.y;
        } else if (edge === "bottom") {
            side = "top";
            anchorX = center.x;
            anchorY = screen.height - root.barThickness - gap;
        } else {
            side = "bottom";
            anchorX = center.x;
            anchorY = root.barThickness + gap;
        }
        // Stash the target so onLoaded can show it if the PanelWindow's Wayland
        // surface isn't ready synchronously on first activation.
        eventTooltipLoader.pendingX = anchorX;
        eventTooltipLoader.pendingY = anchorY;
        eventTooltipLoader.pendingScreen = screen;
        eventTooltipLoader.pendingSide = side;
        eventTooltipLoader.pendingShow = true;
        eventTooltipLoader.active = true;
        if (eventTooltipLoader.item)
            eventTooltipLoader.item.showAt(anchorX, anchorY, screen, side);
    }

    function hideEventTooltip() {
        eventTooltipLoader.pendingShow = false;
        if (eventTooltipLoader.item)
            eventTooltipLoader.item.hideTip();
        // Tear down the Wayland surface instead of leaving it hidden for the session.
        eventTooltipLoader.active = false;
    }

    Loader {
        id: eventTooltipLoader

        active: false

        property real pendingX: 0
        property real pendingY: 0
        property var pendingScreen: null
        property string pendingSide: "right"
        property bool pendingShow: false

        onLoaded: if (pendingShow)
            item.showAt(pendingX, pendingY, pendingScreen, pendingSide)

        sourceComponent: PanelWindow {
            id: ttip

            property real targetX: 0
            property real targetY: 0
            property string side: "right"

            function showAt(x, y, scr, placement) {
                ttip.screen = scr ?? null;
                targetX = x;
                targetY = y;
                side = placement;
                visible = true;
            }

            function hideTip() {
                visible = false;
            }

            WlrLayershell.namespace: "dms:plugins:dankcalendar-tooltip"
            WlrLayershell.layer: WlrLayershell.Overlay
            WlrLayershell.exclusiveZone: -1
            color: "transparent"
            visible: false
            implicitWidth: ttBg.implicitWidth
            implicitHeight: ttBg.implicitHeight
            // Empty input region: the tooltip is purely visual and never steals
            // clicks from the pill underneath it.
            mask: Region {
            }

            anchors {
                top: true
                left: true
            }

            margins {
                left: {
                    var sw = ttip.screen?.width ?? Screen.width;
                    var lx;
                    if (ttip.side === "right")
                        lx = ttip.targetX;
                    else if (ttip.side === "left")
                        lx = ttip.targetX - ttip.implicitWidth;
                    else
                        lx = ttip.targetX - ttip.implicitWidth / 2;
                    return Math.round(Math.max(Theme.spacingS, Math.min(sw - ttip.implicitWidth - Theme.spacingS, lx)));
                }
                top: {
                    var sh = ttip.screen?.height ?? Screen.height;
                    var ty;
                    if (ttip.side === "bottom")
                        ty = ttip.targetY;
                    else if (ttip.side === "top")
                        ty = ttip.targetY - ttip.implicitHeight;
                    else
                        ty = ttip.targetY - ttip.implicitHeight / 2;
                    return Math.round(Math.max(Theme.spacingS, Math.min(sh - ttip.implicitHeight - Theme.spacingS, ty)));
                }
            }

            Rectangle {
                id: ttBg

                implicitWidth: ttCol.width + Theme.spacingM * 2
                implicitHeight: ttCol.implicitHeight + Theme.spacingS * 2
                color: Theme.withAlpha(Theme.surfaceContainerHigh, root.barConfig?.transparency ?? 1)
                radius: Theme.cornerRadius
                border.width: 1
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)

                Column {
                    id: ttCol

                    x: Theme.spacingM
                    y: Theme.spacingS
                    // Scale with the theme font so the tooltip stays sensible
                    // across DPI / screen sizes instead of a fixed pixel width.
                    width: Math.round(Theme.fontSizeSmall * 18)
                    spacing: 2

                    StyledText {
                        width: parent.width
                        text: root.hasEvent ? root.eventSummary : "No events"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        width: parent.width
                        visible: root.hasEvent && root.timeText !== ""
                        text: root.isNow ? "Happening now" : ("Starts in " + root.timeText)
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.timeColor
                        wrapMode: Text.WordWrap
                    }

                }

            }

        }

    }

    popoutWidth: 420
    popoutHeight: 500
    popoutContent: Component {
        PopoutComponent {
            id: popout

            // Custom header (the built-in one hides with empty headerText):
            // the title itself opens DankCalendar, dankmail-style.
            Item {
                width: parent.width
                height: 48

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    StyledText {
                        text: "Dank Calendar"
                        font.pixelSize: Theme.fontSizeLarge + 2
                        font.weight: Font.Bold
                        color: titleHover.hovered ? Theme.primary : Theme.surfaceText
                    }

                    StyledText {
                        text: Qt.formatDate(new Date(), "dddd, d MMMM") + (root.todayEvents.length > 0 ? "  ·  " + root.todayEvents.length + (root.todayEvents.length === 1 ? " event" : " events") : "")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    HoverHandler {
                        id: titleHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: {
                            root.toggleDcal();
                            if (popout.closePopout)
                                popout.closePopout();

                        }
                    }

                }

                Row {
                    spacing: Theme.spacingXS
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter

                    DankActionButton {
                        iconName: "sync"
                        iconColor: root.todayLoading ? Theme.primary : Theme.surfaceText
                        onClicked: root.refreshAll()
                    }

                    DankActionButton {
                        iconName: "close"
                        onClicked: {
                            if (popout.closePopout)
                                popout.closePopout();

                        }
                    }

                }

            }

            Item {
                width: parent.width
                // The list scrolls inside a fixed viewport when it grows
                // beyond the popout.
                readonly property real maxListHeight: 410

                implicitHeight: Math.min(eventColumn.implicitHeight + Theme.spacingM * 2, maxListHeight)

                DankFlickable {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    contentHeight: eventColumn.implicitHeight
                    clip: true

                    Column {
                        id: eventColumn

                        width: parent.width
                        spacing: 2

                        StyledText {
                            visible: root.todayEvents.length === 0
                            width: parent.width
                            text: root.todayLoading ? "Loading events…" : "No events today."
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        Repeater {
                            model: root.todayEvents

                            delegate: Rectangle {
                                id: eventRow

                                required property var modelData
                                readonly property string phase: root.eventPhase(modelData)

                                width: eventColumn.width
                                height: 52
                                radius: Theme.cornerRadiusSmall
                                color: rowHover.hovered ? Theme.surfaceContainerHigh : "transparent"

                                HoverHandler {
                                    id: rowHover

                                    cursorShape: Qt.PointingHandCursor
                                }

                                Row {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: Theme.spacingS
                                    anchors.rightMargin: Theme.spacingS
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingS

                                    Rectangle {
                                        width: 4
                                        height: 34
                                        radius: 2
                                        color: eventRow.phase === "now" ? "#66BB6A" : (eventRow.phase === "past" ? Theme.surfaceVariantText : Theme.primary)
                                        opacity: eventRow.phase === "past" ? 0.4 : 1
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        width: parent.width - 4 - Theme.spacingS * 2
                                        spacing: 1
                                        anchors.verticalCenter: parent.verticalCenter

                                        StyledText {
                                            width: parent.width
                                            text: eventRow.modelData.summary || "(untitled)"
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: eventRow.phase === "past" ? Font.Normal : Font.Medium
                                            color: eventRow.phase === "past" ? Theme.surfaceVariantText : Theme.surfaceText
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }

                                        StyledText {
                                            width: parent.width
                                            text: root.eventTimeLabel(eventRow.modelData) + (eventRow.phase === "now" ? "  ·  Now" : "") + (eventRow.modelData.location ? "  ·  " + eventRow.modelData.location : "")
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: eventRow.phase === "now" ? "#66BB6A" : Theme.surfaceVariantText
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }

                                    }

                                }

                                // Click on the row → open the event's details
                                // window in DankCalendar.
                                TapHandler {
                                    onTapped: {
                                        root.openEvent(eventRow.modelData);
                                        if (popout.closePopout)
                                            popout.closePopout();

                                    }
                                }

                            }

                        }

                    }

                }

            }

        }

    }

    horizontalBarPill: Component {
        Item {
            id: hPill

            implicitWidth: hRow.implicitWidth
            implicitHeight: hRow.implicitHeight

            // Middle click on the pill: toggle DankCalendar directly (left
            // opens the popout, right refreshes). Only MiddleButton is
            // accepted, so left/right fall through to BasePill.
            MouseArea {
                anchors.fill: parent
                // Cover BasePill's padding too — middle clicks on the
                // capsule margin were falling through to the bar canvas.
                anchors.margins: -10
                acceptedButtons: Qt.MiddleButton
                onClicked: root.toggleDcal()
            }

            Row {
                id: hRow

                spacing: Theme.spacingXS

                DankIcon {
                    name: "calendar_today"
                    size: iconSize
                    color: root.hasEvent ? root.timeColor : Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    id: summaryClip

                    width: root.dynamicWidth ? Math.min(summaryText.implicitWidth, root.pillMaxWidth) : root.pillMaxWidth
                    height: summaryText.implicitHeight
                    clip: true
                    anchors.verticalCenter: parent.verticalCenter

                    property real overflow: Math.max(0, summaryText.implicitWidth - width)

                    StyledText {
                        id: summaryText

                        text: root.hasEvent ? root.eventSummary : "No events"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                    }

                    SequentialAnimation {
                        running: summaryClip.overflow > 0
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) summaryText.x = 0

                        PauseAnimation { duration: 2000 }

                        NumberAnimation {
                            target: summaryText
                            property: "x"
                            to: -summaryClip.overflow
                            duration: summaryClip.overflow * 25
                            easing.type: Easing.Linear
                        }

                        PauseAnimation { duration: 1500 }

                        NumberAnimation {
                            target: summaryText
                            property: "x"
                            to: 0
                            duration: 300
                        }

                    }

                }

                StyledText {
                    text: "•"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: root.timeColor
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.hasEvent
                }

                StyledText {
                    text: root.timeText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: root.timeColor
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.hasEvent
                }

            }

            // Hover shows the full event in the same tooltip (handy when the
            // summary is mid-scroll). A HoverHandler is passive: unlike a
            // MouseArea it doesn't consume the hover, so the bar pill keeps its
            // own highlight + pointing-hand cursor and its popout click.
            HoverHandler {
                enabled: root.showTooltip
                onHoveredChanged: hovered ? root.showEventTooltip(hPill) : root.hideEventTooltip()
            }

        }

    }

    verticalBarPill: Component {
        Item {
            id: vPill

            implicitWidth: vCol.implicitWidth
            implicitHeight: vCol.implicitHeight

            // Middle click on the pill: toggle DankCalendar directly (left
            // opens the popout, right refreshes). Only MiddleButton is
            // accepted, so left/right fall through to BasePill.
            MouseArea {
                anchors.fill: parent
                // Cover BasePill's padding too — middle clicks on the
                // capsule margin were falling through to the bar canvas.
                anchors.margins: -10
                acceptedButtons: Qt.MiddleButton
                onClicked: root.toggleDcal()
            }

            Column {
                id: vCol

                spacing: Theme.spacingXS || 4

                DankIcon {
                    name: "calendar_today"
                    size: iconSize
                    color: root.hasEvent ? root.timeColor : Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // Compact countdown so it fits a narrow vertical bar. The event
                // summary (which scrolls on the horizontal pill) is shown in a
                // hover tooltip instead.
                StyledText {
                    width: root.widgetThickness
                    text: root.timeText
                    font.pixelSize: Math.max(8, Math.round(Theme.fontSizeSmall * 0.7))
                    font.weight: Font.Medium
                    color: root.timeColor
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.hasEvent
                }

            }

            // Hover shows the full event in a custom tooltip beside the bar.
            // HoverHandler is passive so the bar's own click still opens the
            // popout and the pill keeps its highlight + cursor.
            HoverHandler {
                enabled: root.showTooltip
                onHoveredChanged: hovered ? root.showEventTooltip(vPill) : root.hideEventTooltip()
            }

        }

    }

}
