import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    property string sessionScriptPath: ""
    property var sessionsList: []
    property string currentSessionId: ""

    signal sessionSelected(string sessionId)
    signal sessionDeleted(string sessionId)
    signal sessionCleared()
    signal closeRequested()

    width: parent ? parent.width : 380
    height: parent ? parent.height : 500
    color: Theme.surfaceContainerHighest
    radius: Theme.cornerRadius

    Component.onCompleted: {
        refreshSessions()
    }

    onVisibleChanged: {
        if (visible) {
            refreshSessions()
        }
    }

    Process {
        id: sessionProc
        command: []
        running: false
        property string action: "list"

        stdout: StdioCollector {
            id: sessionCollector
            onStreamFinished: {
                if (sessionProc.action === "list") {
                    try {
                        var raw = (text || "").trim()
                        if (raw) {
                            var data = JSON.parse(raw)
                            if (Array.isArray(data)) {
                                root.sessionsList = data
                            }
                        }
                    } catch(e) {
                        console.warn("[dankCalendarAgenda] parse session list failed:", e)
                    }
                }
            }
        }

        onExited: (code) => {
            if (code === 0 && sessionProc.action === "list") {
                try {
                    if (sessionCollector.text) {
                        var data = JSON.parse(sessionCollector.text.trim())
                        if (Array.isArray(data)) {
                            root.sessionsList = data
                        }
                    }
                } catch(e) {}
            } else if (sessionProc.action === "delete" || sessionProc.action === "clear") {
                root.refreshSessions()
            }
        }
    }

    function refreshSessions() {
        var script = sessionScriptPath || Qt.resolvedUrl("../../session-manager").toString().replace(/^file:\/\//, "")
        sessionProc.running = false
        sessionProc.action = "list"
        sessionProc.command = [script, "list"]
        sessionProc.running = true
    }

    function deleteSession(id) {
        var script = sessionScriptPath || Qt.resolvedUrl("../../session-manager").toString().replace(/^file:\/\//, "")
        sessionProc.running = false
        sessionProc.action = "delete"
        sessionProc.command = [script, "delete", id]
        sessionProc.running = true
        root.sessionDeleted(id)
    }

    function clearAllSessions() {
        var script = sessionScriptPath || Qt.resolvedUrl("../../session-manager").toString().replace(/^file:\/\//, "")
        sessionProc.running = false
        sessionProc.action = "clear"
        sessionProc.command = [script, "clear"]
        sessionProc.running = true
        root.sessionCleared()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingM

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS

            DankIcon {
                name: "forum"
                size: 20
                color: Theme.primary
            }

            StyledText {
                Layout.fillWidth: true
                text: "会话历史记录"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold
                color: Theme.surfaceText
            }

            // Close button
            StyledRect {
                implicitWidth: 28
                implicitHeight: 28
                radius: 6
                color: closeHover.hovered ? Theme.surfaceContainerHigh : "transparent"

                DankIcon {
                    anchors.centerIn: parent
                    name: "close"
                    size: 16
                    color: Theme.surfaceVariantText
                }

                HoverHandler { id: closeHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        // Sessions List
        ListView {
            id: sessionListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Theme.spacingS
            model: root.sessionsList

            delegate: StyledRect {
                id: sDelegate
                required property var modelData
                required property int index

                width: sessionListView.width
                implicitHeight: sRow.implicitHeight + Theme.spacingS * 2
                radius: Theme.cornerRadiusSmall
                color: (modelData.id === root.currentSessionId) 
                       ? Theme.primaryContainer 
                       : sHover.hovered ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow

                HoverHandler { id: sHover }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.sessionSelected(modelData.id)
                        root.closeRequested()
                    }
                }

                RowLayout {
                    id: sRow
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    spacing: Theme.spacingS

                    DankIcon {
                        name: "chat_bubble_outline"
                        size: 16
                        color: (modelData.id === root.currentSessionId) ? Theme.primary : Theme.surfaceVariantText
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.title || "未命名会话"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: (modelData.id === root.currentSessionId) ? Theme.onPrimaryContainer : Theme.surfaceText
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            wrapMode: Text.NoWrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: (modelData.updatedAt ? modelData.updatedAt.replace("T", " ").substring(0, 16) : "") + " · " + (modelData.messageCount || 0) + " 条消息"
                            font.pixelSize: Theme.fontSizeSmall * 0.8
                            color: (modelData.id === root.currentSessionId) ? Theme.onPrimaryContainer : Theme.surfaceVariantText
                        }
                    }

                    // Delete button
                    StyledRect {
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 4
                        color: delHover.hovered ? "#d32f2f" : "transparent"

                        DankIcon {
                            anchors.centerIn: parent
                            name: "delete"
                            size: 14
                            color: delHover.hovered ? "#ffffff" : Theme.surfaceVariantText
                        }

                        HoverHandler { id: delHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.deleteSession(modelData.id)
                            }
                        }
                    }
                }
            }

            // Empty state
            Item {
                anchors.fill: parent
                visible: root.sessionsList.length === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Theme.spacingS

                    DankIcon {
                        Layout.alignment: Qt.AlignHCenter
                        name: "chat"
                        size: 32
                        color: Theme.surfaceVariantText
                    }

                    StyledText {
                        text: "暂无历史会话"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }
            }
        }

        // Bottom Clear All Button
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 36
            radius: Theme.cornerRadiusSmall
            color: clearHover.hovered ? "#d32f2f" : Theme.surfaceContainerHigh
            visible: root.sessionsList.length > 0

            RowLayout {
                anchors.centerIn: parent
                spacing: Theme.spacingS

                DankIcon {
                    name: "delete_sweep"
                    size: 16
                    color: clearHover.hovered ? "#ffffff" : Theme.surfaceVariantText
                }

                StyledText {
                    text: "清空全部会话历史"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: clearHover.hovered ? "#ffffff" : Theme.surfaceVariantText
                }
            }

            HoverHandler { id: clearHover }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.clearAllSessions()
                }
            }
        }
    }
}
