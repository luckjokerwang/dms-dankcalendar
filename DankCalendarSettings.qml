import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root

    pluginId: "dankCalendarPlus"

    property var fetchedModels: []
    property bool isTestingApi: false
    property string testResultStatus: ""
    property string testResultMessage: ""

    property string aiScriptPath: Qt.resolvedUrl("./ai-client").toString().replace(/^file:\/\//, "")

    Process {
        id: testProc
        command: []
        running: false

        stdout: StdioCollector {
            onDataChanged: {
                try {
                    var res = JSON.parse(value.trim())
                    if (res.status === "ok") {
                        root.testResultStatus = "success"
                        root.fetchedModels = res.models || []
                        root.testResultMessage = "连接成功！发现 " + root.fetchedModels.length + " 个可用模型"
                    } else {
                        root.testResultStatus = "error"
                        root.testResultMessage = res.message || "连接失败"
                    }
                } catch(e) {
                    root.testResultStatus = "error"
                    root.testResultMessage = "解析响应失败: " + e.message
                }
                root.isTestingApi = false
            }
        }

        onExited: (code) => {
            root.isTestingApi = false
        }
    }

    function testAndFetchModels() {
        var url = (root.loadValue("aiBaseUrl", "https://apihub.agnes-ai.com/v1")).trim()
        var key = (root.loadValue("aiApiKey", "")).trim()
        if (!key) {
            testResultStatus = "error"
            testResultMessage = "请先输入 API Key"
            return
        }
        isTestingApi = true
        testResultStatus = "testing"
        testResultMessage = "正在测试连接并拉取模型..."
        fetchedModels = []

        var script = aiScriptPath || "ai-client"
        testProc.command = [script, "test", url, key]
        testProc.running = true
    }

    function applyProviderPreset(name) {
        if (name === "Agnes AI") {
            root.saveValue("aiBaseUrl", "https://apihub.agnes-ai.com/v1")
            root.saveValue("aiModel", "agnes-2.5-flash")
        } else if (name === "DeepSeek") {
            root.saveValue("aiBaseUrl", "https://api.deepseek.com/v1")
            root.saveValue("aiModel", "deepseek-chat")
        } else if (name === "OpenAI") {
            root.saveValue("aiBaseUrl", "https://api.openai.com/v1")
            root.saveValue("aiModel", "gpt-4o-mini")
        } else if (name === "Google Gemini") {
            root.saveValue("aiBaseUrl", "https://generativelanguage.googleapis.com/v1beta/openai/")
            root.saveValue("aiModel", "gemini-2.5-flash")
        } else if (name === "Ollama (本地)") {
            root.saveValue("aiBaseUrl", "http://localhost:11434/v1")
            root.saveValue("aiApiKey", "ollama")
            root.saveValue("aiModel", "llama3.2")
        }
    }

    SelectionSetting {
        settingKey: "pillDisplayMode"
        label: "Pill Display Mode"
        options: [
            { "label": "Full (Title + Countdown)", "value": "full" },
            { "label": "Title Only", "value": "titleOnly" },
            { "label": "Countdown Only", "value": "countdownOnly" },
            { "label": "Icon Only", "value": "iconOnly" }
        ]
        defaultValue: "full"
    }

    ToggleSetting {
        settingKey: "scrollTitle"
        label: "Scroll Long Titles"
        defaultValue: true
    }

    SliderSetting {
        settingKey: "pillMaxWidth"
        label: "Pill Maximum Width"
        defaultValue: 160
        minimum: 80
        maximum: 400
        stepSize: 10
        unit: "px"
    }

    ToggleSetting {
        settingKey: "dynamicWidth"
        label: "Dynamic Pill Width"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "showTooltip"
        label: "Show Next Event Tooltip"
        defaultValue: true
    }

    SliderSetting {
        settingKey: "agendaPastDays"
        label: "Past Days in Agenda"
        defaultValue: 7
        minimum: 0
        maximum: 30
        stepSize: 1
        unit: "天"
    }

    SliderSetting {
        settingKey: "agendaFutureDays"
        label: "Future Days in Agenda"
        defaultValue: 30
        minimum: 7
        maximum: 90
        stepSize: 7
        unit: "天"
    }

    SliderSetting {
        settingKey: "refreshInterval"
        label: "Poll Interval"
        defaultValue: 30
        minimum: 10
        maximum: 300
        stepSize: 5
        unit: "秒"
    }

    // AI Assistant Configuration Section
    Item {
        width: parent ? parent.width : 400
        implicitHeight: aiSettingsCol.implicitHeight + Theme.spacingM * 2

        Column {
            id: aiSettingsCol
            width: parent.width
            spacing: Theme.spacingM

            StyledText {
                text: "🤖 AI Assistant 排程智能体设置"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold
                color: Theme.primary
            }

            StyledText {
                width: parent.width
                text: "支持 OpenAI 兼容 API。预设了主流大模型服务商，支持一键测通并拉取模型列表。"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

            // Presets
            Column {
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: "快速选择主流厂商预设:"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                Flow {
                    width: parent.width
                    spacing: Theme.spacingS

                    Repeater {
                        model: ["Agnes AI", "DeepSeek", "OpenAI", "Google Gemini", "Ollama (本地)"]
                        delegate: StyledRect {
                            required property string modelData
                            implicitWidth: pText.implicitWidth + Theme.spacingM * 2
                            implicitHeight: 28
                            radius: Theme.cornerRadiusSmall
                            color: pHover.hovered ? Theme.primaryContainer : Theme.surfaceContainerHigh

                            StyledText {
                                id: pText
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: Theme.fontSizeSmall * 0.9
                                font.weight: Font.Medium
                                color: pHover.hovered ? Theme.onPrimaryContainer : Theme.surfaceText
                            }

                            HoverHandler { id: pHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.applyProviderPreset(modelData)
                            }
                        }
                    }
                }
            }

            // API Base URL
            Column {
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: "API Base URL (接口地址)"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                DankTextField {
                    id: baseUrlField
                    width: parent.width
                    placeholderText: "https://apihub.agnes-ai.com/v1"
                    text: root.loadValue("aiBaseUrl", "https://apihub.agnes-ai.com/v1")
                    onTextChanged: root.saveValue("aiBaseUrl", text.trim())
                }
            }

            // API Key
            Column {
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: "API Key (密钥，保存在本地安全配置中)"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingS

                    DankTextField {
                        id: apiKeyField
                        Layout.fillWidth: true
                        placeholderText: "sk-..."
                        echoMode: showKeyBtn.showKey ? TextInput.Normal : TextInput.Password
                        text: root.loadValue("aiApiKey", "")
                        onTextChanged: root.saveValue("aiApiKey", text.trim())
                    }

                    StyledRect {
                        id: showKeyBtn
                        property bool showKey: false
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: 8
                        color: showKeyHover.hovered ? Theme.surfaceContainerHighest : "transparent"

                        DankIcon {
                            anchors.centerIn: parent
                            name: showKeyBtn.showKey ? "visibility_off" : "visibility"
                            size: 18
                            color: Theme.surfaceVariantText
                        }

                        HoverHandler { id: showKeyHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: showKeyBtn.showKey = !showKeyBtn.showKey
                        }
                    }
                }
            }

            // Test Connection & Fetch Models Button
            RowLayout {
                width: parent.width
                spacing: Theme.spacingM

                StyledRect {
                    implicitWidth: testBtnRow.implicitWidth + Theme.spacingM * 2
                    implicitHeight: 34
                    radius: Theme.cornerRadiusSmall
                    color: root.isTestingApi ? Theme.surfaceContainerHighest : Theme.primary

                    RowLayout {
                        id: testBtnRow
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS

                        DankIcon {
                            name: root.isTestingApi ? "sync" : "cloud_sync"
                            size: 16
                            color: "#ffffff"
                        }

                        StyledText {
                            text: root.isTestingApi ? "正在测试连接..." : "🔍 测试连接并拉取模型"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                            color: "#ffffff"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: !root.isTestingApi
                        onClicked: root.testAndFetchModels()
                    }
                }

                // Test Status Label
                StyledText {
                    Layout.fillWidth: true
                    text: root.testResultMessage
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: root.testResultStatus === "success" ? "#2e7d32" : root.testResultStatus === "error" ? "#c62828" : Theme.surfaceVariantText
                    elide: Text.ElideRight
                }
            }

            // Fetched Models Chips (If available)
            Column {
                width: parent.width
                spacing: Theme.spacingXS
                visible: root.fetchedModels.length > 0

                StyledText {
                    text: "已发现的可用模型 (点击一键选用):"
                    font.pixelSize: Theme.fontSizeSmall * 0.85
                    color: Theme.surfaceVariantText
                }

                Flow {
                    width: parent.width
                    spacing: Theme.spacingXS

                    Repeater {
                        model: root.fetchedModels
                        delegate: StyledRect {
                            required property string modelData
                            implicitWidth: mChipText.implicitWidth + Theme.spacingS * 2
                            implicitHeight: 24
                            radius: 6
                            color: (root.loadValue("aiModel", "") === modelData) ? Theme.primary : mChipHover.hovered ? Theme.surfaceContainerHighest : Theme.surfaceContainerLowest

                            StyledText {
                                id: mChipText
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: 11
                                font.weight: (root.loadValue("aiModel", "") === modelData) ? Font.Bold : Font.Normal
                                color: (root.loadValue("aiModel", "") === modelData) ? "#ffffff" : Theme.surfaceText
                            }

                            HoverHandler { id: mChipHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.saveValue("aiModel", modelData)
                                }
                            }
                        }
                    }
                }
            }

            // Model Name Input Field
            Column {
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: "当前生效模型 (Model Name)"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                DankTextField {
                    id: modelField
                    width: parent.width
                    placeholderText: "agnes-2.5-flash / deepseek-chat / gpt-4o-mini"
                    text: root.loadValue("aiModel", "agnes-2.5-flash")
                    onTextChanged: root.saveValue("aiModel", text.trim())
                }
            }
        }
    }
}
