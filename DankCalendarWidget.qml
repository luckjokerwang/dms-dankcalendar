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

    // Popout Dimensions & Actions
    popoutWidth: constants.defaultPopoutWidth
    popoutHeight: constants.defaultPopoutHeight

    pillRightClickAction: () => root.refreshAll()

    function cycleModule() {
        var next = (barModule === "agenda") ? "tasks" : "agenda";
        globalBarModule.set(next);
        globalActiveModule.set(next);
    }

    Timer {
        id: autoRefreshTimer
        interval: 350
        repeat: false
        onTriggered: {
            calendarStoreItem.refreshAll();
            taskStoreItem.fetchTasks();
        }
    }

    function refreshAll() {
        calendarStoreItem.refreshAll();
        taskStoreItem.fetchTasks();
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

    // Centered AI Modal Window
    PluginGlobalVar {
        id: globalAiModalOpen
        varName: "dankCalendarAiModalOpen"
        defaultValue: false
    }

    function toggleAiModal() {
        globalAiModalOpen.set(!globalAiModalOpen.value);
    }

    Loader {
        id: aiModalWindowLoader
        active: globalAiModalOpen.value === true

        sourceComponent: PanelWindow {
            id: aiModalWindow
            WlrLayershell.namespace: "dms:plugins:dankcalendar-ai-modal"
            WlrLayershell.layer: WlrLayershell.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Rectangle {
                anchors.fill: parent
                color: "#80000000"

                MouseArea {
                    anchors.fill: parent
                    onClicked: globalAiModalOpen.set(false)
                }
            }

            StyledRect {
                id: modalContainer
                width: 620
                height: 680
                anchors.centerIn: parent
                color: Theme.surfaceContainerHighest
                radius: Theme.cornerRadiusLarge
                border.width: 1
                border.color: Theme.outlineVariant

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingS

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "smart_toy"
                            size: 22
                            color: Theme.primary
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: "Dank Calendar AI 排程助理"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }

                        StyledRect {
                            implicitWidth: 32
                            implicitHeight: 32
                            radius: 16
                            color: mCloseHover.hovered ? Theme.surfaceContainerHigh : "transparent"

                            DankIcon {
                                anchors.centerIn: parent
                                name: "close"
                                size: 18
                                color: Theme.surfaceVariantText
                            }

                            HoverHandler { id: mCloseHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: globalAiModalOpen.set(false)
                            }
                        }
                    }

                    ChatView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        aiScriptPath: root.aiScriptPath
                        batchScriptPath: root.batchScriptPath
                        sessionScriptPath: root.sessionScriptPath
                        pasteHelperPath: root.pasteHelperPath
                        providerScriptPath: root.providerScriptPath
                        onScheduleConfirmed: root.refreshAll()
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "dankCalendarPlus"

        function toggleAI() {
            root.toggleAiModal();
        }

        function openAI() {
            globalAiModalOpen.set(true);
        }

        function closeAI() {
            globalAiModalOpen.set(false);
        }
    }

    // Popout Content Area
    popoutContent: Component {
        PopoutComponent {
            id: popout
            width: root.popoutWidth
            spacing: Theme.spacingM

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
                }
            }

            // 3. Agenda View
            AgendaView {
                visible: root.activeModule === "agenda"
                calendarStore: root.calendarStore
                width: parent.width
                height: visible ? (root.constants ? root.constants.defaultContentHeight : 420) : 0
                onCloseRequested: {
                    if (popout.closePopout) popout.closePopout();
                }
            }

            // 4. Tasks View
            TasksView {
                visible: root.activeModule === "tasks"
                taskStore: root.taskStore
                width: parent.width
                height: visible ? (root.constants ? root.constants.defaultContentHeight : 420) : 0
            }

            // 5. AI Assistant View
            ChatView {
                visible: root.activeModule === "ai"
                aiScriptPath: root.aiScriptPath
                batchScriptPath: root.batchScriptPath
                sessionScriptPath: root.sessionScriptPath
                pasteHelperPath: root.pasteHelperPath
                providerScriptPath: root.providerScriptPath
                width: parent.width
                height: visible ? (root.constants ? root.constants.defaultContentHeight : 420) : 0
                onScheduleConfirmed: root.refreshAll()
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
