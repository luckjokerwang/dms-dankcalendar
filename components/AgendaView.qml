import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: agendaView

    property var rootWidget: null
    signal closeRequested

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

        // Open the list scrolled to today, not to the oldest past day.
        // DMS keeps popout contents warm after close, so reset on open.
        property bool userScrolled: false
        readonly property real todayY: Math.max(0, Math.min(rootWidget ? rootWidget.agendaTodayOffset : 0, contentHeight - height))

        function pinToToday() {
            if (!userScrolled)
                contentY = todayY;
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
                visible: rootWidget && rootWidget.agendaModel.length === 0
                width: parent.width
                text: (rootWidget && rootWidget.agendaLoading) ? "Loading events…" : "No events in this range."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            Repeater {
                model: rootWidget ? rootWidget.agendaModel : []

                delegate: Item {
                    id: agendaRow

                    required property var modelData
                    readonly property string phase: (modelData.kind === "event" && rootWidget) ? rootWidget.eventPhase(modelData.ev) : ""

                    width: eventColumn.width
                    height: modelData.kind === "event" ? 52 : (modelData.kind === "day" ? 32 : 28)

                    // Week divider: small label + hairline.
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

                    // Day header: shaded band, today tinted primary.
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

                    // Event row: click opens the event's details window in DankCalendar.
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

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: Theme.spacingS
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            // Left Clickable Content Area
                            Item {
                                id: eventContentItem
                                width: parent.width - 28 - Theme.spacingS
                                height: 44
                                anchors.verticalCenter: parent.verticalCenter

                                Row {
                                    anchors.fill: parent
                                    spacing: Theme.spacingS

                                    Rectangle {
                                        width: 4
                                        height: 34
                                        radius: 2
                                        color: agendaRow.phase === "now" ? "#66BB6A" : (agendaRow.phase === "past" ? Theme.surfaceVariantText : Theme.primary)
                                        opacity: agendaRow.phase === "past" ? 0.4 : 1
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        width: parent.width - 4 - Theme.spacingS
                                        spacing: 1
                                        anchors.verticalCenter: parent.verticalCenter

                                        StyledText {
                                            width: parent.width
                                            text: agendaRow.modelData.kind === "event" ? (agendaRow.modelData.ev.summary || "(untitled)") : ""
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: agendaRow.phase === "past" ? Font.Normal : Font.Medium
                                            color: agendaRow.phase === "past" ? Theme.surfaceVariantText : Theme.surfaceText
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }

                                        StyledText {
                                            width: parent.width
                                            text: {
                                                if (agendaRow.modelData.kind !== "event" || !rootWidget)
                                                    return "";

                                                var ev = agendaRow.modelData.ev;
                                                return rootWidget.eventTimeLabel(ev) + (agendaRow.phase === "now" ? "  ·  Now" : "") + (ev.location ? "  ·  " + ev.location : "");
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: agendaRow.phase === "now" ? "#66BB6A" : Theme.surfaceVariantText
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }
                                    }
                                }

                                TapHandler {
                                    onTapped: {
                                        if (rootWidget) {
                                            rootWidget.openEvent(agendaRow.modelData.ev);
                                        }
                                        agendaView.closeRequested();
                                    }
                                }
                            }

                            // Delete Action Button (Task-style)
                            Rectangle {
                                width: 28
                                height: 28
                                radius: 14
                                color: delEvMouse.containsMouse ? Theme.withAlpha(Theme.error, 0.15) : "transparent"
                                visible: rowHover.hovered || delEvMouse.containsMouse
                                anchors.verticalCenter: parent.verticalCenter

                                DankIcon {
                                    name: "delete"
                                    size: 16
                                    color: delEvMouse.containsMouse ? Theme.error : Theme.surfaceVariantText
                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    id: delEvMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (rootWidget) {
                                            rootWidget.deleteEvent(agendaRow.modelData.ev);
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

    // Floating "Today" chip: appears when the list is scrolled
    // away from today and jumps back to it.
    Rectangle {
        visible: !todayJumpAnim.running && Math.abs(agendaFlick.contentY - agendaFlick.todayY) > 120
        width: todayChipRow.implicitWidth + Theme.spacingM * 2
        height: 28
        radius: 14
        color: Theme.primary
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spacingM

        Row {
            id: todayChipRow

            anchors.centerIn: parent
            spacing: Theme.spacingXS

            DankIcon {
                name: agendaFlick.contentY > agendaFlick.todayY ? "arrow_upward" : "arrow_downward"
                size: Theme.iconSizeSmall
                color: Theme.primaryText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: "Today"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.primaryText
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                todayJumpAnim.to = agendaFlick.todayY;
                todayJumpAnim.restart();
            }
        }
    }
}
