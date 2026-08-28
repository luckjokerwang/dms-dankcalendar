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
    readonly property alias aiStore: aiStoreItem

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
        calendarStoreItem.refreshAll();
        taskStoreItem.fetchTasks();
    }

    function toggleDcal() {
        Quickshell.execDetached(["dcal", "ipc", "ui.toggle", "view=day"]);
    }

    function newEvent() {
        Quickshell.execDetached(["sh", "-c", "dcal ipc ui.newEvent || exec dcal ipc ui.show view=day"]);
    }

    function showEventTooltip(targetItem) {
        if (!calendarStoreItem.hasEvent) return;
        var s = calendarStoreItem.eventDate(calendarStoreItem.eventStart, calendarStoreItem.eventAllDay);
        var day = calendarStoreItem.formatLocalDate(s, "dddd d MMMM");
        var time = calendarStoreItem.eventAllDay ? "All day" : (Qt.formatTime(s, "HH:mm") + (calendarStoreItem.eventEnd ? "–" + Qt.formatTime(calendarStoreItem.eventDate(calendarStoreItem.eventEnd, false), "HH:mm") : ""));
        var tooltipText = calendarStoreItem.eventSummary + "\n" + day + " · " + time;
        if (calendarStoreItem.eventLocation) tooltipText += "\n📍 " + calendarStoreItem.eventLocation;
        TooltipService.show(targetItem, tooltipText);
    }

    function hideEventTooltip() {
        TooltipService.hide();
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

            // 2. Tab Switcher
            PopoutTabBar {
                activeModule: root.activeModule
                pendingTasksCount: root.taskStore ? root.taskStore.pendingTasksCount : 0
                onTabSelected: (mod) => {
                    globalActiveModule.set(mod);
                    if (mod === "agenda" || mod === "tasks") {
                        globalBarModule.set(mod);
                    }
                }
            }

            // 3. Error Banner (if any)
            Rectangle {
                visible: root.calendarStore ? root.calendarStore.hasSyncError : false
                width: parent.width - Theme.spacingS * 2
                anchors.horizontalCenter: parent.horizontalCenter
                height: visible ? 32 : 0
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
                        text: root.calendarStore ? root.calendarStore.syncErrorMessage : "同步失败"
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
                calendarStore: root.calendarStore
                width: parent.width
                height: visible ? (root.constants ? root.constants.defaultContentHeight : 420) : 0
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
                taskStore: root.taskStore
                width: parent.width
                height: visible ? (root.constants ? root.constants.defaultContentHeight : 420) : 0
                onCloseRequested: {
                    if (popout.closePopout) popout.closePopout();
                }
            }

            ChatView {
                id: chatViewItem
                visible: root.activeModule === "ai"
                aiStore: root.aiStore
                providerStore: root.providerStore
                batchScriptPath: root.constants ? root.constants.coreScriptPath : ""
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
