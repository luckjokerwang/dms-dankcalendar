import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Common
import qs.Widgets
import "../../store"

ListView {
    id: listView

    property AiStore aiStore: null
    property string batchScriptPath: ""

    signal scheduleConfirmed()

    clip: true
    spacing: Theme.spacingM
    model: aiStore ? aiStore.messages : []

    // Welcome placeholder
    Item {
        anchors.centerIn: parent
        width: parent.width - Theme.spacingL * 2
        visible: aiStore ? (aiStore.messages.length === 0 && !aiStore.isGenerating) : false

        Column {
            anchors.centerIn: parent
            width: parent.width
            spacing: Theme.spacingS

            DankIcon {
                name: "smart_toy"
                size: 36
                color: Theme.primary
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                width: parent.width
                text: "智能排程助手"
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                text: "直接输入计划需求，或按 Ctrl+V 粘贴课程表/截图，AI 将为您智能拆解日程与待办"
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
                color: Theme.surfaceVariantText
                wrapMode: Text.Wrap
            }
        }
    }

    delegate: Item {
        id: msgDelegate
        required property var modelData
        required property int index

        readonly property bool isUser: modelData.role === "user"
        readonly property bool isSystem: modelData.role === "system"

        width: listView.width
        implicitHeight: col.implicitHeight

        Column {
            id: col
            width: parent.width
            spacing: Theme.spacingXS

            // Attachment previews if user sent image or file
            Row {
                visible: isUser && (modelData.imagePath || modelData.filePath)
                anchors.right: isUser ? parent.right : undefined
                spacing: Theme.spacingXS

                Rectangle {
                    visible: !!modelData.imagePath
                    width: 70
                    height: 70
                    radius: Theme.cornerRadiusSmall
                    color: Theme.surfaceContainerHigh
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: modelData.imagePath ? ("file://" + modelData.imagePath) : ""
                        fillMode: Image.PreserveAspectCrop
                    }
                }
            }

            // Message Bubble
            Row {
                width: parent.width
                layoutDirection: isUser ? Qt.RightToLeft : Qt.LeftToRight
                spacing: Theme.spacingS

                Rectangle {
                    id: bubbleRect
                    width: Math.min(contentCol.implicitWidth + Theme.spacingM * 2, listView.width * 0.85)
                    implicitHeight: contentCol.implicitHeight + Theme.spacingS * 2
                    radius: Theme.cornerRadius
                    color: isUser ? Theme.primary : (isSystem ? Theme.surfaceContainerLowest : Theme.surfaceContainerHigh)

                    Column {
                        id: contentCol
                        anchors.centerIn: parent
                        width: parent.width - Theme.spacingM * 2
                        spacing: Theme.spacingXS

                        StyledText {
                            width: parent.width
                            text: msgDelegate.modelData.content || ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: isUser ? Theme.primaryText : Theme.surfaceText
                            wrapMode: Text.Wrap
                            textFormat: isUser ? Text.PlainText : Text.MarkdownText
                        }
                    }
                }
            }

            // Schedule Proposal Card if attached to assistant message
            ScheduleProposalCard {
                id: propCard
                visible: !isUser && !!modelData.proposal
                width: parent.width
                proposal: modelData.proposal
                batchScriptPath: listView.batchScriptPath
                onConfirmed: (updated) => {
                    listView.scheduleConfirmed();
                }
            }
        }
    }

    footer: Item {
        width: listView.width
        height: (aiStore && (aiStore.isGenerating || aiStore.streamingAssistantText)) ? streamCol.implicitHeight + Theme.spacingM : 0
        visible: aiStore ? (aiStore.isGenerating || !!aiStore.streamingAssistantText) : false

        Column {
            id: streamCol
            width: parent.width
            spacing: Theme.spacingXS

            Rectangle {
                width: Math.min(streamText.implicitWidth + Theme.spacingM * 2, listView.width * 0.85)
                implicitHeight: streamText.implicitHeight + Theme.spacingS * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh

                StyledText {
                    id: streamText
                    anchors.centerIn: parent
                    width: parent.width - Theme.spacingM * 2
                    text: (aiStore && aiStore.streamingAssistantText) ? aiStore.streamingAssistantText : "🤖 正在思考与排程规划中..."
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    function scrollToBottom() {
        positionViewAtEnd();
    }
}
