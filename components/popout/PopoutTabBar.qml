import QtQuick
import qs.Common
import qs.Widgets
import "../../store"

Row {
    id: tabBar

    property string activeModule: "agenda"
    property int pendingTasksCount: 0

    signal tabSelected(string moduleName)

    width: parent.width - Theme.spacingS * 2
    height: 36
    spacing: Theme.spacingS

    // Tab 1: 日程
    Rectangle {
        width: (parent.width - Theme.spacingS * 2) / 3
        height: 34
        radius: Theme.cornerRadius
        color: tabBar.activeModule === "agenda" ? Theme.primary : Theme.surfaceContainerHigh

        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingXS

            DankIcon {
                name: "calendar_today"
                size: 15
                color: tabBar.activeModule === "agenda" ? Theme.primaryText : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: "日程"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: tabBar.activeModule === "agenda" ? Theme.primaryText : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tabBar.tabSelected("agenda")
        }
    }

    // Tab 2: 待办任务
    Rectangle {
        width: (parent.width - Theme.spacingS * 2) / 3
        height: 34
        radius: Theme.cornerRadius
        color: tabBar.activeModule === "tasks" ? Theme.primary : Theme.surfaceContainerHigh

        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingXS

            DankIcon {
                name: "task_alt"
                size: 15
                color: tabBar.activeModule === "tasks" ? Theme.primaryText : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: tabBar.pendingTasksCount > 0 ? ("待办 (" + tabBar.pendingTasksCount + ")") : "待办"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: tabBar.activeModule === "tasks" ? Theme.primaryText : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tabBar.tabSelected("tasks")
        }
    }

    // Tab 3: AI 助理
    Rectangle {
        width: (parent.width - Theme.spacingS * 2) / 3
        height: 34
        radius: Theme.cornerRadius
        color: tabBar.activeModule === "ai" ? Theme.primary : Theme.surfaceContainerHigh

        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingXS

            DankIcon {
                name: "smart_toy"
                size: 15
                color: tabBar.activeModule === "ai" ? Theme.primaryText : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: "助理"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: tabBar.activeModule === "ai" ? Theme.primaryText : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tabBar.tabSelected("ai")
        }
    }
}
