import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets
import "../../store"
import "../common"
import "file:/usr/share/quickshell/dms/Modals/FileBrowser" as DMSFileBrowser

StyledRect {
    id: root

    property AiStore aiStore: null
    property ProviderStore providerStore: null
    property string batchScriptPath: ""

    signal scheduleConfirmed()

    property bool showDrawer: false
    property bool showModelMenu: false
    property bool showCommandPalette: false
    property bool showProviderModal: false
    property var selectedProviderData: null

    implicitWidth: parent ? parent.width : 420
    implicitHeight: visible ? 420 : 0
    color: Theme.surfaceContainerLowest
    radius: Theme.cornerRadius

    Item {
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingS
            spacing: Theme.spacingS

            // 1. Top Sub-Header (Session title + Model Selector + Actions)
            Row {
                width: parent.width
                height: 34
                spacing: Theme.spacingXS

                DankActionButton {
                    iconName: "history"
                    onClicked: root.showDrawer = !root.showDrawer
                }

                StyledText {
                    width: parent.width - 240
                    text: aiStore ? aiStore.currentSessionTitle : "新排程会话"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Model Selector Capsule
                Rectangle {
                    height: 28
                    width: modelPillRow.implicitWidth + Theme.spacingM * 2
                    radius: 14
                    color: Theme.surfaceContainerHigh
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        id: modelPillRow
                        anchors.centerIn: parent
                        spacing: 4

                        DankIcon {
                            name: "bolt"
                            size: 14
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: providerStore ? providerStore.activeModelId : "agnes-2.5-flash"
                            font.pixelSize: Theme.fontSizeSmall - 1
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        DankIcon {
                            name: "arrow_drop_down"
                            size: 14
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showModelMenu = !root.showModelMenu
                    }
                }

                DankActionButton {
                    iconName: "tune"
                    onClicked: {
                        root.selectedProviderData = null;
                        root.showProviderModal = true;
                    }
                }

                DankActionButton {
                    iconName: "add"
                    onClicked: {
                        if (aiStore) aiStore.newSession();
                    }
                }
            }

            // 2. Message List View
            MessageListView {
                id: msgListView
                width: parent.width
                height: parent.height - 34 - inputBar.implicitHeight - Theme.spacingS * 2
                aiStore: root.aiStore
                batchScriptPath: root.batchScriptPath
                onScheduleConfirmed: root.scheduleConfirmed()
            }

            // 3. Modern Input Area
            ChatInputBar {
                id: inputBar
                width: parent.width
                isGenerating: aiStore ? aiStore.isGenerating : false
                onSendRequested: (txt, img, file) => {
                    if (aiStore) {
                        var mId = providerStore ? providerStore.activeModelId : "";
                        aiStore.sendMessage(txt, img, file, mId, null);
                        Qt.callLater(() => msgListView.scrollToBottom());
                    }
                }
                onStopRequested: {
                    if (aiStore) aiStore.stopGeneration();
                }
                onCommandPaletteRequested: {
                    root.showCommandPalette = true;
                }
                onFileBrowserRequested: {
                    fileBrowserLoader.active = true;
                }
            }
        }

        // Dropdown: Model Picker
        ModelPickerMenu {
            id: modelPicker
            visible: root.showModelMenu
            anchors.top: parent.top
            anchors.topMargin: 40
            anchors.horizontalCenter: parent.horizontalCenter
            providerStore: root.providerStore
            activeModel: providerStore ? providerStore.activeModelId : ""
            onModelSelected: (mId, pId) => {
                if (providerStore) providerStore.setActive(pId, mId);
                root.showModelMenu = false;
            }
        }

        // Modal: Command Palette
        CommandPalette {
            id: cmdPalette
            visible: root.showCommandPalette
            anchors.centerIn: parent
            sessionList: aiStore ? aiStore.sessionsList : []
            onExecuteCommand: (cmd) => {
                inputBar.setInputText(cmd);
                root.showCommandPalette = false;
            }
            onSelectSession: (sId) => {
                if (aiStore) aiStore.switchSession(sId);
                root.showCommandPalette = false;
            }
            onSelectModel: (mId, pId) => {
                if (providerStore) providerStore.setActive(pId, mId);
                root.showCommandPalette = false;
            }
            onCloseRequested: root.showCommandPalette = false
        }

        // Drawer: Session History Drawer
        SessionDrawer {
            id: sessDrawer
            visible: root.showDrawer
            anchors.fill: parent
            sessionsList: aiStore ? aiStore.sessionsList : []
            currentSessionId: aiStore ? aiStore.currentSessionId : ""
            onSessionSelected: (sId) => {
                if (aiStore) aiStore.switchSession(sId);
                root.showDrawer = false;
            }
            onSessionDeleted: (sId) => {
                if (aiStore) aiStore.deleteSession(sId);
            }
            onCloseRequested: root.showDrawer = false
        }

        // Shared Modal: Provider Configuration
        ProviderConfigModal {
            id: provModal
            visible: root.showProviderModal
            providerStore: root.providerStore
            providerId: root.selectedProviderData ? root.selectedProviderData.id : ""
            providerName: root.selectedProviderData ? root.selectedProviderData.name : ""
            providerBaseUrl: root.selectedProviderData ? root.selectedProviderData.baseUrl : "https://"
            providerApiKey: root.selectedProviderData ? root.selectedProviderData.apiKey : ""
            onClosed: root.showProviderModal = false
            onSaved: (prov) => {
                if (providerStore) providerStore.reloadProviders();
            }
        }

        // File Browser Loader
        Loader {
            id: fileBrowserLoader
            active: false
            sourceComponent: DMSFileBrowser.FileBrowserModal {
                onFileSelected: (path) => {
                    inputBar.attachedImagePath = path;
                    fileBrowserLoader.active = false;
                }
                onClosed: fileBrowserLoader.active = false
            }
        }
    }
}
