import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Widgets
import "../store"

Item {
    id: tasksView

    property TaskStore taskStore: null
    property var rootWidget: null // Backward compatibility alias
    readonly property TaskStore activeStore: taskStore || (rootWidget ? rootWidget.taskStore : null)

    signal closeRequested()

    readonly property real maxListHeight: 420
    implicitWidth: parent ? parent.width : 420
    implicitHeight: visible ? 420 : 0

    property string filterCalendarId: ""
    property bool showCompleted: false

    readonly property var filteredPendingTasks: {
        var all = (activeStore && activeStore.pendingTasks) ? activeStore.pendingTasks : [];
        if (!filterCalendarId) return all;
        return all.filter(t => t.calendarId === filterCalendarId);
    }

    readonly property var filteredCompletedTasks: {
        var all = (activeStore && activeStore.completedTasks) ? activeStore.completedTasks : [];
        if (!filterCalendarId) return all;
        return all.filter(t => t.calendarId === filterCalendarId);
    }

    DankFlickable {
        id: tasksFlick
        anchors.fill: parent
        anchors.margins: Theme.spacingS
        contentHeight: taskCol.implicitHeight
        clip: true

        Column {
            id: taskCol
            width: tasksFlick.width
            spacing: Theme.spacingM

            // 1. Quick Add Task Input Box
            Rectangle {
                width: parent.width
                height: 42
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.width: taskTextInput.activeFocus ? 2 : 1
                border.color: taskTextInput.activeFocus ? Theme.primary : Theme.outlineMedium

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingM
                    anchors.rightMargin: Theme.spacingS
                    spacing: Theme.spacingS

                    DankIcon {
                        name: "add"
                        size: 20
                        color: taskTextInput.activeFocus ? Theme.primary : Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextInput {
                        id: taskTextInput
                        width: parent.width - 64
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeSmall
                        anchors.verticalCenter: parent.verticalCenter
                        selectByMouse: true

                        Text {
                            text: "添加新待办任务… (可输入 !1, !2, !3 设定优先级)"
                            color: Theme.outlineButton
                            font.pixelSize: Theme.fontSizeSmall
                            visible: !taskTextInput.text && !taskTextInput.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Keys.onReturnPressed: {
                            if (taskTextInput.text.trim()) {
                                if (activeStore)
                                    activeStore.createTask(taskTextInput.text.trim(), tasksView.filterCalendarId);
                                taskTextInput.text = "";
                            }
                        }
                    }

                    Rectangle {
                        visible: taskTextInput.text.trim().length > 0
                        width: 28
                        height: 28
                        radius: 14
                        color: addBtnMouse.containsMouse ? Theme.primaryHover : Theme.primary
                        anchors.verticalCenter: parent.verticalCenter

                        DankIcon {
                            name: "arrow_forward"
                            size: 16
                            color: Theme.primaryText
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: addBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (taskTextInput.text.trim()) {
                                    if (activeStore)
                                        activeStore.createTask(taskTextInput.text.trim(), tasksView.filterCalendarId);
                                    taskTextInput.text = "";
                                }
                            }
                        }
                    }
                }
            }

            // 2. Task Calendar Filter Pills
            Row {
                visible: (activeStore && activeStore.taskCalendars && activeStore.taskCalendars.length > 1)
                width: parent.width
                spacing: Theme.spacingXS

                Rectangle {
                    height: 26
                    width: allCalText.implicitWidth + Theme.spacingM * 2
                    radius: 13
                    color: tasksView.filterCalendarId === "" ? Theme.primary : Theme.surfaceContainerHigh

                    StyledText {
                        id: allCalText
                        anchors.centerIn: parent
                        text: "全部清单"
                        font.pixelSize: Theme.fontSizeSmall - 1
                        font.weight: Font.Medium
                        color: tasksView.filterCalendarId === "" ? Theme.primaryText : Theme.surfaceText
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tasksView.filterCalendarId = ""
                    }
                }

                Repeater {
                    model: (activeStore && activeStore.taskCalendars) ? activeStore.taskCalendars : []

                    delegate: Rectangle {
                        height: 26
                        width: calItemText.implicitWidth + Theme.spacingM * 2
                        radius: 13
                        color: tasksView.filterCalendarId === modelData.id ? Theme.primary : Theme.surfaceContainerHigh

                        StyledText {
                            id: calItemText
                            anchors.centerIn: parent
                            text: modelData.name
                            font.pixelSize: Theme.fontSizeSmall - 1
                            font.weight: Font.Medium
                            color: tasksView.filterCalendarId === modelData.id ? Theme.primaryText : Theme.surfaceText
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tasksView.filterCalendarId = modelData.id
                        }
                    }
                }
            }

            // 3. Pending Tasks Empty State
            Item {
                visible: tasksView.filteredPendingTasks.length === 0
                width: parent.width
                height: 80

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    DankIcon {
                        name: "task_alt"
                        size: 28
                        color: Theme.primary
                        anchors.horizontalCenter: parent.horizontalCenter
                        opacity: 0.8
                    }

                    StyledText {
                        text: "没有待处理的任务 🎉"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            // 4. Pending Tasks List
            Column {
                width: parent.width
                spacing: 2
                visible: tasksView.filteredPendingTasks.length > 0

                Repeater {
                    model: tasksView.filteredPendingTasks

                    delegate: Rectangle {
                        id: pendingRow
                        required property var modelData

                        width: parent.width
                        implicitHeight: Math.max(48, rowContent.implicitHeight + Theme.spacingS * 2)
                        radius: Theme.cornerRadiusSmall
                        color: rowHover.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                        MouseArea {
                            id: rowHover
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        Row {
                            id: rowContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: Theme.spacingS
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            // Complete Checkbox Button
                            Rectangle {
                                width: 28
                                height: 28
                                radius: 14
                                color: checkMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                                anchors.verticalCenter: parent.verticalCenter

                                DankIcon {
                                    name: checkMouse.containsMouse ? "check_circle" : "radio_button_unchecked"
                                    size: 18
                                    color: checkMouse.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    id: checkMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (activeStore)
                                            activeStore.completeTask(pendingRow.modelData.id, true);
                                    }
                                }
                            }

                            // Task Text & Meta Details
                            Column {
                                width: parent.width - 28 - 28 - Theme.spacingS * 2
                                spacing: 2
                                anchors.verticalCenter: parent.verticalCenter

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingXS

                                    // Priority Indicator Badge
                                    Rectangle {
                                        visible: (pendingRow.modelData.priority >= 1 && pendingRow.modelData.priority <= 9)
                                        width: 14
                                        height: 14
                                        radius: 7
                                        color: {
                                            var p = pendingRow.modelData.priority;
                                            if (p === 1) return "#ef5350";
                                            if (p <= 5) return "#ffa726";
                                            return "#42a5f5";
                                        }
                                        anchors.verticalCenter: parent.verticalCenter

                                        StyledText {
                                            anchors.centerIn: parent
                                            text: "!"
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                            color: "#ffffff"
                                        }
                                    }

                                    StyledText {
                                        width: parent.width - 20
                                        text: pendingRow.modelData.summary || ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                        wrapMode: Text.Wrap
                                    }
                                }

                                // Calendar Name Tag / Due date
                                Row {
                                    spacing: Theme.spacingS
                                    StyledText {
                                        text: pendingRow.modelData.calendarName || "Tasks"
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        color: Theme.surfaceVariantText
                                    }
                                    StyledText {
                                        visible: !!pendingRow.modelData.due
                                        text: "📅 " + (pendingRow.modelData.due || "")
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        color: Theme.primary
                                    }
                                }
                            }

                            // Delete Task Button (Visible on Hover)
                            Rectangle {
                                visible: rowHover.hovered || delMouse.containsMouse
                                width: 28
                                height: 28
                                radius: 14
                                color: delMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                                anchors.verticalCenter: parent.verticalCenter

                                DankIcon {
                                    name: "delete"
                                    size: 16
                                    color: delMouse.containsMouse ? Theme.error : Theme.surfaceVariantText
                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    id: delMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (activeStore)
                                            activeStore.deleteTask(pendingRow.modelData.id);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 5. Completed Tasks Section
            Column {
                width: parent.width
                spacing: Theme.spacingXS
                visible: tasksView.filteredCompletedTasks.length > 0

                // Header Toggle Button
                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadiusSmall
                    color: compHeaderMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingS
                        anchors.rightMargin: Theme.spacingS
                        spacing: Theme.spacingS

                        DankIcon {
                            name: tasksView.showCompleted ? "expand_more" : "chevron_right"
                            size: 16
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "已完成 (" + tasksView.filteredCompletedTasks.length + ")"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: compHeaderMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tasksView.showCompleted = !tasksView.showCompleted
                    }
                }

                // Completed Task Items List
                Column {
                    width: parent.width
                    spacing: 2
                    visible: tasksView.showCompleted

                    Repeater {
                        model: tasksView.filteredCompletedTasks

                        delegate: Rectangle {
                            id: completedRow
                            required property var modelData

                            width: parent.width
                            implicitHeight: Math.max(40, compContent.implicitHeight + Theme.spacingXS * 2)
                            radius: Theme.cornerRadiusSmall
                            color: compRowHover.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                            opacity: 0.7

                            MouseArea {
                                id: compRowHover
                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            Row {
                                id: compContent
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: Theme.spacingS
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingS

                                // Uncomplete Checkbox Button
                                Rectangle {
                                    width: 24
                                    height: 24
                                    radius: 12
                                    color: "transparent"
                                    anchors.verticalCenter: parent.verticalCenter

                                    DankIcon {
                                        name: "check_circle"
                                        size: 16
                                        color: uncheckMouse.containsMouse ? Theme.surfaceVariantText : Theme.primary
                                        anchors.centerIn: parent
                                    }

                                    MouseArea {
                                        id: uncheckMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (activeStore)
                                                activeStore.completeTask(completedRow.modelData.id, false);
                                        }
                                    }
                                }

                                StyledText {
                                    width: parent.width - 24 - 24 - Theme.spacingS * 2
                                    text: completedRow.modelData.summary || ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.strikeout: true
                                    color: Theme.surfaceVariantText
                                    wrapMode: Text.Wrap
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                // Delete Completed Task (Visible on Hover)
                                Rectangle {
                                    visible: compRowHover.containsMouse || delCompMouse.containsMouse
                                    width: 24
                                    height: 24
                                    radius: 12
                                    color: delCompMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                                    anchors.verticalCenter: parent.verticalCenter

                                    DankIcon {
                                        name: "delete"
                                        size: 14
                                        color: delCompMouse.containsMouse ? Theme.error : Theme.surfaceVariantText
                                        anchors.centerIn: parent
                                    }

                                    MouseArea {
                                        id: delCompMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (activeStore)
                                                activeStore.deleteTask(completedRow.modelData.id);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
