import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import "../../store"

Rectangle {
    id: inputBar

    DankCalendarConstants { id: constants }
    property bool isGenerating: false
    property string attachedImagePath: ""
    property string attachedFilePath: ""

    signal sendRequested(string text, string imagePath, string filePath)
    signal stopRequested()
    signal commandPaletteRequested()
    signal fileBrowserRequested()

    width: parent.width
    implicitHeight: mainCol.implicitHeight + Theme.spacingS * 2
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh
    border.width: chatInput.activeFocus ? 2 : 1
    border.color: chatInput.activeFocus ? Theme.primary : Theme.outlineMedium

    Process {
        id: pasteProc
        command: [constants.coreScriptPath, "paste"]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                var trimmed = line.trim();
                if (trimmed) {
                    inputBar.attachedImagePath = trimmed;
                }
            }
        }
    }

    Column {
        id: mainCol
        anchors.fill: parent
        anchors.margins: Theme.spacingS
        spacing: Theme.spacingXS

        // Attached Thumbnail Pill
        Row {
            visible: !!inputBar.attachedImagePath || !!inputBar.attachedFilePath
            spacing: Theme.spacingS

            Rectangle {
                width: 48
                height: 48
                radius: Theme.cornerRadiusSmall
                color: Theme.surfaceContainerLowest
                clip: true

                Image {
                    anchors.fill: parent
                    source: inputBar.attachedImagePath ? ("file://" + inputBar.attachedImagePath) : ""
                    fillMode: Image.PreserveAspectCrop
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    width: 16
                    height: 16
                    radius: 8
                    color: Theme.surfaceContainerHighest
                    StyledText {
                        anchors.centerIn: parent
                        text: "×"
                        font.pixelSize: 12
                        color: Theme.surfaceText
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            inputBar.attachedImagePath = "";
                            inputBar.attachedFilePath = "";
                        }
                    }
                }
            }
        }

        // Text Input Area
        Row {
            width: parent.width
            spacing: Theme.spacingS

            DankActionButton {
                iconName: "content_paste"
                onClicked: {
                    if (!pasteProc.running) pasteProc.running = true;
                }
            }

            DankActionButton {
                iconName: "attach_file"
                onClicked: inputBar.fileBrowserRequested()
            }

            DankActionButton {
                iconName: "terminal"
                onClicked: inputBar.commandPaletteRequested()
            }

            Flickable {
                id: inputFlick
                width: parent.width - 150
                height: Math.min(80, Math.max(28, chatInput.implicitHeight))
                contentHeight: chatInput.implicitHeight
                clip: true

                TextEdit {
                    id: chatInput
                    width: inputFlick.width
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true

                    Text {
                        text: "输入排程需求、按 Ctrl+V 粘贴截图或输入 / 选用指令..."
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                        visible: !chatInput.text && !chatInput.activeFocus
                    }

                    Keys.onReturnPressed: (event) => {
                        if (event.modifiers & Qt.ShiftModifier) {
                            event.accepted = false;
                        } else {
                            event.accepted = true;
                            inputBar.triggerSend();
                        }
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier)) {
                            if (!pasteProc.running) pasteProc.running = true;
                        }
                    }
                }
            }

            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: inputBar.isGenerating ? Theme.error : Theme.primary
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: inputBar.isGenerating ? "stop" : "arrow_upward"
                    size: 16
                    color: Theme.primaryText
                    anchors.centerIn: parent
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (inputBar.isGenerating) {
                            inputBar.stopRequested();
                        } else {
                            inputBar.triggerSend();
                        }
                    }
                }
            }
        }
    }

    function triggerSend() {
        var txt = chatInput.text.trim();
        if (!txt && !attachedImagePath && !attachedFilePath) return;
        inputBar.sendRequested(txt, attachedImagePath, attachedFilePath);
        chatInput.text = "";
        attachedImagePath = "";
        attachedFilePath = "";
    }

    function setInputText(t) {
        chatInput.text = t;
        chatInput.forceActiveFocus();
    }
}
