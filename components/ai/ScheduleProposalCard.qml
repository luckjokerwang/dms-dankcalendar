import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    property var proposal: null
    property string batchScriptPath: ""
    property var selectedEvents: []
    property var selectedTasks: []
    property bool isWriting: false
    property bool isCommitted: false
    property string resultMessage: ""

    signal confirmed()

    implicitWidth: parent ? parent.width : 360
    implicitHeight: mainLayout.implicitHeight + Theme.spacingM * 2
    color: Theme.surfaceContainerLowest
    radius: Theme.cornerRadius
    border.width: 1
    border.color: isCommitted ? "#2e7d32" : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)

    Process {
        id: batchProcess
        command: []
        running: false

        stdout: StdioCollector {
            id: batchCollector
            onStreamFinished: {
                var raw = (text || "").trim()
                try {
                    var res = JSON.parse(raw)
                    if (res.status === "ok" || res.createdEvents > 0 || res.createdTasks > 0) {
                        root.isCommitted = true
                        root.resultMessage = "✓ 成功添加 " + (res.createdEvents || 0) + " 项日程, " + (res.createdTasks || 0) + " 项待办"
                        root.confirmed()
                    } else {
                        root.resultMessage = (res.errors && res.errors.length > 0) ? res.errors.join("; ") : (res.message || "写入失败")
                    }
                } catch(e) {
                    root.resultMessage = "写入完成"
                    root.isCommitted = true
                    root.confirmed()
                }
                root.isWriting = false
            }
        }

        onExited: (exitCode) => {
            if (exitCode !== 0 && !root.isCommitted) {
                root.resultMessage = "执行出错 (退出码 " + exitCode + ")"
                root.isWriting = false
            }
        }
    }

    function commitItems() {
        if (!proposal || isCommitted || isWriting) return
        isWriting = true
        resultMessage = "正在写入系统日历与待办..."

        var evs = proposal.events || []
        var tks = proposal.tasks || []
        var finalEvents = []
        var finalTasks = []

        for (var i = 0; i < evs.length; i++) {
            if (selectedEvents[i] !== false) finalEvents.push(evs[i])
        }
        for (var j = 0; j < tks.length; j++) {
            if (selectedTasks[j] !== false) finalTasks.push(tks[j])
        }

        var payload = {
            events: finalEvents,
            tasks: finalTasks
        }

        var script = batchScriptPath || Qt.resolvedUrl("../../batch-create-items").toString().replace(/^file:\/\//, "")
        batchProcess.running = false
        batchProcess.command = [script, JSON.stringify(payload)]
        batchProcess.running = true
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        // 1. Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS

            DankIcon {
                name: isCommitted ? "check_circle" : "auto_awesome"
                size: 18
                color: isCommitted ? "#2e7d32" : Theme.primary
            }

            StyledText {
                Layout.fillWidth: true
                text: isCommitted ? "排程已确认并写入日历" : (proposal && proposal.explanation ? proposal.explanation : "待确认的排程提案")
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
                color: isCommitted ? "#2e7d32" : Theme.surfaceText
                elide: Text.ElideRight
            }
        }

        // 2. Section: Events List
        ColumnLayout {
            Layout.fillWidth: true
            visible: proposal && proposal.events && proposal.events.length > 0
            spacing: Theme.spacingXS

            StyledText {
                text: "📅 日程建议"
                font.pixelSize: Theme.fontSizeSmall * 0.9
                font.weight: Font.Medium
                color: Theme.primary
            }

            Repeater {
                model: proposal && proposal.events ? proposal.events : []

                delegate: StyledRect {
                    id: eventItemRect
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    implicitHeight: eventRow.implicitHeight + Theme.spacingS * 2
                    color: Theme.surfaceContainerHigh
                    radius: Theme.cornerRadiusSmall

                    RowLayout {
                        id: eventRow
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        spacing: Theme.spacingS

                        // Checkbox Box
                        StyledRect {
                            implicitWidth: 20
                            implicitHeight: 20
                            radius: 4
                            color: (root.selectedEvents[index] !== false) ? Theme.primary : "transparent"
                            border.width: (root.selectedEvents[index] !== false) ? 0 : 2
                            border.color: Theme.surfaceVariantText

                            DankIcon {
                                anchors.centerIn: parent
                                name: "check"
                                size: 14
                                color: "#ffffff"
                                visible: root.selectedEvents[index] !== false
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: !root.isCommitted && !root.isWriting
                                onClicked: {
                                    var copy = root.selectedEvents.slice()
                                    copy[index] = !(copy[index] !== false)
                                    root.selectedEvents = copy
                                }
                            }
                        }

                        // Event Title & Time
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.title || modelData.summary || "未命名日程"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: (modelData.start ? modelData.start.replace("T", " ").substring(0, 16) : "") + (modelData.end ? " ~ " + (modelData.end.includes("T") ? modelData.end.split("T")[1].substring(0, 5) : modelData.end) : "")
                                font.pixelSize: Theme.fontSizeSmall * 0.85
                                color: Theme.surfaceVariantText
                            }
                        }
                    }
                }
            }
        }

        // 3. Section: Tasks List
        ColumnLayout {
            Layout.fillWidth: true
            visible: proposal && proposal.tasks && proposal.tasks.length > 0
            spacing: Theme.spacingXS

            StyledText {
                text: "📋 待办清单建议"
                font.pixelSize: Theme.fontSizeSmall * 0.9
                font.weight: Font.Medium
                color: Theme.secondary || Theme.primary
            }

            Repeater {
                model: proposal && proposal.tasks ? proposal.tasks : []

                delegate: StyledRect {
                    id: taskItemRect
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    implicitHeight: taskRow.implicitHeight + Theme.spacingS * 2
                    color: Theme.surfaceContainerHigh
                    radius: Theme.cornerRadiusSmall

                    RowLayout {
                        id: taskRow
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        spacing: Theme.spacingS

                        // Checkbox Box
                        StyledRect {
                            implicitWidth: 20
                            implicitHeight: 20
                            radius: 4
                            color: (root.selectedTasks[index] !== false) ? Theme.primary : "transparent"
                            border.width: (root.selectedTasks[index] !== false) ? 0 : 2
                            border.color: Theme.surfaceVariantText

                            DankIcon {
                                anchors.centerIn: parent
                                name: "check"
                                size: 14
                                color: "#ffffff"
                                visible: root.selectedTasks[index] !== false
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: !root.isCommitted && !root.isWriting
                                onClicked: {
                                    var copy = root.selectedTasks.slice()
                                    copy[index] = !(copy[index] !== false)
                                    root.selectedTasks = copy
                                }
                            }
                        }

                        // Task Title & Due
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingXS

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.summary || modelData.title || "未命名任务"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    elide: Text.ElideRight
                                }

                                // Priority Badge
                                StyledRect {
                                    visible: modelData.priority !== undefined && modelData.priority !== null && modelData.priority !== 0
                                    implicitWidth: pBadgeText.implicitWidth + 8
                                    implicitHeight: 18
                                    radius: 4
                                    color: (modelData.priority === 1) ? "#ffebee" : (modelData.priority === 5) ? "#fff8e1" : "#e3f2fd"

                                    StyledText {
                                        id: pBadgeText
                                        anchors.centerIn: parent
                                        text: (modelData.priority === 1) ? "高优" : (modelData.priority === 5) ? "中优" : "低优"
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: (modelData.priority === 1) ? "#c62828" : (modelData.priority === 5) ? "#f57f17" : "#1565c0"
                                    }
                                }
                            }

                            StyledText {
                                visible: !!modelData.due
                                Layout.fillWidth: true
                                text: "截止: " + (modelData.due ? modelData.due.replace("T", " ").substring(0, 16) : "")
                                font.pixelSize: Theme.fontSizeSmall * 0.85
                                color: Theme.surfaceVariantText
                            }
                        }
                    }
                }
            }
        }

        // 4. Action Button / Status Result
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 36
            radius: Theme.cornerRadiusSmall
            color: isCommitted ? "#2e7d32" : (isWriting ? Theme.surfaceContainerHighest : Theme.primary)

            RowLayout {
                anchors.centerIn: parent
                spacing: Theme.spacingS

                DankIcon {
                    name: isCommitted ? "check_circle" : (isWriting ? "sync" : "done_all")
                    size: 16
                    color: "#ffffff"
                }

                StyledText {
                    text: isCommitted ? (root.resultMessage || "✓ 已成功添加至日历与待办") : (isWriting ? (root.resultMessage || "正在写入...") : "一键确认添加 (Confirm)")
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                    color: "#ffffff"
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: (root.isCommitted || root.isWriting) ? Qt.ArrowCursor : Qt.PointingHandCursor
                enabled: !root.isCommitted && !root.isWriting
                onClicked: root.commitItems()
            }
        }
    }
}
