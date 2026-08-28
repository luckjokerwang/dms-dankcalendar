import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import "../../store"

Item {
    id: hPill

    property CalendarStore calendarStore: null
    property TaskStore taskStore: null
    property string barModule: "agenda"
    property int pillMaxWidth: 160
    property bool dynamicWidth: false
    property bool scrollTitle: true
    property string pillDisplayMode: "full"
    property int iconSize: 18

    signal cycleRequested()
    signal hoverRequested(var targetItem)
    signal hoverEnded()

    implicitWidth: hRow.implicitWidth
    implicitHeight: hRow.implicitHeight

    // Middle click toggles dcal
    MouseArea {
        anchors.fill: parent
        anchors.margins: -10
        acceptedButtons: Qt.MiddleButton
        onClicked: Quickshell.execDetached(["dcal", "ipc", "ui.toggle", "view=day"])
    }

    Row {
        id: hRow
        spacing: Theme.spacingXS

        Item {
            width: iconSize
            height: iconSize
            anchors.verticalCenter: parent.verticalCenter

            DankIcon {
                id: hIcon
                name: (calendarStore && calendarStore.isLoading) ? "sync" : (barModule === "tasks" ? "task_alt" : "calendar_today")
                size: iconSize
                color: Theme.primary
                anchors.centerIn: parent
                smoothTransform: true
                layer.enabled: true
                transformOrigin: Item.Center

                RotationAnimation {
                    target: hIcon
                    property: "rotation"
                    from: 0
                    to: 360
                    duration: 800
                    loops: Animation.Infinite
                    running: calendarStore ? calendarStore.isLoading : false
                    onRunningChanged: if (!running) hIcon.rotation = 0
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: hPill.cycleRequested()
            }
        }

        // Agenda Mode Display
        Row {
            spacing: Theme.spacingXS
            visible: barModule === "agenda"
            anchors.verticalCenter: parent.verticalCenter

            Item {
                id: summaryClip
                visible: (pillDisplayMode !== "countdownOnly") || !(calendarStore && calendarStore.hasEvent)
                width: dynamicWidth ? Math.min(summaryText.implicitWidth, pillMaxWidth) : pillMaxWidth
                height: summaryText.implicitHeight
                clip: true
                anchors.verticalCenter: parent.verticalCenter
                property real overflow: Math.max(0, summaryText.implicitWidth - width)

                StyledText {
                    id: summaryText
                    width: scrollTitle ? implicitWidth : summaryClip.width
                    text: (calendarStore && calendarStore.hasEvent) ? calendarStore.eventSummary : "No events"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                    elide: scrollTitle ? Text.ElideNone : Text.ElideRight
                }

                SequentialAnimation {
                    running: scrollTitle && summaryClip.overflow > 0 && summaryClip.visible
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) summaryText.x = 0
                    PauseAnimation { duration: 2000 }
                    NumberAnimation { target: summaryText; property: "x"; to: -summaryClip.overflow; duration: summaryClip.overflow * 25; easing.type: Easing.Linear }
                    PauseAnimation { duration: 1500 }
                    NumberAnimation { target: summaryText; property: "x"; to: 0; duration: 300 }
                }
            }

            StyledText {
                text: "•"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: calendarStore ? calendarStore.timeColor : Theme.primary
                anchors.verticalCenter: parent.verticalCenter
                visible: calendarStore && calendarStore.hasEvent && pillDisplayMode === "full"
            }

            StyledText {
                text: calendarStore ? calendarStore.timeText : ""
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: calendarStore ? calendarStore.timeColor : Theme.primary
                anchors.verticalCenter: parent.verticalCenter
                visible: calendarStore && calendarStore.hasEvent && pillDisplayMode !== "titleOnly"
            }
        }

        // Tasks Mode Display
        Row {
            spacing: Theme.spacingXS
            visible: barModule === "tasks"
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: (taskStore && taskStore.pendingTasksCount > 0) ? (taskStore.pendingTasksCount + " 项待办") : "全部完成"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                id: taskSummaryClip
                visible: taskStore && taskStore.pendingTasksCount > 0
                width: dynamicWidth ? Math.min(taskSummaryText.implicitWidth, pillMaxWidth) : pillMaxWidth
                height: taskSummaryText.implicitHeight
                clip: true
                anchors.verticalCenter: parent.verticalCenter
                property real overflow: Math.max(0, taskSummaryText.implicitWidth - width)

                StyledText {
                    id: taskSummaryText
                    width: scrollTitle ? implicitWidth : taskSummaryClip.width
                    text: (taskStore && taskStore.pendingTasks.length > 0 && taskStore.pendingTasks[0].summary) ? ("• " + taskStore.pendingTasks[0].summary) : ""
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                    elide: scrollTitle ? Text.ElideNone : Text.ElideRight
                }

                SequentialAnimation {
                    running: scrollTitle && taskSummaryClip.overflow > 0 && taskSummaryClip.visible
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) taskSummaryText.x = 0
                    PauseAnimation { duration: 2000 }
                    NumberAnimation { target: taskSummaryText; property: "x"; to: -taskSummaryClip.overflow; duration: taskSummaryClip.overflow * 25; easing.type: Easing.Linear }
                    PauseAnimation { duration: 1500 }
                    NumberAnimation { target: taskSummaryText; property: "x"; to: 0; duration: 300 }
                }
            }
        }
    }

    HoverHandler {
        onHoveredChanged: hovered ? hPill.hoverRequested(hPill) : hPill.hoverEnded()
    }
}
