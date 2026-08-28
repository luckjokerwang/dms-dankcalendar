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

    DankCalendarConstants { id: constants }

    // State Stores
    CalendarStore {
        id: calendarStore
        refreshInterval: (pluginData.refreshInterval || 30) * 1000
        lookAheadDays: pluginData.lookAheadDays || 1
        nowWindowMinutes: pluginData.nowWindowMinutes ?? 5
        agendaPastDays: pluginData.agendaPastDays ?? 7
        agendaFutureDays: pluginData.agendaFutureDays || 30
    }

    TaskStore {
        id: taskStore
    }

    ProviderStore {
        id: providerStore
    }

    AiStore {
        id: aiStore
        onProposalConfirmed: {
            calendarStore.refreshAll();
            taskStore.fetchTasks();
        }
    }

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

    function refreshAll() {
        calendarStore.refreshAll();
        taskStore.fetchTasks();
    }

    function toggleDcal() {
        Quickshell.execDetached(["dcal", "ipc", "ui.toggle", "view=day"]);
    }

    function newEvent() {
        Quickshell.execDetached(["sh", "-c", "dcal ipc ui.newEvent || exec dcal ipc ui.show view=day"]);
    }

    function showEventTooltip(targetItem) {
        if (!calendarStore.hasEvent) return;
        var s = calendarStore.eventDate(calendarStore.eventStart, calendarStore.eventAllDay);
        var day = calendarStore.formatLocalDate(s, "dddd d MMMM");
        var time = calendarStore.eventAllDay ? "All day" : (Qt.formatTime(s, "HH:mm") + (calendarStore.eventEnd ? "–" + Qt.formatTime(calendarStore.eventDate(calendarStore.eventEnd, false), "HH:mm") : ""));
        var tooltipText = calendarStore.eventSummary + "\n" + day + " · " + time;
        if (calendarStore.eventLocation) tooltipText += "\n📍 " + calendarStore.eventLocation;
        TooltipService.show(targetItem, tooltipText);
    }

    function hideEventTooltip() {
        TooltipService.hide();
    }

    // Popout Content Area
    popoutContent: Component {
        Item {
            id: popout

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                // 1. Popout Top Header
                PopoutHeader {
                    calendarStore: calendarStore
                    taskStore: taskStore
                    activeModule: root.activeModule
                    isRefreshing: calendarStore.isLoading
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

                // 2. Tab Switcher
                PopoutTabBar {
                    activeModule: root.activeModule
                    pendingTasksCount: taskStore.pendingTasksCount
                    onTabSelected: (mod) => {
                        globalActiveModule.set(mod);
                        if (mod === "agenda" || mod === "tasks") {
                            globalBarModule.set(mod);
                        }
                    }
                }

                // 3. Error Banner (if any)
                Rectangle {
                    visible: calendarStore.hasSyncError
                    width: parent.width - Theme.spacingS * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 32
                    radius: Theme.cornerRadiusSmall
                    color: Theme.withAlpha(Theme.error, 0.15)
                    border.width: 1
                    border.color: Theme.withAlpha(Theme.error, 0.4)

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingS
                        anchors.rightMargin: Theme.spacingS
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "error_outline"
                            size: 16
                            color: Theme.error
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            width: parent.width - 60
                            text: calendarStore.syncErrorMessage || "同步失败"
                            font.pixelSize: Theme.fontSizeSmall - 1
                            color: Theme.error
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "重试"
                            font.pixelSize: Theme.fontSizeSmall - 1
                            font.weight: Font.Bold
                            color: Theme.error
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.refreshAll()
                            }
                        }
                    }
                }

                // 4. View Module Containers
                AgendaView {
                    id: agendaViewItem
                    visible: root.activeModule === "agenda"
                    calendarStore: calendarStore
                    width: parent.width
                    height: constants.defaultContentHeight
                    onCloseRequested: {
                        if (popout.closePopout) popout.closePopout();
                    }
                    Connections {
                        target: popout.parentPopout
                        function onOpened() { agendaViewItem.resetToToday(); }
                    }
                }

                TasksView {
                    id: tasksViewItem
                    visible: root.activeModule === "tasks"
                    taskStore: taskStore
                    width: parent.width
                    height: constants.defaultContentHeight
                    onCloseRequested: {
                        if (popout.closePopout) popout.closePopout();
                    }
                }

                ChatView {
                    id: chatViewItem
                    visible: root.activeModule === "ai"
                    aiStore: aiStore
                    providerStore: providerStore
                    batchScriptPath: constants.coreScriptPath
                    width: parent.width
                    height: constants.defaultContentHeight
                    onScheduleConfirmed: root.refreshAll()
                }
            }
        }
    }

    // Horizontal Bar Pill
    horizontalBarPill: Component {
        HorizontalBarPill {
            calendarStore: calendarStore
            taskStore: taskStore
            barModule: root.barModule
            pillMaxWidth: pluginData.pillMaxWidth || constants.defaultPillMaxWidth
            dynamicWidth: pluginData.dynamicWidth ?? false
            scrollTitle: pluginData.scrollTitle ?? true
            pillDisplayMode: pluginData.pillDisplayMode || "full"
            iconSize: constants.defaultIconSize
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
            calendarStore: calendarStore
            taskStore: taskStore
            barModule: root.barModule
            widgetThickness: root.widgetThickness
            iconSize: constants.defaultIconSize
            onCycleRequested: root.cycleModule()
            onHoverRequested: (target) => {
                if (pluginData.showTooltip ?? true) root.showEventTooltip(target);
            }
            onHoverEnded: root.hideEventTooltip()
        }
    }
}
