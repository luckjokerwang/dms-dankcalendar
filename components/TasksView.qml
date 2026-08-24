import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Widgets

Item {
    id: tasksView

    property var rootWidget: null
    signal closeRequested

    readonly property real maxListHeight: 420
    implicitWidth: parent ? parent.width : 420
    implicitHeight: visible ? 420 : 0

    property string filterCalendarId: ""
    property bool showCompleted: false

    readonly property var filteredPendingTasks: {
        var all = (rootWidget && rootWidget.pendingTasks) ? rootWidget.pendingTasks : [];
        if (!filterCalendarId)
            return all;
        return all.filter(t => t.calendarId === filterCalendarId);
    }

    readonly property var filteredCompletedTasks: {
        var all = (rootWidget && rootWidget.completedTasks) ? rootWidget.completedTasks : [];
        if (!filterCalendarId)
            return all;
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
                            text: "添加新待办任务…"
                            color: Theme.outlineButton
                            font.pixelSize: Theme.fontSizeSmall
                            visible: !taskTextInput.text && !taskTextInput.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Keys.onReturnPressed: {
                            if (taskTextInput.text.trim()) {
                                if (rootWidget)
                                    rootWidget.createTask(taskTextInput.text.trim(), tasksView.filterCalendarId);
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
                                    if (rootWidget)
                                        rootWidget.createTask(taskTextInput.text.trim(), tasksView.filterCalendarId);
                                    taskTextInput.text = "";
                                }
                            }
                        }
                    }
                }
            }

            // 2. Task Calendar Filter Pills (if multiple task lists exist)
            Row {
                visible: (rootWidget.taskCalendars || []).length > 1
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
                    model: rootWidget.taskCalendars || []

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
                                    size: 20
                                    color: checkMouse.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    id: checkMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (rootWidget)
                                            rootWidget.completeTask(pendingRow.modelData.id, true);
                                    }
                                }
                            }

                            // Task Text & Meta
                            Column {
                                width: parent.width - 28 - 32 - Theme.spacingS * 2
                                spacing: 2
                                anchors.verticalCenter: parent.verticalCenter

                                StyledText {
                                    width: parent.width
                                    text: pendingRow.modelData.summary || "(无标题)"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    wrapMode: Text.WrapAnywhere
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                }

                                Row {
                                    spacing: Theme.spacingXS
                                    visible: Boolean(pendingRow.modelData.priority && pendingRow.modelData.priority > 0) || Boolean(pendingRow.modelData.due) || Boolean(pendingRow.modelData.calendarName)

                                    // Priority Badge
                                    Rectangle {
                                        visible: Boolean(pendingRow.modelData.priority && pendingRow.modelData.priority > 0)
                                        height: 18
                                        width: prioText.implicitWidth + 8
                                        radius: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: {
                                            var p = pendingRow.modelData.priority || 0;
                                            if (p >= 1 && p <= 4) return Theme.withAlpha(Theme.error, 0.2);
                                            if (p === 5) return Theme.withAlpha("#f59e0b", 0.2);
                                            return Theme.withAlpha(Theme.primary, 0.2);
                                        }

                                        StyledText {
                                            id: prioText
                                            anchors.centerIn: parent
                                            text: {
                                                var p = pendingRow.modelData.priority || 0;
                                                if (p >= 1 && p <= 4) return "高优";
                                                if (p === 5) return "中优";
                                                return "低优";
                                            }
                                            font.pixelSize: Theme.fontSizeSmall - 3
                                            font.weight: Font.Bold
                                            color: {
                                                var p = pendingRow.modelData.priority || 0;
                                                if (p >= 1 && p <= 4) return Theme.error;
                                                if (p === 5) return "#f59e0b";
                                                return Theme.primary;
                                            }
                                        }
                                    }

                                    StyledText {
                                        visible: Boolean(pendingRow.modelData.due)
                                        text: {
                                            if (!pendingRow.modelData.due) return "";
                                            var d = new Date(pendingRow.modelData.due);
                                            return "截止: " + Qt.formatDate(d, "M月d日");
                                        }
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        color: Theme.primary
                                    }

                                    StyledText {
                                        visible: Boolean(pendingRow.modelData.calendarName)
                                        text: ((Boolean(pendingRow.modelData.priority && pendingRow.modelData.priority > 0) || Boolean(pendingRow.modelData.due)) ? "·  " : "") + pendingRow.modelData.calendarName
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        color: Theme.surfaceVariantText
                                    }
                                }
                            }

                            // Delete Action Button
                            Rectangle {
                                width: 28
                                height: 28
                                radius: 14
                                color: delTaskMouse.containsMouse ? Theme.withAlpha(Theme.error, 0.15) : "transparent"
                                visible: rowHover.containsMouse
                                anchors.verticalCenter: parent.verticalCenter

                                DankIcon {
                                    name: "delete"
                                    size: 16
                                    color: delTaskMouse.containsMouse ? Theme.error : Theme.surfaceVariantText
                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    id: delTaskMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (rootWidget)
                                            rootWidget.deleteTask(pendingRow.modelData.id);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 5. Completed Tasks Collapsible Section
            Column {
                width: parent.width
                spacing: Theme.spacingS
                visible: tasksView.filteredCompletedTasks.length > 0

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadiusSmall
                    color: compHeaderMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        DankIcon {
                            name: tasksView.showCompleted ? "expand_more" : "chevron_right"
                            size: 18
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

                // Completed tasks list
                Column {
                    visible: tasksView.showCompleted
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: tasksView.filteredCompletedTasks

                        delegate: Rectangle {
                            id: compRow
                            required property var modelData

                            width: parent.width
                            implicitHeight: Math.max(40, compRowContent.implicitHeight + Theme.spacingS * 2)
                            radius: Theme.cornerRadiusSmall
                            color: compRowHover.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                            MouseArea {
                                id: compRowHover
                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            Row {
                                id: compRowContent
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: Theme.spacingS
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingS

                                // Uncomplete Checkbox
                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: uncheckMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                                    anchors.verticalCenter: parent.verticalCenter

                                    DankIcon {
                                        name: "check_circle"
                                        size: 20
                                        color: Theme.primary
                                        anchors.centerIn: parent
                                    }

                                    MouseArea {
                                        id: uncheckMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (rootWidget)
                                                rootWidget.completeTask(compRow.modelData.id, false);
                                        }
                                    }
                                }

                                // Task Text (Dimmed)
                                Column {
                                    width: parent.width - 28 - 32 - Theme.spacingS * 2
                                    spacing: 1
                                    anchors.verticalCenter: parent.verticalCenter

                                    StyledText {
                                        width: parent.width
                                        text: compRow.modelData.summary || "(无标题)"
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.strikeout: true
                                        color: Theme.surfaceVariantText
                                        wrapMode: Text.WrapAnywhere
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                    }
                                }

                                // Delete Action
                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: delCompMouse.containsMouse ? Theme.withAlpha(Theme.error, 0.15) : "transparent"
                                    visible: compRowHover.containsMouse
                                    anchors.verticalCenter: parent.verticalCenter

                                    DankIcon {
                                        name: "delete"
                                        size: 16
                                        color: delCompMouse.containsMouse ? Theme.error : Theme.surfaceVariantText
                                        anchors.centerIn: parent
                                    }

                                    MouseArea {
                                        id: delCompMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (rootWidget)
                                                rootWidget.deleteTask(compRow.modelData.id);
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
