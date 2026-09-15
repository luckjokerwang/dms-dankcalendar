import QtQuick
import qs.Common
import qs.Widgets
import "../../store"

Item {
    id: tabBar

    property string activeModule: "agenda"
    property int pendingTasksCount: 0

    signal tabSelected(string moduleName)

    width: parent ? (parent.width - Theme.spacingS * 2) : 340
    height: 36

    readonly property real tabWidth: Math.floor((width - Theme.spacingS * 2) / 3)

    readonly property real targetIndicatorX: {
        if (tabBar.activeModule === "tasks") return tabWidth + Theme.spacingS;
        if (tabBar.activeModule === "ai") return (tabWidth + Theme.spacingS) * 2;
        return 0;
    }

    readonly property var springParams: Theme.springPreset("fast", 220)

    SpringMotion {
        id: indicatorSpring
        stiffness: tabBar.springParams.stiffness
        damping: tabBar.springParams.damping
        value: tabBar.targetIndicatorX

        Component.onCompleted: snapTo(tabBar.targetIndicatorX)
    }

    onTargetIndicatorXChanged: {
        indicatorSpring.retarget(targetIndicatorX);
    }

    // 1. Background slot tracks
    Row {
        anchors.fill: parent
        spacing: Theme.spacingS
        z: 0

        Repeater {
            model: 3
            Rectangle {
                width: tabBar.tabWidth
                height: 34
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
            }
        }
    }

    // 2. Physical Spring Indicator Pill
    Rectangle {
        id: activeIndicator
        x: Math.round(indicatorSpring.value)
        y: 0
        width: tabBar.tabWidth
        height: 34
        radius: Theme.cornerRadius
        color: Theme.primary
        z: 1
    }

    // 3. Foreground Tabs with Interactive Icons & Labels
    Row {
        anchors.fill: parent
        spacing: Theme.spacingS
        z: 2

        // Tab 1: Agenda
        Item {
            width: tabBar.tabWidth
            height: 34

            readonly property bool isCurrent: tabBar.activeModule === "agenda"

            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: "calendar_today"
                    size: 15
                    color: parent.parent.isCurrent ? Theme.primaryText : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                StyledText {
                    text: "日程"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: parent.parent.isCurrent ? Theme.primaryText : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: tabBar.tabSelected("agenda")
            }
        }

        // Tab 2: Tasks
        Item {
            width: tabBar.tabWidth
            height: 34

            readonly property bool isCurrent: tabBar.activeModule === "tasks"

            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: "task_alt"
                    size: 15
                    color: parent.parent.isCurrent ? Theme.primaryText : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                StyledText {
                    text: tabBar.pendingTasksCount > 0 ? ("待办 (" + tabBar.pendingTasksCount + ")") : "待办"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: parent.parent.isCurrent ? Theme.primaryText : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: tabBar.tabSelected("tasks")
            }
        }

        // Tab 3: AI Assistant
        Item {
            width: tabBar.tabWidth
            height: 34

            readonly property bool isCurrent: tabBar.activeModule === "ai"

            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: "smart_toy"
                    size: 15
                    color: parent.parent.isCurrent ? Theme.primaryText : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                StyledText {
                    text: "助理"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: parent.parent.isCurrent ? Theme.primaryText : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: tabBar.tabSelected("ai")
            }
        }
    }
}
