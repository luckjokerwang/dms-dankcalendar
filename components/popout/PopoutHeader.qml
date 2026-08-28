import QtQuick
import qs.Common
import qs.Widgets
import "../../store"

Item {
    id: header

    property CalendarStore calendarStore: null
    property TaskStore taskStore: null
    property string activeModule: "agenda"
    property bool isRefreshing: false

    signal newEventRequested()
    signal refreshRequested()
    signal settingsRequested()
    signal closeRequested()
    signal toggleDcalRequested()

    width: parent.width
    height: 48

    Column {
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        StyledText {
            text: "Dank Calendar"
            font.pixelSize: Theme.fontSizeLarge + 2
            font.weight: Font.Bold
            color: titleHover.hovered ? Theme.primary : Theme.surfaceText
        }

        StyledText {
            text: {
                var date = calendarStore ? calendarStore.formatLocalDate(new Date(), "dddd, d MMMM") : "";
                if (activeModule === "tasks") {
                    var pCount = taskStore ? taskStore.pendingTasksCount : 0;
                    if (pCount === 0) return date + "  ·  全部完成";
                    return date + "  ·  " + pCount + " 项待办";
                }
                var upCount = calendarStore ? calendarStore.upcomingCount : 0;
                if (upCount === 0) return date;
                return date + "  ·  " + upCount + " upcoming";
            }
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        HoverHandler {
            id: titleHover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: header.toggleDcalRequested()
        }
    }

    Row {
        spacing: Theme.spacingXS
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingXS
        anchors.verticalCenter: parent.verticalCenter

        DankActionButton {
            iconName: "add"
            onClicked: header.newEventRequested()
        }

        Rectangle {
            id: syncBtn
            width: 32
            height: 32
            radius: Theme.cornerRadiusSmall
            color: syncMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

            DankIcon {
                id: syncIcon
                name: "sync"
                size: 18
                color: header.isRefreshing ? Theme.primary : (syncMouse.containsMouse ? Theme.surfaceText : Theme.surfaceVariantText)
                anchors.centerIn: parent
                smoothTransform: true
                layer.enabled: true
                transformOrigin: Item.Center

                RotationAnimation {
                    target: syncIcon
                    property: "rotation"
                    from: 0
                    to: 360
                    duration: 800
                    loops: Animation.Infinite
                    running: header.isRefreshing
                    onRunningChanged: if (!running) syncIcon.rotation = 0
                }
            }

            MouseArea {
                id: syncMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: header.refreshRequested()
            }
        }

        DankActionButton {
            iconName: "settings"
            onClicked: header.settingsRequested()
        }

        DankActionButton {
            iconName: "close"
            onClicked: header.closeRequested()
        }
    }
}
