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
                        anchors.fill: parent
                        radius: Theme.cornerRadiusSmall
                        color: rowHover.hovered ? Theme.surfaceContainerHigh : "transparent"

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

                            // Action Buttons: Copy, Open in dcal, Delete (Visible on Hover)
                            RowLayout {
                                visible: rowHover.hovered || evCopyMouse.containsMouse || openMouse.containsMouse || deleteMouse.containsMouse
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
