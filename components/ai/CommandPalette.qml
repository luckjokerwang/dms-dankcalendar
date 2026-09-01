import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    property string currentMode: "root" // "root" | "history" | "model" | "provider"
    property string searchQuery: ""
    property int selectedIndex: 0

    property var sessionList: []
    property var providerConfig: null

    signal selectSession(string sessionId)
    signal selectModel(string modelId, string providerId)
    signal selectProvider(string providerId)
    signal executeCommand(string cmd)
    signal closeRequested()

    implicitWidth: parent ? parent.width : 420
    
    // Explicit dynamic height: Header (34) + List (up to 4 items * 48) + Footer (26) + Margins (16)
    height: {
        var count = root.currentItems.length
        if (count === 0) return 110
        var visibleRows = Math.min(4, count)
        return 34 + visibleRows * 48 + 26 + Theme.spacingS * 2
    }

    color: Theme.surfaceContainerHighest
    radius: 12
    border.width: 1
    border.color: Theme.outlineVariant

    // Outer Glow / Drop Shadow
    StyledRect {
        anchors.fill: parent
        anchors.margins: -1
        z: -1
        radius: parent.radius + 1
        color: Qt.rgba(0, 0, 0, 0.35)
    }

    // Root commands definition
    readonly property var rootCommands: [
        {
            "id": "model",
            "cmd": "/model",
            "title": "切换大语言模型",
            "desc": "在所有已配置的服务商与动态模型中快速切换",
            "icon": "bolt",
            "color": Theme.primary,
            "badge": "Submenu"
        },
        {
            "id": "history",
            "cmd": "/history",
            "title": "切换历史会话",
            "desc": "键盘上下选择并载入过去的排程会话记录",
            "icon": "history",
            "color": "#1565c0",
            "badge": "Submenu"
        },
        {
            "id": "provider",
            "cmd": "/provider",
            "title": "切换 AI 服务商",
            "desc": "切换 DeepSeek / OpenAI / Claude / Ollama 主力服务商",
            "icon": "hub",
            "color": "#e65100",
            "badge": "Submenu"
        },
        {
            "id": "new",
            "cmd": "/new",
            "title": "开启全新排程会话",
            "desc": "清空当前上下文，开始新的对话规划",
            "icon": "add_comment",
            "color": "#2e7d32",
            "badge": "Action"
        },
        {
            "id": "clear",
            "cmd": "/clear",
            "title": "清空当前会话内容",
            "desc": "重置当前窗口的聊天记录",
            "icon": "delete_sweep",
            "color": "#c62828",
            "badge": "Action"
        },
        {
            "id": "help",
            "cmd": "/help",
            "title": "查看指令与快捷键指南",
            "desc": "显示排程系统支持的全部按键操作",
            "icon": "help_outline",
            "color": "#6a1b9a",
            "badge": "Info"
        }
    ]

    // Flatten all models across providers
    readonly property var allFlatModels: {
        var list = []
        if (!providerConfig || !providerConfig.providers) return list
        for (var i = 0; i < providerConfig.providers.length; i++) {
            var p = providerConfig.providers[i]
            var pModels = p.models || []
            for (var j = 0; j < pModels.length; j++) {
                var m = pModels[j]
                list.push({
                    "id": m.id,
                    "name": m.name || m.id,
                    "desc": m.desc || (p.name + " 实时模型"),
                    "vision": !!m.vision,
                    "providerId": p.id,
                    "providerName": p.name,
                    "providerIcon": p.icon || "smart_toy",
                    "providerColor": p.color || Theme.primary,
                    "isActive": (providerConfig.activeProvider === p.id && providerConfig.activeModel === m.id)
                })
            }
        }
        return list
    }

    // Active items to display based on currentMode & searchQuery
    readonly property var currentItems: {
        var query = searchQuery.trim().toLowerCase()
        var results = []

        if (currentMode === "root") {
            for (var i = 0; i < rootCommands.length; i++) {
                var c = rootCommands[i]
                if (!query || c.cmd.toLowerCase().includes(query) || c.id.toLowerCase().includes(query) || c.title.toLowerCase().includes(query) || c.desc.toLowerCase().includes(query)) {
                    results.push(c)
                }
            }
        } else if (currentMode === "history") {
            var sList = sessionList || []
            for (var j = 0; j < sList.length; j++) {
                var s = sList[j]
                var title = (s.title || "未命名会话").toLowerCase()
                if (!query || title.includes(query) || s.id.toLowerCase().includes(query)) {
                    results.push(s)
                }
            }
        } else if (currentMode === "model") {
            var mList = allFlatModels
            for (var k = 0; k < mList.length; k++) {
                var mItem = mList[k]
                var mId = mItem.id.toLowerCase()
                var pName = mItem.providerName.toLowerCase()
                if (!query || mId.includes(query) || pName.includes(query)) {
                    results.push(mItem)
                }
            }
        } else if (currentMode === "provider") {
            var pList = (providerConfig && providerConfig.providers) ? providerConfig.providers : []
            for (var l = 0; l < pList.length; l++) {
                var prov = pList[l]
                var pId = prov.id.toLowerCase()
                var pN = (prov.name || prov.id).toLowerCase()
                if (!query || pId.includes(query) || pN.includes(query)) {
                    results.push(prov)
                }
            }
        }
        return results
    }

    onCurrentItemsChanged: {
        if (selectedIndex >= currentItems.length) {
            selectedIndex = Math.max(0, currentItems.length - 1)
        }
    }

    function enterMode(mode, query) {
        currentMode = mode
        searchQuery = query || ""
        selectedIndex = 0
        if (itemList) {
            itemList.positionViewAtBeginning()
        }
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Up) {
            if (selectedIndex > 0) {
                selectedIndex--
                itemList.positionViewAtIndex(selectedIndex, ListView.Contain)
            }
            event.accepted = true
            return true
        } else if (event.key === Qt.Key_Down) {
            if (selectedIndex < currentItems.length - 1) {
                selectedIndex++
                itemList.positionViewAtIndex(selectedIndex, ListView.Contain)
            }
            event.accepted = true
            return true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Tab) {
            confirmSelection()
            event.accepted = true
            return true
        } else if (event.key === Qt.Key_Backspace) {
            if (searchQuery.length === 0 && currentMode !== "root") {
                enterMode("root")
                event.accepted = true
                return true
            }
            return false
        } else if (event.key === Qt.Key_Escape) {
            closeRequested()
            event.accepted = true
            return true
        }
        return false
    }

    function confirmSelection() {
        if (currentItems.length === 0 || selectedIndex < 0 || selectedIndex >= currentItems.length) return
        var item = currentItems[selectedIndex]

        if (currentMode === "root") {
            if (item.id === "history") {
                enterMode("history")
            } else if (item.id === "model") {
                enterMode("model")
            } else if (item.id === "provider") {
                enterMode("provider")
            } else {
                executeCommand(item.cmd)
                closeRequested()
            }
        } else if (currentMode === "history") {
            selectSession(item.id)
            closeRequested()
        } else if (currentMode === "model") {
            selectModel(item.id, item.providerId)
            closeRequested()
        } else if (currentMode === "provider") {
            selectProvider(item.id)
            closeRequested()
        }
    }

    ColumnLayout {
        id: pLayout
        anchors.fill: parent
        anchors.margins: Theme.spacingS
        spacing: 4

        // 1. Breadcrumb Header
        RowLayout {
            Layout.fillWidth: true
            implicitHeight: 26
            spacing: Theme.spacingS

            StyledRect {
                implicitWidth: bcrumbRow.implicitWidth + Theme.spacingS * 2
                implicitHeight: 22
                radius: 6
                color: Theme.surfaceContainerHigh

                RowLayout {
                    id: bcrumbRow
                    anchors.centerIn: parent
                    spacing: 4

                    DankIcon {
                        name: (currentMode === "history") ? "history" :
                              (currentMode === "model") ? "bolt" :
                              (currentMode === "provider") ? "hub" : "terminal"
                        size: 13
                        color: Theme.primary
                    }

                    StyledText {
                        text: (currentMode === "history") ? "指令 > 历史会话 (" + currentItems.length + ")" :
                              (currentMode === "model") ? "指令 > 切换模型 (" + currentItems.length + ")" :
                              (currentMode === "provider") ? "指令 > 切换服务商 (" + currentItems.length + ")" :
                              "⚡ 指令中心 (" + currentItems.length + ")"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: Theme.primary
                    }
                }
            }

            Item { Layout.fillWidth: true }

            StyledText {
                text: (currentMode !== "root") ? "按 Backspace 返回" : "输入关键词检索"
                font.pixelSize: 10
                color: Theme.surfaceVariantText
            }
        }

        // 2. Empty state or Items List
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Empty state placeholder
            StyledText {
                anchors.centerIn: parent
                visible: root.currentItems.length === 0
                text: "未找到匹配项 (按 Backspace 返回或按 Esc 关闭)"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            // Items List
            ListView {
                id: itemList
                anchors.fill: parent
                visible: root.currentItems.length > 0
                clip: true
                spacing: 4
                model: root.currentItems

                delegate: StyledRect {
                    id: itemDelegate
                    required property var modelData
                    required property int index

                    width: itemList.width
                    implicitHeight: 44
                    radius: 8
                    color: (root.selectedIndex === index) ? Theme.primary : (dHover.hovered ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest)
                    border.width: (root.selectedIndex === index) ? 1 : 0
                    border.color: Theme.primary

                    HoverHandler { id: dHover }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        // Icon / Provider Logo
                        StyledRect {
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: 6
                            color: (root.selectedIndex === index) ? Qt.rgba(255, 255, 255, 0.2) : Theme.surfaceContainerHighest

                            DankIcon {
                                anchors.centerIn: parent
                                name: (root.currentMode === "root") ? (modelData.icon || "code") :
                                      (root.currentMode === "history") ? "chat_bubble_outline" :
                                      (root.currentMode === "model") ? (modelData.providerIcon || "smart_toy") :
                                      (modelData.icon || "hub")
                                size: 15
                                color: (root.selectedIndex === index) ? "#ffffff" :
                                       ((root.currentMode === "model") ? (modelData.providerColor || Theme.primary) :
                                        (modelData.color || Theme.primary))
                            }
                        }

                        // Main Text & Subtitle
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingXS

                                StyledText {
                                    text: (root.currentMode === "root") ? (modelData.cmd + "  " + modelData.title) :
                                          (root.currentMode === "history") ? (modelData.title || "未命名会话") :
                                          (root.currentMode === "model") ? modelData.id :
                                          (modelData.name || modelData.id)
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Bold
                                    color: (root.selectedIndex === index) ? "#ffffff" : Theme.surfaceText
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    wrapMode: Text.NoWrap
                                }

                                // Model/Provider Badge
                                StyledRect {
                                    visible: root.currentMode === "model" && !!modelData.providerName
                                    implicitWidth: pNameText.implicitWidth + 8
                                    implicitHeight: 16
                                    radius: 4
                                    color: (root.selectedIndex === index) ? Qt.rgba(0,0,0,0.2) : Theme.surfaceContainerHighest

                                    StyledText {
                                        id: pNameText
                                        anchors.centerIn: parent
                                        text: modelData.providerName || ""
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                        color: (root.selectedIndex === index) ? "#ffffff" : (modelData.providerColor || Theme.primary)
                                    }
                                }

                                // Vision Badge
                                StyledRect {
                                    visible: root.currentMode === "model" && !!modelData.vision
                                    implicitWidth: vBadgeRow.implicitWidth + 8
                                    implicitHeight: 16
                                    radius: 4
                                    color: (root.selectedIndex === index) ? Qt.rgba(0,0,0,0.2) : Theme.withAlpha(Theme.primary, 0.15)

                                    RowLayout {
                                        id: vBadgeRow
                                        anchors.centerIn: parent
                                        spacing: 2
                                        DankIcon {
                                            name: "visibility"
                                            size: 10
                                            color: (root.selectedIndex === index) ? "#ffffff" : Theme.primary
                                        }
                                        StyledText {
                                            text: "视觉"
                                            font.pixelSize: 9
                                            font.weight: Font.Bold
                                            color: (root.selectedIndex === index) ? "#ffffff" : Theme.primary
                                        }
                                    }
                                }

                                StyledRect {
                                    visible: root.currentMode === "provider"
                                    implicitWidth: provStatusText.implicitWidth + 8
                                    implicitHeight: 16
                                    radius: 4
                                    color: (modelData.apiKey || modelData.id === "ollama") ? Qt.rgba(46/255, 125/255, 50/255, 0.2) : Qt.rgba(198/255, 40/255, 40/255, 0.2)

                                    StyledText {
                                        id: provStatusText
                                        anchors.centerIn: parent
                                        text: (modelData.apiKey || modelData.id === "ollama") ? "🟢 已配置" : "⚪ 未配置"
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                        color: (root.selectedIndex === index) ? "#ffffff" : ((modelData.apiKey || modelData.id === "ollama") ? "#2e7d32" : "#c62828")
                                    }
                                }
                            }

                            StyledText {
                                text: (root.currentMode === "root") ? modelData.desc :
                                      (root.currentMode === "history") ? ((modelData.updatedAt ? modelData.updatedAt.replace("T", " ").substring(0, 16) : "") + " · " + (modelData.messageCount || 0) + " 条消息") :
                                      (root.currentMode === "model") ? modelData.desc :
                                      ((modelData.apiKey || modelData.id === "ollama") ? ((modelData.models ? modelData.models.length : 0) + " 个可用模型 · " + (modelData.baseUrl || "")) : "未配置 API Key · 需前往设置配置")
                                font.pixelSize: 10
                                color: (root.selectedIndex === index) ? Qt.rgba(255, 255, 255, 0.8) : Theme.surfaceVariantText
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                wrapMode: Text.NoWrap
                            }
                        }

                        // Active status checkmark
                        DankIcon {
                            visible: (root.currentMode === "model" && !!modelData.isActive) ||
                                     (root.currentMode === "provider" && root.providerConfig && root.providerConfig.activeProvider === modelData.id)
                            name: "check"
                            size: 16
                            color: (root.selectedIndex === index) ? "#ffffff" : Theme.primary
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedIndex = index
                            root.confirmSelection()
                        }
                    }
                }
            }
        }

        // 3. Footer Key Hints
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 20
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                spacing: Theme.spacingS

                StyledText {
                    text: "[↑/↓] 导航"
                    font.pixelSize: 9
                    color: Theme.surfaceVariantText
                }
                StyledText {
                    text: "[Enter/Tab] 选择"
                    font.pixelSize: 9
                    color: Theme.surfaceVariantText
                }
                StyledText {
                    text: "[Backspace] 返回"
                    font.pixelSize: 9
                    color: Theme.surfaceVariantText
                }
                StyledText {
                    text: "[Esc] 关闭"
                    font.pixelSize: 9
                    color: Theme.surfaceVariantText
                }
            }
        }
    }
}
