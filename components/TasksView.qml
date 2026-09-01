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
    property string filterTag: ""
    property bool showCompleted: false

    readonly property int uncategorizedCount: {
        var all = (activeStore && activeStore.pendingTasks) ? activeStore.pendingTasks : [];
        var count = 0;
        for (var i = 0; i < all.length; i++) {
            var tags = all[i].tags || [];
            if (tags.length === 0) count++;
        }
        return count;
    }

    readonly property var filteredPendingTasks: {
        var all = (activeStore && activeStore.pendingTasks) ? activeStore.pendingTasks : [];
        if (filterCalendarId) {
            all = all.filter(t => t.calendarId === filterCalendarId);
        }
        if (filterTag) {
            all = all.filter(t => {
                var tags = t.tags || [];
                for (var i = 0; i < tags.length; i++) {
                    if (tags[i].name === filterTag) return true;
                }
                return false;
            });
        }
        return all;
    }

    readonly property var filteredCompletedTasks: {
        var all = (activeStore && activeStore.completedTasks) ? activeStore.completedTasks : [];
        if (filterCalendarId) {
            all = all.filter(t => t.calendarId === filterCalendarId);
        }
        if (filterTag) {
            all = all.filter(t => {
                var tags = t.tags || [];
                for (var i = 0; i < tags.length; i++) {
                    if (tags[i].name === filterTag) return true;
                }
                return false;
            });
        }
        return all;
    }

    function checkFilterTagValidity() {
        if (!filterTag) return;
        var tags = (activeStore && activeStore.allTags) ? activeStore.allTags : [];
        var found = false;
        for (var i = 0; i < tags.length; i++) {
            if (tags[i].name === filterTag) {
                found = true;
                break;
            }
        }
        if (!found) filterTag = "";
    }

    Connections {
        target: activeStore
        function onAllTagsChanged() {
            tasksView.checkFilterTagValidity();
        }
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

            // 1. Quick Add Task Input Box using DMS standard DankTextField
            DankTextField {
                id: taskTextInput
                width: parent.width
                height: 42
                leftIconName: "add"
                leftIconSize: 20
                placeholderText: "添加新待办… (支持 !1 优先级, #标签 分类)"
                font.pixelSize: Theme.fontSizeMedium
                topPadding: 9
                bottomPadding: 7
                rightAccessoryWidth: text.trim().length > 0 ? 36 : 0

                onAccepted: {
                    if (text.trim()) {
                        if (activeStore)
                            activeStore.createTask(text.trim(), tasksView.filterCalendarId);
                        text = "";
                    }
                }

                Rectangle {
                    visible: taskTextInput.text.trim().length > 0
                    width: 28
                    height: 28
                    radius: 14
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    color: addBtnMouse.containsMouse ? Theme.primaryHover : Theme.primary

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

            // 1.5 Smart Auto-Classify Trigger Banner
            Rectangle {
                visible: tasksView.uncategorizedCount > 0
                width: parent.width
                height: 34
                radius: 17
                color: Theme.withAlpha(Theme.primary, 0.12)
                border.width: 1
                border.color: Theme.withAlpha(Theme.primary, 0.3)

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Theme.spacingS

                    DankIcon {
                        name: (activeStore && activeStore.isClassifyingBatch) ? "sync" : "auto_awesome"
                        size: 15
                        color: Theme.primary
                    }

                    StyledText {
                        text: (activeStore && activeStore.isClassifyingBatch)
                              ? "正在利用 AI 智能整理待办分类…"
                              : ("✨ 一键智能整理分类 (" + tasksView.uncategorizedCount + " 项未分类待办)")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.primary
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: !(activeStore && activeStore.isClassifyingBatch)
                    onClicked: {
                        if (activeStore)
                            activeStore.autoClassifyUncategorizedTasks();
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

            // 3. Category #Tag Filter Tab Pills (Only active tags with tasks)
            Flow {
                visible: (activeStore && activeStore.allTags && activeStore.allTags.length > 0)
                width: parent.width
                spacing: 6

                // "全部" Pill
                Rectangle {
                    id: allTagPill
                    height: 24
                    implicitWidth: allTagText.implicitWidth + 16
                    radius: 12
                    color: tasksView.filterTag === "" ? Theme.primary : Theme.surfaceContainerHigh
                    border.width: 1
                    border.color: tasksView.filterTag === "" ? Theme.primary : Theme.outlineVariant

                    StyledText {
                        id: allTagText
                        anchors.centerIn: parent
                        text: "全部待办"
                        font.pixelSize: 11
                        font.weight: tasksView.filterTag === "" ? Font.Bold : Font.Normal
                        color: tasksView.filterTag === "" ? "#ffffff" : Theme.surfaceText
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tasksView.filterTag = ""
                    }
                }

                // Dynamic Tag Pills
                Repeater {
                    model: (activeStore && activeStore.allTags) ? activeStore.allTags : []
                    delegate: Rectangle {
                        id: tagPill
                        required property var modelData
                        readonly property bool isSelected: tasksView.filterTag === modelData.name
                        readonly property string tagColor: modelData.color || Theme.primary

                        height: 24
                        implicitWidth: tagPillRow.implicitWidth + 14
                        radius: 12
                        color: isSelected ? tagColor : Theme.withAlpha(tagColor, 0.12)
                        border.width: 1
                        border.color: isSelected ? tagColor : Theme.withAlpha(tagColor, 0.4)

                        RowLayout {
                            id: tagPillRow
                            anchors.centerIn: parent
                            spacing: 3

                            DankIcon {
                                name: modelData.icon || "label"
                                size: 12
                                color: isSelected ? "#ffffff" : tagPill.tagColor
                            }

                            StyledText {
                                text: "#" + modelData.name + (modelData.count && modelData.count > 0 ? (" (" + modelData.count + ")") : "")
                                font.pixelSize: 11
                                font.weight: isSelected ? Font.Bold : Font.Normal
                                color: isSelected ? "#ffffff" : Theme.surfaceText
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (tasksView.filterTag === modelData.name) {
                                    tasksView.filterTag = "";
                                } else {
                                    tasksView.filterTag = modelData.name;
                                }
                            }
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
                        color: rowHover.hovered ? Theme.surfaceContainerHigh : "transparent"

                        HoverHandler {
                            id: rowHover
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
                                        text: pendingRow.modelData.cleanSummary || pendingRow.modelData.summary || ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                        wrapMode: Text.Wrap
                                    }
                                }

                                // Meta Row: Calendar Name, Due Date, and Category Tag Badges
                                Flow {
                                    width: parent.width
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

                                    Repeater {
                                        model: pendingRow.modelData.tags || []
                                        delegate: Rectangle {
                                            required property var modelData
                                            readonly property string bColor: modelData.color || Theme.primary

                                            implicitWidth: tagBadgeRow.implicitWidth + 8
                                            implicitHeight: 16
                                            radius: 8
                                            color: Theme.withAlpha(bColor, 0.15)
                                            border.width: 1
                                            border.color: Theme.withAlpha(bColor, 0.35)

                                            RowLayout {
                                                id: tagBadgeRow
                                                anchors.centerIn: parent
                                                spacing: 2

                                                DankIcon {
                                                    name: modelData.icon || "label"
                                                    size: 9
                                                    color: bColor
                                                }

                                                StyledText {
                                                    text: modelData.name
                                                    font.pixelSize: 9
                                                    font.weight: Font.Bold
                                                    color: bColor
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    tasksView.filterTag = modelData.name;
                                                }
                                            }
                                        }
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
                            color: compRowHover.hovered ? Theme.surfaceContainerHigh : "transparent"
                            opacity: 0.7

                            HoverHandler {
                                id: compRowHover
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

                                Column {
                                    width: parent.width - 24 - 24 - Theme.spacingS * 2
                                    spacing: 2
                                    anchors.verticalCenter: parent.verticalCenter

                                    StyledText {
                                        width: parent.width
                                        text: completedRow.modelData.cleanSummary || completedRow.modelData.summary || ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.strikeout: true
                                        color: Theme.surfaceVariantText
                                        wrapMode: Text.Wrap
                                    }

                                    // Category Tag Badges
                                    Flow {
                                        visible: (completedRow.modelData.tags && completedRow.modelData.tags.length > 0)
                                        width: parent.width
                                        spacing: 4

                                        Repeater {
                                            model: completedRow.modelData.tags || []
                                            delegate: Rectangle {
                                                required property var modelData
                                                readonly property string bColor: modelData.color || Theme.primary

                                                implicitWidth: cTagBadgeRow.implicitWidth + 8
                                                implicitHeight: 14
                                                radius: 7
                                                color: Theme.withAlpha(bColor, 0.1)
                                                border.width: 1
                                                border.color: Theme.withAlpha(bColor, 0.25)

                                                RowLayout {
                                                    id: cTagBadgeRow
                                                    anchors.centerIn: parent
                                                    spacing: 2

                                                    DankIcon {
                                                        name: modelData.icon || "label"
                                                        size: 8
                                                        color: bColor
                                                    }

                                                    StyledText {
                                                        text: modelData.name
                                                        font.pixelSize: 8
                                                        font.weight: Font.Bold
                                                        color: bColor
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Delete Completed Task (Visible on Hover)
                                Rectangle {
                                    visible: compRowHover.hovered || delCompMouse.containsMouse
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
