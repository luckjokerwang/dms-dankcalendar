import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import "../../store"

Rectangle {
    id: modal

    DankCalendarConstants { id: constants }
    property ProviderStore providerStore: null

    property bool isEditing: false
    property string providerId: ""
    property string providerName: ""
    property string providerBaseUrl: "https://"
    property string providerApiKey: ""
    property string providerIcon: "smart_toy"
    property string providerColor: "#1565c0"
    property bool isTesting: false
    property string testResult: ""
    property bool testSuccess: false

    signal closed()
    signal saved(var providerObj)

    anchors.fill: parent
    color: Theme.withAlpha(Theme.surface, 0.96)
    radius: Theme.cornerRadius
    z: 999

    MouseArea {
        anchors.fill: parent
    }

    Process {
        id: testModelsProc
        command: []
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                var trimmed = line.trim();
                if (!trimmed) return;
                try {
                    var res = JSON.parse(trimmed);
                    if (res.status === "ok") {
                        modal.testResult = "🟢 连接成功 (" + (res.latency || 0) + "ms) · 获得 " + (res.count || 0) + " 个模型";
                        modal.testSuccess = true;
                    } else {
                        modal.testResult = "❌ " + (res.message || "连接失败");
                        modal.testSuccess = false;
                    }
                } catch(e) {
                    modal.testResult = "❌ 解析响应失败";
                    modal.testSuccess = false;
                }
                modal.isTesting = false;
            }
        }
        onExited: (code) => {
            modal.isTesting = false;
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingM

        // Header
        Row {
            width: parent.width
            StyledText {
                text: modal.isEditing ? "编辑大模型服务商" : "添加服务商 / 端点"
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
                color: Theme.primary
            }
            Item { Layout.fillWidth: true }
            DankActionButton {
                iconName: "close"
                onClicked: modal.closed()
            }
        }

        // Form Fields
        Column {
            width: parent.width
            spacing: Theme.spacingS

            StyledText { text: "服务商 ID (英文标识):"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
            Rectangle {
                width: parent.width
                height: 36
                radius: Theme.cornerRadiusSmall
                color: Theme.surfaceContainerHigh
                TextInput {
                    id: idInput
                    anchors.fill: parent
                    anchors.margins: 8
                    text: modal.providerId
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    enabled: !modal.isEditing
                    onTextChanged: modal.providerId = text
                }
            }

            StyledText { text: "显示名称 (Name):"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
            Rectangle {
                width: parent.width
                height: 36
                radius: Theme.cornerRadiusSmall
                color: Theme.surfaceContainerHigh
                TextInput {
                    anchors.fill: parent
                    anchors.margins: 8
                    text: modal.providerName
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    onTextChanged: modal.providerName = text
                }
            }

            StyledText { text: "API Base URL:"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
            Rectangle {
                width: parent.width
                height: 36
                radius: Theme.cornerRadiusSmall
                color: Theme.surfaceContainerHigh
                TextInput {
                    anchors.fill: parent
                    anchors.margins: 8
                    text: modal.providerBaseUrl
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    onTextChanged: modal.providerBaseUrl = text
                }
            }

            StyledText { text: "API Key (密匙):"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
            Rectangle {
                width: parent.width
                height: 36
                radius: Theme.cornerRadiusSmall
                color: Theme.surfaceContainerHigh
                TextInput {
                    anchors.fill: parent
                    anchors.margins: 8
                    text: modal.providerApiKey
                    echoMode: TextInput.Password
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    onTextChanged: modal.providerApiKey = text
                }
            }
        }

        // Test Status Text
        StyledText {
            width: parent.width
            text: modal.testResult
            font.pixelSize: Theme.fontSizeSmall
            color: modal.testSuccess ? "#4caf50" : Theme.error
            visible: modal.testResult.length > 0
            wrapMode: Text.Wrap
        }

        // Bottom Action Buttons
        Row {
            width: parent.width
            spacing: Theme.spacingM

            Rectangle {
                width: (parent.width - Theme.spacingM) / 2
                height: 36
                radius: Theme.cornerRadiusSmall
                color: Theme.surfaceContainerHigh
                StyledText {
                    anchors.centerIn: parent
                    text: modal.isTesting ? "⏳ 测试中..." : "🔍 测试并拉取模型"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        modal.isTesting = true;
                        modal.testResult = "⏳ 正在连接测试端点...";
                        testModelsProc.command = [
                            constants.coreScriptPath, "provider", "fetch-models",
                            "--id", modal.providerId,
                            "--base-url", modal.providerBaseUrl,
                            "--api-key", modal.providerApiKey
                        ];
                        testModelsProc.running = true;
                    }
                }
            }

            Rectangle {
                width: (parent.width - Theme.spacingM) / 2
                height: 36
                radius: Theme.cornerRadiusSmall
                color: Theme.primary
                StyledText {
                    anchors.centerIn: parent
                    text: "💾 保存配置"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                    color: Theme.primaryText
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var pId = modal.providerId.trim().toLowerCase();
                        if (!pId) {
                            modal.testResult = "❌ Provider ID 不能为空";
                            return;
                        }
                        var pObj = {
                            "id": pId,
                            "name": modal.providerName.trim() || pId,
                            "baseUrl": modal.providerBaseUrl.trim(),
                            "apiKey": modal.providerApiKey.trim(),
                            "enabled": true,
                            "icon": modal.providerIcon,
                            "color": modal.providerColor,
                            "models": []
                        };
                        if (modal.providerStore) {
                            modal.providerStore.saveProvider(pObj);
                        }
                        modal.saved(pObj);
                        modal.closed();
                    }
                }
            }
        }
    }
}
