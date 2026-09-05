import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets
import "./store"
import "./components"
import "./components/pills"
import "./components/popout"
import "./components/ai"

PluginComponent {
    id: root

    DankCalendarConstants { id: constantsItem }
    readonly property DankCalendarConstants constants: constantsItem

    // State Stores
    CalendarStore {
        id: calendarStoreItem
        refreshInterval: (pluginData.refreshInterval || 30) * 1000
        lookAheadDays: pluginData.lookAheadDays || 1
        nowWindowMinutes: pluginData.nowWindowMinutes ?? 5
        agendaPastDays: pluginData.agendaPastDays ?? 7
        agendaFutureDays: pluginData.agendaFutureDays || 30
    }

    TaskStore {
        id: taskStoreItem
    }

    ProviderStore {
        id: providerStoreItem
    }

    AiStore {
        id: aiStoreItem
        onProposalConfirmed: {
            calendarStoreItem.refreshAll();
            taskStoreItem.fetchTasks();
        }
    }

    readonly property alias calendarStore: calendarStoreItem
    readonly property alias taskStore: taskStoreItem
    readonly property alias providerStore: providerStoreItem
    // AI & Backend Script Paths
    property string aiScriptPath: Qt.resolvedUrl("./ai-client").toString().replace(/^file:\/\//, "")
    property string batchScriptPath: Qt.resolvedUrl("./batch-create-items").toString().replace(/^file:\/\//, "")
    property string sessionScriptPath: Qt.resolvedUrl("./session-manager").toString().replace(/^file:\/\//, "")
    property string pasteHelperPath: Qt.resolvedUrl("./clipboard-paste-helper").toString().replace(/^file:\/\//, "")
    property string providerScriptPath: Qt.resolvedUrl("./provider-manager").toString().replace(/^file:\/\//, "")

    // Module State Persistence
    PluginGlobalVar {
        id: globalActiveModule
        varName: "dankCalendarActiveModule"
        defaultValue: "agenda"
    }
    readonly property string activeModule: globalActiveModule.value || "agenda"

    PluginGlobalVar {
        id: globalBarModule
        varName: "dankCalendarBarModule"
        defaultValue: "agenda"
    }
    readonly property string barModule: (globalBarModule.value === "tasks") ? "tasks" : "agenda"
    onActiveModuleChanged: root.refreshAll()
    onBarModuleChanged: root.refreshAll()
    property bool isPopoutOpen: false
    signal requestAutoFocus()

    // Popout Dimensions & Actions
    popoutWidth: constants.defaultPopoutWidth
    popoutHeight: constants.defaultPopoutHeight

    pillRightClickAction: () => root.refreshAll()

    function cycleModule() {
        var next = (barModule === "agenda") ? "tasks" : "agenda";
        globalBarModule.set(next);
        globalActiveModule.set(next);
    }

    function switchTabNext(forward = true) {
        var modules = ["agenda", "tasks", "ai"];
        var currIdx = modules.indexOf(root.activeModule);
        if (currIdx === -1) currIdx = 0;
        var nextIdx = forward ? ((currIdx + 1) % modules.length) : ((currIdx - 1 + modules.length) % modules.length);
        var nextMod = modules[nextIdx];
        globalActiveModule.set(nextMod);
        if (nextMod === "agenda" || nextMod === "tasks") {
            globalBarModule.set(nextMod);
        }
        root.requestAutoFocus();
    }

    Timer {
        id: autoRefreshTimer
        interval: 350
        repeat: false
        onTriggered: {
            calendarStoreItem.refreshAll();
            taskStoreItem.fetchTasks();
            taskStoreItem.notifyTasksChanged();
        }
    }

    Timer {
        id: syncFollowupTimer
        interval: 1200
        repeat: false
        onTriggered: {
            calendarStoreItem.refreshAll();
            taskStoreItem.fetchTasks();
            taskStoreItem.notifyTasksChanged();
        }
    }

    function refreshAll() {
        calendarStoreItem.refreshAll();
        taskStoreItem.fetchTasks();
        taskStoreItem.notifyTasksChanged();
        autoRefreshTimer.restart();
    }

    function toggleDcal() {
        Quickshell.execDetached(["dcal", "ipc", "ui.toggle", "view=day"]);
    }

    function newEvent() {
        Quickshell.execDetached(["sh", "-c", "dcal ipc ui.newEvent || exec dcal ipc ui.show view=day"]);
    }

    // Rich Event Tooltip Logic
    function showEventTooltip(pill) {
        if (!(pluginData.showTooltip ?? true) || !pill || !root.parentScreen || !calendarStoreItem.hasEvent)
            return;

        var screen = root.parentScreen;
        var edge = (root.axis && root.axis.edge !== undefined) ? root.axis.edge : (root.isVertical ? "left" : "top");
        var gap = (root.barConfig && root.barConfig.spacing !== undefined ? root.barConfig.spacing : 4) + Theme.spacingXS;
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

        onLoaded: if (pendingShow && item) item.showAt(pendingX, pendingY, pendingScreen, pendingSide)

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
            mask: Region {}

            anchors {
                top: true
                left: true
            }

            margins {
                left: {
                    var sw = (ttip.screen && ttip.screen.width) ? ttip.screen.width : Screen.width;
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
                    var sh = (ttip.screen && ttip.screen.height) ? ttip.screen.height : Screen.height;
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
                color: Theme.withAlpha(Theme.surfaceContainerHigh, (root.barConfig && root.barConfig.transparency !== undefined) ? root.barConfig.transparency : 1)
                radius: Theme.cornerRadius
                border.width: 1
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)

                Column {
                    id: ttCol
                    x: Theme.spacingM
                    y: Theme.spacingS
                    width: Math.round(Theme.fontSizeSmall * 24)
                    spacing: Theme.spacingXS

                    StyledText {
                        width: parent.width
                        text: calendarStoreItem.hasEvent ? calendarStoreItem.eventSummary : "No events"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        width: parent.width
                        visible: calendarStoreItem.hasEvent && !!calendarStoreItem.eventStart
                        text: {
                            if (!calendarStoreItem.hasEvent || !calendarStoreItem.eventStart) return "";
                            var s = calendarStoreItem.eventDate(calendarStoreItem.eventStart, calendarStoreItem.eventAllDay);
                            var day = calendarStoreItem.formatLocalDate(s, "dddd, d MMMM");
                            if (calendarStoreItem.eventAllDay) return day + " · All day";
                            var timeStr = Qt.formatTime(s, "HH:mm");
                            if (calendarStoreItem.eventEnd) {
                                var e = calendarStoreItem.eventDate(calendarStoreItem.eventEnd, false);
                                timeStr += "–" + Qt.formatTime(e, "HH:mm");
                            }
                            return day + " · " + timeStr;
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        width: parent.width
                        visible: calendarStoreItem.hasEvent && !!calendarStoreItem.startsInText
                        text: calendarStoreItem.startsInText
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: calendarStoreItem.timeColor
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingXS
                        visible: calendarStoreItem.hasEvent && (!!calendarStoreItem.eventMeetingUrl || !!calendarStoreItem.eventUrl)

                        DankIcon {
                            name: calendarStoreItem.eventMeetingUrl ? "videocam" : "link"
                            size: 14
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: calendarStoreItem.eventMeetingUrl ? "Meeting link available" : "Event link available"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingXS
                        visible: calendarStoreItem.hasEvent && !!calendarStoreItem.eventLocation

                        DankIcon {
                            name: "location_on"
                            size: 14
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: calendarStoreItem.eventLocation
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        width: parent.width
                        visible: calendarStoreItem.hasEvent && !!calendarStoreItem.eventDescription
                        text: calendarStoreItem.eventDescription
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
    IpcHandler {
        target: "dankCalendarPlus"

        // 1. Popout Control
        function toggle() {
            root.triggerPopout();
        }

        function open() {
            if (!root.isPopoutOpen) {
                root.triggerPopout();
            }
        }

        function close() {
            root.closePopout();
        }

        // 2. Tab Navigation
        function openAgenda() {
            globalActiveModule.set("agenda");
            globalBarModule.set("agenda");
            if (!root.isPopoutOpen) {
                root.triggerPopout();
            }
            root.requestAutoFocus();
        }

        function openTasks() {
            globalActiveModule.set("tasks");
            globalBarModule.set("tasks");
            if (!root.isPopoutOpen) {
                root.triggerPopout();
            }
            root.requestAutoFocus();
        }

        function openAI() {
            globalActiveModule.set("ai");
            if (!root.isPopoutOpen) {
                root.triggerPopout();
            }
            root.requestAutoFocus();
        }

        function toggleAI() {
            if (root.isPopoutOpen && root.activeModule === "ai") {
                root.closePopout();
            } else {
                globalActiveModule.set("ai");
                if (!root.isPopoutOpen) {
                    root.triggerPopout();
                }
                root.requestAutoFocus();
            }
        }

        // 3. Data Refresh
        function refresh() {
            root.refreshAll();
        }
    }

    // Popout Content Area
    popoutContent: Component {
        PopoutComponent {
            id: popout
            property var parentPopout: null
            onParentPopoutChanged: {
                if (parentPopout) {
                    root.isPopoutOpen = Qt.binding(() => parentPopout.shouldBeVisible);
                }
            }

            width: root.popoutWidth
            spacing: Theme.spacingM
            focus: true

            function autoFocusInput() {
                if (!root.isPopoutOpen) return;
                if (root.activeModule === "ai") {
                    if (chatViewComp && chatViewComp.focusInput) {
                        chatViewComp.focusInput();
                    }
                } else if (root.activeModule === "tasks") {
                    if (tasksViewComp && tasksViewComp.focusNewTaskInput) {
                        tasksViewComp.focusNewTaskInput();
                    }
                } else if (root.activeModule === "agenda") {
                    if (agendaViewComp && agendaViewComp.focusAgenda) {
                        agendaViewComp.focusAgenda();
                    }
                }
            }

            Connections {
                target: popout.parentPopout || null
                function onShouldBeVisibleChanged() {
                    if (popout.parentPopout && popout.parentPopout.shouldBeVisible) {
                        autoFocusTimer.restart();
                    }
                }
            }

            Connections {
                target: root
                function onRequestAutoFocus() {
                    autoFocusTimer.restart();
                }
                function onActiveModuleChanged() {
                    if (root.isPopoutOpen) {
                        autoFocusTimer.restart();
                    }
                }
            }

            Timer {
                id: autoFocusTimer
                interval: 80
                repeat: false
                onTriggered: {
                    popout.autoFocusInput();
                }
            }

            Component.onCompleted: {
                root.refreshAll();
                popout.forceActiveFocus();
                autoFocusTimer.restart();
            }

            Keys.onPressed: event => {
                var isCtrl = (event.modifiers & Qt.ControlModifier);
                var isAlt = (event.modifiers & Qt.AltModifier);

                if (isCtrl && (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)) {
                    var forward = (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier));
                    root.switchTabNext(forward);
                    event.accepted = true;
                    return;
                }
                if (isCtrl && event.key === Qt.Key_1) {
                    globalActiveModule.set("agenda");
                    globalBarModule.set("agenda");
                    event.accepted = true;
                    return;
                }
                if (isCtrl && event.key === Qt.Key_2) {
                    globalActiveModule.set("tasks");
                    globalBarModule.set("tasks");
                    event.accepted = true;
                    return;
                }
                if (isCtrl && event.key === Qt.Key_3) {
                    globalActiveModule.set("ai");
                    event.accepted = true;
                    return;
                }
                if (isCtrl && event.key === Qt.Key_R) {
                    root.refreshAll();
                    event.accepted = true;
                    return;
                }
                if (isCtrl && event.key === Qt.Key_N) {
                    globalActiveModule.set("tasks");
                    globalBarModule.set("tasks");
                    Qt.callLater(() => {
                        if (tasksViewComp && tasksViewComp.focusNewTaskInput) {
                            tasksViewComp.focusNewTaskInput();
                        }
                    });
                    event.accepted = true;
                    return;
                }

                // If no modifiers and no active text input is focused
                var activeItem = popout.Window ? popout.Window.activeFocusItem : null;
                var isEditingText = activeItem && (activeItem.hasOwnProperty("cursorPosition") || activeItem.hasOwnProperty("inputMethodHints")) && !activeItem.readOnly;
                if (!isCtrl && !isAlt && !isEditingText) {
                    if (event.key === Qt.Key_1) {
                        globalActiveModule.set("agenda");
                        globalBarModule.set("agenda");
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_2) {
                        globalActiveModule.set("tasks");
                        globalBarModule.set("tasks");
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_3) {
                        globalActiveModule.set("ai");
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_R) {
                        root.refreshAll();
                        event.accepted = true;
                        return;
                    }
                }
            }

            // 1. Popout Top Header
            PopoutHeader {
                calendarStore: root.calendarStore
                taskStore: root.taskStore
                activeModule: root.activeModule
                isRefreshing: root.calendarStore ? root.calendarStore.isLoading : false
                onNewEventRequested: {
                    root.newEvent();
                    if (popout.closePopout) popout.closePopout();
                }
                onRefreshRequested: root.refreshAll()
                onSettingsRequested: {
                    Quickshell.execDetached(["dms", "settings", "dankCalendarPlus"]);
                    if (popout.closePopout) popout.closePopout();
                }
                onCloseRequested: {
                    if (popout.closePopout) popout.closePopout();
                }
                onToggleDcalRequested: {
                    root.toggleDcal();
                    if (popout.closePopout) popout.closePopout();
                }
            }

            // 2. Module Selector Tabs (Agenda / Tasks / AI)
            PopoutTabBar {
                activeModule: root.activeModule
                pendingTasksCount: root.taskStore ? root.taskStore.pendingCount : 0
                onTabSelected: (mod) => {
                    globalActiveModule.set(mod);
                    if (mod === "agenda" || mod === "tasks") {
                        globalBarModule.set(mod);
                    }
                    root.requestAutoFocus();
                }
            }

            // 3. Agenda View
            AgendaView {
                id: agendaViewComp
                visible: root.activeModule === "agenda"
                calendarStore: root.calendarStore
                width: parent.width
                height: visible ? (root.constants ? root.constants.defaultContentHeight : 420) : 0
                onCloseRequested: {
                    if (popout.closePopout) popout.closePopout();
                }
                onSwitchToModule: (mod) => {
                    globalActiveModule.set(mod);
                    if (mod === "agenda" || mod === "tasks") globalBarModule.set(mod);
                    root.requestAutoFocus();
                }
            }

            // 4. Tasks View
            TasksView {
                id: tasksViewComp
                visible: root.activeModule === "tasks"
                taskStore: root.taskStore
                width: parent.width
                height: visible ? (root.constants ? root.constants.defaultContentHeight : 420) : 0
                onCloseRequested: {
                    if (popout.closePopout) popout.closePopout();
                }
                onSwitchToModule: (mod) => {
                    globalActiveModule.set(mod);
                    if (mod === "agenda" || mod === "tasks") globalBarModule.set(mod);
                    root.requestAutoFocus();
                }
            }

            // 5. AI Assistant View
            ChatView {
                id: chatViewComp
                visible: root.activeModule === "ai"
                aiScriptPath: root.aiScriptPath
                batchScriptPath: root.batchScriptPath
                sessionScriptPath: root.sessionScriptPath
                pasteHelperPath: root.pasteHelperPath
                providerScriptPath: root.providerScriptPath
                width: parent.width
                height: visible ? (root.constants ? root.constants.defaultContentHeight : 420) : 0
                onCloseRequested: {
                    if (popout.closePopout) popout.closePopout();
                }
                onSwitchToModule: (mod) => {
                    globalActiveModule.set(mod);
                    if (mod === "agenda" || mod === "tasks") globalBarModule.set(mod);
                    root.requestAutoFocus();
                }
                onScheduleConfirmed: {
                    root.refreshAll()
                    syncFollowupTimer.restart()
                }
            }
        }
    }

    // Horizontal Bar Pill
    horizontalBarPill: Component {
        HorizontalBarPill {
            calendarStore: root.calendarStore
            taskStore: root.taskStore
            barModule: root.barModule
            pillMaxWidth: pluginData.pillMaxWidth || (root.constants ? root.constants.defaultPillMaxWidth : 200)
            dynamicWidth: pluginData.dynamicWidth ?? false
            scrollTitle: pluginData.scrollTitle ?? true
            pillDisplayMode: pluginData.pillDisplayMode || "full"
            iconSize: root.constants ? root.constants.defaultIconSize : 18
            onCycleRequested: root.cycleModule()
            onHoverRequested: (target) => {
                if (pluginData.showTooltip ?? true) root.showEventTooltip(target);
            }
            onHoverEnded: root.hideEventTooltip()
        }
    }

    // Vertical Bar Pill
    verticalBarPill: Component {
        VerticalBarPill {
            calendarStore: root.calendarStore
            taskStore: root.taskStore
            barModule: root.barModule
            widgetThickness: root.widgetThickness
            iconSize: root.constants ? root.constants.defaultIconSize : 18
            onCycleRequested: root.cycleModule()
            onHoverRequested: (target) => {
                if (pluginData.showTooltip ?? true) root.showEventTooltip(target);
            }
            onHoverEnded: root.hideEventTooltip()
        }
    }
}
