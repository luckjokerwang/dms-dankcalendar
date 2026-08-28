import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import "../../store"

Item {
    id: vPill

    property CalendarStore calendarStore: null
    property TaskStore taskStore: null
    property string barModule: "agenda"
    property int widgetThickness: 32
    property int iconSize: 18

    signal cycleRequested()
    signal hoverRequested(var targetItem)
    signal hoverEnded()

    implicitWidth: vCol.implicitWidth
    implicitHeight: vCol.implicitHeight

    // Middle click toggles dcal
    MouseArea {
        anchors.fill: parent
        anchors.margins: -10
        acceptedButtons: Qt.MiddleButton
        onClicked: Quickshell.execDetached(["dcal", "ipc", "ui.toggle", "view=day"])
    }

    Column {
        id: vCol
        spacing: Theme.spacingXS || 4

        Item {
            width: iconSize
            height: iconSize
            anchors.horizontalCenter: parent.horizontalCenter

            DankIcon {
                id: vIcon
                name: (calendarStore && calendarStore.isLoading) ? "sync" : (barModule === "tasks" ? "task_alt" : "calendar_today")
                size: iconSize
                color: Theme.primary
                anchors.centerIn: parent
                smoothTransform: true
                layer.enabled: true
                transformOrigin: Item.Center

                RotationAnimation {
                    target: vIcon
                    property: "rotation"
                    from: 0
                    to: 360
                    duration: 800
                    loops: Animation.Infinite
                    running: calendarStore ? calendarStore.isLoading : false
                    onRunningChanged: if (!running) vIcon.rotation = 0
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: vPill.cycleRequested()
            }
        }

        NumericText {
            width: widgetThickness
            text: barModule === "tasks" ? ((taskStore && taskStore.pendingTasksCount > 0) ? String(taskStore.pendingTasksCount) : "✓") : (calendarStore ? calendarStore.compactTimeText : "")
            reserveText: "99d"
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Bold
            color: calendarStore ? calendarStore.timeColor : Theme.primary
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            anchors.horizontalCenter: parent.horizontalCenter
            visible: barModule === "tasks" || (calendarStore && calendarStore.hasEvent)
        }
    }

    HoverHandler {
        onHoveredChanged: hovered ? vPill.hoverRequested(vPill) : vPill.hoverEnded()
    }
}
