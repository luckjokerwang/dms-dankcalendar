import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import "../store"

Item {
    id: agendaView

    property CalendarStore calendarStore: null
    property var rootWidget: null // Backward compatibility alias
    readonly property CalendarStore activeStore: calendarStore || (rootWidget ? rootWidget.calendarStore : null)

    signal closeRequested()
    signal switchToModule(string moduleName)

    focus: true
    property int selectedIndex: -1

    function copyToClipboard(txt) {
        if (!txt) return;
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy 2>/dev/null || printf '%s' \"$1\" | xclip -selection clipboard 2>/dev/null", "sh", txt]);
        try {
            ToastService.showInfo("已复制日程到剪贴板");
        } catch (e) {
            console.log("[AgendaView] Copied to clipboard:", txt);
        }
    }

    implicitWidth: parent ? parent.width : 420
    implicitHeight: visible ? 420 : 0

    function focusAgenda() {
        agendaView.forceActiveFocus();
        if (selectedIndex === -1) {
            selectNextEvent();
        }
    }

    onVisibleChanged: {
        if (visible) {
            Qt.callLater(() => focusAgenda());
        }
    }

    function getEventIndices() {
        var model = activeStore ? activeStore.agendaModel : [];
        var indices = [];
        for (var i = 0; i < model.length; i++) {
            if (model[i] && model[i].kind === "event") {
                indices.push(i);
            }
        }
        return indices;
    }

    function selectNextEvent() {
        var indices = getEventIndices();
        if (indices.length === 0) return;
        if (agendaView.selectedIndex === -1) {
            agendaView.selectedIndex = indices[0];
            return;
        }
        for (var i = 0; i < indices.length; i++) {
            if (indices[i] > agendaView.selectedIndex) {
                agendaView.selectedIndex = indices[i];
                return;
            }
        }
    }

    function selectPrevEvent() {
        var indices = getEventIndices();
        if (indices.length === 0) return;
        if (agendaView.selectedIndex === -1) {
            agendaView.selectedIndex = indices[indices.length - 1];
            return;
        }
        for (var i = indices.length - 1; i >= 0; i--) {
            if (indices[i] < agendaView.selectedIndex) {
                agendaView.selectedIndex = indices[i];
                return;
            }
        }
    }

    function openCurrentEvent() {
        var model = activeStore ? activeStore.agendaModel : [];
        if (agendaView.selectedIndex >= 0 && agendaView.selectedIndex < model.length) {
            var item = model[agendaView.selectedIndex];
            if (item && item.kind === "event" && item.ev) {
                Quickshell.execDetached(["dcal", "ipc", "ui.openEvent", "uid=" + item.ev.uid, "start=" + item.ev.start]);
                agendaView.closeRequested();
            }
        }
    }

    function copyCurrentEvent() {
        var model = activeStore ? activeStore.agendaModel : [];
        if (agendaView.selectedIndex >= 0 && agendaView.selectedIndex < model.length) {
            var item = model[agendaView.selectedIndex];
            if (item && item.kind === "event" && item.ev) {
                var ev = item.ev;
                var details = (ev.cleanSummary || ev.summary || "");
                if (activeStore) {
                    var timeStr = activeStore.eventTimeLabel(ev);
                    if (timeStr) details += " (" + timeStr + ")";
                }
                if (ev.location) details += " @" + ev.location;
                agendaView.copyToClipboard(details);
            }
        }
    }

    function deleteCurrentEvent() {
        var model = activeStore ? activeStore.agendaModel : [];
        if (agendaView.selectedIndex >= 0 && agendaView.selectedIndex < model.length) {
            var item = model[agendaView.selectedIndex];
            if (item && item.kind === "event" && item.ev && activeStore) {
                activeStore.deleteEvent(item.ev);
            }
        }
    }

    Keys.onPressed: (event) => {
        var isCtrl = (event.modifiers & Qt.ControlModifier);
        if (isCtrl) {
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                var forward = (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier));
                agendaView.switchToModule(forward ? "tasks" : "ai");
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_1) {
                agendaView.switchToModule("agenda");
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_2) {
                agendaView.switchToModule("tasks");
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_3) {
                agendaView.switchToModule("ai");
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_R) {
                if (activeStore) activeStore.refreshAll();
                event.accepted = true;
                return;
            }
        }

        if (event.key === Qt.Key_Escape) {
            agendaView.closeRequested();
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_1) {
            agendaView.switchToModule("agenda");
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_2) {
            agendaView.switchToModule("tasks");
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_3) {
            agendaView.switchToModule("ai");
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
            selectNextEvent();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
            selectPrevEvent();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_O) {
            openCurrentEvent();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_C || event.key === Qt.Key_Y) {
            copyCurrentEvent();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_D || event.key === Qt.Key_Delete) {
            deleteCurrentEvent();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_R) {
            if (activeStore) activeStore.refreshAll();
            event.accepted = true;
            return;
        }
    }

    function resetToToday() {
        if (agendaFlick) {
            agendaFlick.resetToToday();
        }
    }

    DankFlickable {
        id: agendaFlick
        anchors.fill: parent
        anchors.margins: Theme.spacingS
        contentHeight: eventColumn.implicitHeight
        clip: true

        property bool userScrolled: false
        readonly property real todayY: Math.max(0, Math.min(activeStore ? activeStore.agendaTodayOffset : 0, contentHeight - height))

        function pinToToday() {
            if (!userScrolled) contentY = todayY;
        }

        function resetToToday() {
            userScrolled = false;
            todayJumpAnim.stop();
            pinToToday();
            Qt.callLater(() => agendaFlick.pinToToday());
        }

        onMovementStarted: userScrolled = true
        onTodayYChanged: pinToToday()
        Component.onCompleted: resetToToday()

        NumberAnimation {
            id: todayJumpAnim
            target: agendaFlick
            property: "contentY"
            duration: 250
            easing.type: Easing.OutCubic
        }

        Column {
            id: eventColumn
            width: agendaFlick.width
            spacing: 2

            StyledText {
                visible: activeStore && activeStore.agendaModel.length === 0
                width: parent.width
                text: (activeStore && activeStore.agendaLoading) ? "Loading events…" : "No events in this range."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            Repeater {
                model: activeStore ? activeStore.agendaModel : []

                delegate: Item {
                    id: agendaRow
                    required property var modelData
                    required property int index
                    readonly property string phase: (modelData.kind === "event" && activeStore) ? activeStore.eventPhase(modelData.ev) : ""

                    width: eventColumn.width
                    height: modelData.kind === "event" ? 52 : (modelData.kind === "day" ? 32 : 28)

                    // Week divider
                    Row {
                        visible: agendaRow.modelData.kind === "week"
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.spacingXS
                        anchors.rightMargin: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        StyledText {
                            id: weekLabel
                            text: agendaRow.modelData.kind === "week" ? agendaRow.modelData.label : ""
                            font.pixelSize: Math.max(9, Math.round(Theme.fontSizeSmall * 0.85))
                            font.weight: Font.Medium
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            width: parent.width - weekLabel.implicitWidth - Theme.spacingS * 2
                            height: 1
                            color: Theme.withAlpha(Theme.outline, 0.3)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Day header
                    Rectangle {
                        visible: agendaRow.modelData.kind === "day"
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 26
                        radius: Theme.cornerRadiusSmall
                        color: agendaRow.modelData.isToday ? Theme.withAlpha(Theme.primary, 0.16) : Theme.surfaceContainerHigh

                        StyledText {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            text: agendaRow.modelData.kind === "day" ? agendaRow.modelData.label : ""
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: agendaRow.modelData.isToday ? Theme.primary : Theme.surfaceText
                        }
                    }

                    // Event row
                    Rectangle {
                        id: eventRect
                        visible: agendaRow.modelData.kind === "event"
                        readonly property bool isSelected: agendaView.selectedIndex === agendaRow.index
                        anchors.fill: parent
                        radius: Theme.cornerRadiusSmall
                        color: isSelected ? Theme.withAlpha(Theme.primary, 0.14) : (rowHover.hovered ? Theme.surfaceContainerHigh : "transparent")
                        border.width: isSelected ? 1.5 : 0
                        border.color: Theme.primary

                        Connections {
                            target: agendaView
                            function onSelectedIndexChanged() {
                                if (agendaView.selectedIndex === agendaRow.index) {
                                    var itemY = agendaRow.mapToItem(eventColumn, 0, 0).y;
                                    if (itemY < agendaFlick.contentY) {
                                        agendaFlick.contentY = Math.max(0, itemY - Theme.spacingS);
                                    } else if (itemY + agendaRow.height > agendaFlick.contentY + agendaFlick.height) {
                                        agendaFlick.contentY = itemY + agendaRow.height - agendaFlick.height + Theme.spacingS;
                                    }
                                }
                            }
                        }

                        HoverHandler {
                            id: rowHover
                            enabled: eventRect.visible
                            cursorShape: Qt.PointingHandCursor
                        }

                        RowLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: Theme.spacingS
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            Item {
                                id: eventContentItem
                                Layout.fillWidth: true
                                height: 44
                                Layout.alignment: Qt.AlignVCenter

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        agendaView.selectedIndex = agendaRow.index;
                                        if (agendaRow.modelData.kind === "event" && agendaRow.modelData.ev) {
                                            var ev = agendaRow.modelData.ev;
                                            Quickshell.execDetached(["dcal", "ipc", "ui.openEvent", "uid=" + ev.uid, "start=" + ev.start]);
                                            agendaView.closeRequested();
                                        }
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: Theme.spacingS

                                    Rectangle {
                                        Layout.preferredWidth: 4
                                        Layout.preferredHeight: 34
                                        radius: 2
                                        color: agendaRow.phase === "now" ? "#66BB6A" : (agendaRow.phase === "past" ? Theme.surfaceVariantText : Theme.primary)
                                        opacity: agendaRow.phase === "past" ? 0.4 : 1
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 1

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 4

                                            TextEdit {
                                                Layout.fillWidth: true
                                                text: agendaRow.modelData.kind === "event" ? (agendaRow.modelData.ev.cleanSummary || agendaRow.modelData.ev.summary || "(untitled)") : ""
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: agendaRow.phase === "past" ? Font.Normal : Font.Medium
                                                color: agendaRow.phase === "past" ? Theme.surfaceVariantText : Theme.surfaceText
                                                readOnly: true
                                                selectByMouse: true
                                                selectByKeyboard: true
                                                cursorVisible: false
                                                selectionColor: Theme.primary
                                                selectedTextColor: Theme.primaryText
                                                activeFocusOnPress: true
                                                wrapMode: TextEdit.NoWrap
                                                clip: true
                                                textFormat: TextEdit.PlainText
                                            }

                                            Repeater {
                                                model: (agendaRow.modelData.kind === "event" && agendaRow.modelData.ev) ? (agendaRow.modelData.ev.tags || []) : []
                                                delegate: Rectangle {
                                                    required property var modelData
                                                    readonly property string bColor: modelData.color || Theme.primary
                                                    implicitWidth: evTagRow.implicitWidth + 8
                                                    implicitHeight: 16
                                                    radius: 8
                                                    color: Theme.withAlpha(bColor, 0.15)
                                                    border.width: 1
                                                    border.color: Theme.withAlpha(bColor, 0.35)

                                                    RowLayout {
                                                        id: evTagRow
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
                                                }
                                            }
                                        }

                                        TextEdit {
                                            Layout.fillWidth: true
                                            text: {
                                                if (agendaRow.modelData.kind !== "event" || !activeStore) return "";
                                                var ev = agendaRow.modelData.ev;
                                                return activeStore.eventTimeLabel(ev) + (agendaRow.phase === "now" ? "  ·  Now" : "") + (ev.location ? "  ·  " + ev.location : "");
                                            }
                                            font.pixelSize: Math.max(9, Math.round(Theme.fontSizeSmall * 0.85))
                                            color: Theme.surfaceVariantText
                                            readOnly: true
                                            selectByMouse: true
                                            selectByKeyboard: true
                                            cursorVisible: false
                                            selectionColor: Theme.primary
                                            selectedTextColor: Theme.primaryText
                                            activeFocusOnPress: true
                                            wrapMode: TextEdit.NoWrap
                                            clip: true
                                            textFormat: TextEdit.PlainText
                                        }
                                    }
                                }
                            }

                            // Action Buttons: Copy, Open in dcal, Delete (Visible on Hover or Selected)
                            RowLayout {
                                visible: rowHover.hovered || evCopyMouse.containsMouse || openMouse.containsMouse || deleteMouse.containsMouse || eventRect.isSelected
                                spacing: 2
                                Layout.alignment: Qt.AlignVCenter

                                // 1. Copy Event Details Button
                                Rectangle {
                                    id: evCopyBtn
                                    Layout.preferredWidth: 26
                                    Layout.preferredHeight: 26
                                    radius: 13
                                    color: evCopyMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                                    property bool recentlyCopied: false
                                    Timer {
                                        id: evCopyTimer
                                        interval: 1500
                                        onTriggered: evCopyBtn.recentlyCopied = false
                                    }

                                    DankIcon {
                                        name: evCopyBtn.recentlyCopied ? "check" : "content_copy"
                                        size: 14
                                        color: evCopyBtn.recentlyCopied ? "#10b981" : (evCopyMouse.containsMouse ? Theme.primary : Theme.surfaceVariantText)
                                        anchors.centerIn: parent
                                    }

                                    MouseArea {
                                        id: evCopyMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (agendaRow.modelData.kind === "event" && agendaRow.modelData.ev) {
                                                var ev = agendaRow.modelData.ev;
                                                var details = (ev.cleanSummary || ev.summary || "");
                                                if (activeStore) {
                                                    var timeStr = activeStore.eventTimeLabel(ev);
                                                    if (timeStr) details += " (" + timeStr + ")";
                                                }
                                                if (ev.location) details += " @" + ev.location;
                                                agendaView.copyToClipboard(details);
                                                evCopyBtn.recentlyCopied = true;
                                                evCopyTimer.restart();
                                            }
                                        }
                                    }
                                }

                                // 2. Open Event in dcal
                                Rectangle {
                                    Layout.preferredWidth: 26
                                    Layout.preferredHeight: 26
                                    radius: 13
                                    color: openMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                                    DankIcon {
                                        name: "open_in_new"
                                        size: 14
                                        color: openMouse.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                        anchors.centerIn: parent
                                    }

                                    MouseArea {
                                        id: openMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (agendaRow.modelData.kind === "event" && agendaRow.modelData.ev) {
                                                var ev = agendaRow.modelData.ev;
                                                Quickshell.execDetached(["dcal", "ipc", "ui.openEvent", "uid=" + ev.uid, "start=" + ev.start]);
                                                agendaView.closeRequested();
                                            }
                                        }
                                    }
                                }

                                // 3. Delete Action Button
                                Rectangle {
                                    Layout.preferredWidth: 26
                                    Layout.preferredHeight: 26
                                    radius: 13
                                    color: deleteMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                                    DankIcon {
                                        name: "delete"
                                        size: 14
                                        color: deleteMouse.containsMouse ? Theme.error : Theme.surfaceVariantText
                                        anchors.centerIn: parent
                                    }

                                    MouseArea {
                                        id: deleteMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (agendaRow.modelData.kind === "event" && agendaRow.modelData.ev && activeStore) {
                                                activeStore.deleteEvent(agendaRow.modelData.ev);
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
}
