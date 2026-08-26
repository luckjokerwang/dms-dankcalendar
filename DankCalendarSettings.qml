import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services

PluginSettings {
    id: root

    pluginId: "dankCalendarPlus"

    property string providerScriptPath: Qt.resolvedUrl("./provider-manager").toString().replace(/^file:\/\//, "")
    property var allProviders: []
    property string selectedProviderId: "agnes"
    property var currentProviderData: null

    property var fetchedModels: []
    property bool isTestingApi: false
    property string testResultStatus: ""
    property string testResultMessage: ""

    function reloadProviders() {
        var script = providerScriptPath || "provider-manager"
        listProc.command = [script, "list"]
        listProc.running = true
    }

    Component.onCompleted: {
        reloadProviders()
    }

    Process {
        id: listProc
        command: []
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                var trimmed = line.trim()
                if (!trimmed) return
                try {
                    var res = JSON.parse(trimmed)
                    if (res.status === "ok" && res.data) {
                        root.allProviders = res.data.providers || []
                        root.syncCurrentProvider(root.selectedProviderId)
                    }
                } catch(e) {}
            }
        }
    }

    function syncCurrentProvider(pId) {
        root.selectedProviderId = pId
        for (var i = 0; i < allProviders.length; i++) {
            if (allProviders[i].id === pId) {
                root.currentProviderData = allProviders[i]
                providerBaseUrlField.text = allProviders[i].baseUrl || ""
                providerKeyField.text = allProviders[i].apiKey || ""
                providerEnabledToggle.checked = allProviders[i].enabled ?? true
                return
            }
        }
        if (allProviders.length > 0) {
            root.currentProviderData = allProviders[0]
            root.selectedProviderId = allProviders[0].id
            providerBaseUrlField.text = allProviders[0].baseUrl || ""
            providerKeyField.text = allProviders[0].apiKey || ""
            providerEnabledToggle.checked = allProviders[0].enabled ?? true
        }
    }

    Process {
        id: testProc
        command: []
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                var trimmed = line.trim()
                if (!trimmed) return
                try {
                    var res = JSON.parse(trimmed)
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
        var url = providerBaseUrlField.text.trim()
        var key = providerKeyField.text.trim()
        if (!key) {
            testResultStatus = "error"
            testResultMessage = "请先输入 API Key"
            return
        }
        isTestingApi = true
        testResultStatus = "testing"
        testResultMessage = "正在测试连接并拉取模型列表..."
        fetchedModels = []

        var script = providerScriptPath || "provider-manager"
        testProc.command = [script, "test", url, key]
        testProc.running = true
    }

    function saveCurrentProvider() {
        if (!currentProviderData) return
        var updated = Object.assign({}, currentProviderData)
        updated.baseUrl = providerBaseUrlField.text.trim()
        updated.apiKey = providerKeyField.text.trim()
        updated.enabled = providerEnabledToggle.checked

        var script = providerScriptPath || "provider-manager"
        saveProc.command = [script, "save-provider", JSON.stringify(updated)]
        saveProc.running = true
    }

    Process {
        id: saveProc
        command: []
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                root.reloadProviders()
            }
        }
    }

    function addModelToCurrentProvider(modelId, modelName) {
        if (!modelId) return
        var script = providerScriptPath || "provider-manager"
        addModelProc.command = [script, "add-model", root.selectedProviderId, modelId, modelName || modelId]
        addModelProc.running = true
    }

    Process {
        id: addModelProc
        command: []
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                root.reloadProviders()
            }
        }
    }

    function deleteModelFromCurrentProvider(modelId) {
        if (!modelId) return
        var script = providerScriptPath || "provider-manager"
        delModelProc.command = [script, "delete-model", root.selectedProviderId, modelId]
        delModelProc.running = true
    }

    Process {
        id: delModelProc
        command: []
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                root.reloadProviders()
            }
        }
    }

    Column {
        id: mainSettingsCol
        width: parent ? parent.width : 400
        spacing: Theme.spacingL

        function loadValue(key, def) {
            return PluginService.loadPluginData(root.pluginId, key, def);
        }

        function saveValue(key, val) {
            PluginService.savePluginData(root.pluginId, key, val);
            PluginService.setGlobalVar(root.pluginId, key, val);
        }

        // ==========================================
        // 1. AI 多服务商与多模型统一管理卡片 (Cherry Studio 架构)
        // ==========================================
        Rectangle {
            width: parent.width
            height: providerCol.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1

            Column {
                id: providerCol
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                // Header
                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingS

                    DankIcon {
                        name: "hub"
                        size: 22
                        color: Theme.primary
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: "🤖 AI 大模型服务商与模型管理"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: "管理多厂家 (Agnes/DeepSeek/OpenAI/Ollama) API 与模型库。配置保存在 ~/.config/dms-ai/providers.json"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }
                }

                // Provider Selector Tabs / Chips
                Column {
                    width: parent.width
                    spacing: Theme.spacingXS

                    StyledText {
                        text: "选择要配置的服务商 (Provider):"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    Flow {
                        width: parent.width
                        spacing: Theme.spacingS

                        Repeater {
                            model: root.allProviders
                            delegate: StyledRect {
                                required property var modelData
                                readonly property bool isSelected: (root.selectedProviderId === modelData.id)

                                implicitWidth: pTabRow.implicitWidth + Theme.spacingM * 2
                                implicitHeight: 30
                                radius: 8
                                color: isSelected ? Theme.primary : pTabHover.hovered ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
                                border.width: 1
                                border.color: isSelected ? Theme.primary : Theme.outlineVariant

                                RowLayout {
                                    id: pTabRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    DankIcon {
                                        name: modelData.icon || "smart_toy"
                                        size: 14
                                        color: isSelected ? "#ffffff" : (modelData.color || Theme.primary)
                                    }

                                    StyledText {
                                        text: modelData.name
                                        font.pixelSize: Theme.fontSizeSmall * 0.95
                                        font.weight: isSelected ? Font.Bold : Font.Medium
                                        color: isSelected ? "#ffffff" : Theme.surfaceText
                                    }

                                    StyledText {
                                        text: "(" + (modelData.models ? modelData.models.length : 0) + ")"
                                        font.pixelSize: 10
                                        color: isSelected ? "#ffffff" : Theme.surfaceVariantText
                                    }
                                }

                                HoverHandler { id: pTabHover }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.syncCurrentProvider(modelData.id)
                                }
                            }
                        }
                    }
                }

                // Divider
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outlineVariant
                }

                // Current Provider Detail Form
                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: !!root.currentProviderData

                    // Provider Name & Enable Toggle
                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "服务商: " + (root.currentProviderData ? root.currentProviderData.name : "")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }

                        Item { Layout.fillWidth: true }

                        DankToggle {
                            id: providerEnabledToggle
                            text: "启用此服务商"
                            onToggled: isChecked => root.saveCurrentProvider()
                        }
                    }

                    // API Base URL
                    Column {
                        width: parent.width
                        spacing: 3

                        StyledText {
                            text: "API Base URL (接口地址)"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        DankTextField {
                            id: providerBaseUrlField
                            width: parent.width
                            placeholderText: "https://api.example.com/v1"
                        }
                    }

                    // API Key
                    Column {
                        width: parent.width
                        spacing: 3

                        StyledText {
                            text: "API Key (访问密钥)"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingS

                            DankTextField {
                                id: providerKeyField
                                Layout.fillWidth: true
                                placeholderText: "sk-..."
                                echoMode: showKeyBtn.showKey ? TextInput.Normal : TextInput.Password
                            }

                            StyledRect {
                                id: showKeyBtn
                                property bool showKey: false
                                implicitWidth: 34
                                implicitHeight: 34
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

                    // Action Buttons (Save & Test Connection)
                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM

                        // Save Button
                        StyledRect {
                            implicitWidth: saveBtnRow.implicitWidth + Theme.spacingM * 2
                            implicitHeight: 32
                            radius: 8
                            color: Theme.primary

                            RowLayout {
                                id: saveBtnRow
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS

                                DankIcon { name: "save"; size: 15; color: "#ffffff" }
                                StyledText { text: "保存此服务商配置"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: "#ffffff" }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.saveCurrentProvider()
                            }
                        }

                        // Test Connection Button
                        StyledRect {
                            implicitWidth: testBtnRow.implicitWidth + Theme.spacingM * 2
                            implicitHeight: 32
                            radius: 8
                            color: root.isTestingApi ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                            border.width: 1
                            border.color: Theme.outlineVariant

                            RowLayout {
                                id: testBtnRow
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS

                                DankIcon { name: root.isTestingApi ? "sync" : "cloud_sync"; size: 15; color: Theme.primary }
                                StyledText { text: root.isTestingApi ? "测试中..." : "🔍 测试连接并拉取模型"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.primary }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: !root.isTestingApi
                                onClicked: root.testAndFetchModels()
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.testResultMessage
                            font.pixelSize: Theme.fontSizeSmall
                            color: root.testResultStatus === "success" ? "#2e7d32" : root.testResultStatus === "error" ? "#c62828" : Theme.surfaceVariantText
                            elide: Text.ElideRight
                        }
                    }

                    // Fetched Models from Test Connection
                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        visible: root.fetchedModels.length > 0

                        StyledText {
                            text: "从接口拉取到的模型 (点击【+】一键添加至此服务商):"
                            font.pixelSize: 11
                            color: Theme.surfaceVariantText
                        }

                        Flow {
                            width: parent.width
                            spacing: Theme.spacingXS

                            Repeater {
                                model: root.fetchedModels
                                delegate: StyledRect {
                                    required property string modelData
                                    implicitWidth: fChipRow.implicitWidth + Theme.spacingS * 2
                                    implicitHeight: 24
                                    radius: 6
                                    color: fChipHover.hovered ? Theme.primaryContainer : Theme.surfaceContainerLowest
                                    border.width: 1
                                    border.color: Theme.outlineVariant

                                    RowLayout {
                                        id: fChipRow
                                        anchors.centerIn: parent
                                        spacing: 2
                                        DankIcon { name: "add"; size: 12; color: Theme.primary }
                                        StyledText { text: modelData; font.pixelSize: 11; color: Theme.surfaceText }
                                    }

                                    HoverHandler { id: fChipHover }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.addModelToCurrentProvider(modelData, modelData)
                                    }
                                }
                            }
                        }
                    }

                    // Configured Models under Current Provider
                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS

                        StyledText {
                            text: "已配置的模型列表 (Models List):"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        ColumnLayout {
                            width: parent.width
                            spacing: 4

                            Repeater {
                                model: (root.currentProviderData && root.currentProviderData.models) ? root.currentProviderData.models : []
                                delegate: StyledRect {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 32
                                    radius: 6
                                    color: Theme.surfaceContainerLowest
                                    border.width: 1
                                    border.color: Theme.outlineVariant

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Theme.spacingS
                                        anchors.rightMargin: Theme.spacingS
                                        spacing: Theme.spacingS

                                        DankIcon { name: "smart_toy"; size: 14; color: Theme.primary }
                                        StyledText { text: modelData.name || modelData.id; font.pixelSize: 11; font.weight: Font.Bold; color: Theme.surfaceText }
                                        StyledText { text: "(" + modelData.id + ")"; font.pixelSize: 10; color: Theme.surfaceVariantText }
                                        StyledText { Layout.fillWidth: true; text: modelData.desc ? "— " + modelData.desc : ""; font.pixelSize: 10; color: Theme.surfaceVariantText; elide: Text.ElideRight }

                                        DankIcon {
                                            name: "close"
                                            size: 14
                                            color: Theme.surfaceVariantText
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.deleteModelFromCurrentProvider(modelData.id)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Add Custom Model Row
                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingS

                        DankTextField {
                            id: newModelIdField
                            Layout.fillWidth: true
                            placeholderText: "输入新模型 ID (如 deepseek-v3 / qwen-max)"
                        }

                        StyledRect {
                            implicitWidth: addMRow.implicitWidth + Theme.spacingM * 2
                            implicitHeight: 32
                            radius: 6
                            color: Theme.primary

                            RowLayout {
                                id: addMRow
                                anchors.centerIn: parent
                                spacing: 2
                                DankIcon { name: "add"; size: 14; color: "#ffffff" }
                                StyledText { text: "添加模型"; font.pixelSize: 11; font.weight: Font.Bold; color: "#ffffff" }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var mId = newModelIdField.text.trim()
                                    if (mId) {
                                        root.addModelToCurrentProvider(mId, mId)
                                        newModelIdField.text = ""
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ==========================================
        // 2. 原版 Dank Calendar Agenda 完整设置卡片
        // ==========================================
        Rectangle {
            width: parent.width
            height: origCol.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1

            Column {
                id: origCol
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                StyledText {
                    text: "📅 Dank Calendar 原版日程与顶栏偏好"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                }

                StyledText {
                    text: "配置下一个日程倒计时、顶栏药丸宽度、滑动展示与日程跨度。"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                // 1. Refresh Interval
                Column {
                    width: parent.width
                    spacing: 4
                    RowLayout {
                        width: parent.width
                        StyledText { text: "刷新周期 (Refresh Interval)"; font.weight: Font.Medium; color: Theme.surfaceText }
                        Item { Layout.fillWidth: true }
                        StyledText { text: Math.round(refSlider.value) + " 秒"; color: Theme.primary; font.weight: Font.Bold }
                    }
                    StyledText { text: "从 dcal 轮询拉取最新日程事件的频率"; font.pixelSize: 11; color: Theme.surfaceVariantText }
                    DankSlider {
                        id: refSlider
                        width: parent.width
                        from: 10
                        to: 120
                        stepSize: 5
                        value: mainSettingsCol.loadValue("refreshInterval", 30)
                        onValueChanged: mainSettingsCol.saveValue("refreshInterval", Math.round(value))
                    }
                }

                // 2. Event Name Width
                Column {
                    width: parent.width
                    spacing: 4
                    RowLayout {
                        width: parent.width
                        StyledText { text: "事件名称宽度 (Event Name Width)"; font.weight: Font.Medium; color: Theme.surfaceText }
                        Item { Layout.fillWidth: true }
                        StyledText { text: Math.round(widthSlider.value) + " px"; color: Theme.primary; font.weight: Font.Bold }
                    }
                    StyledText { text: "顶栏 Pill 中日程标题的最大展示宽度"; font.pixelSize: 11; color: Theme.surfaceVariantText }
                    DankSlider {
                        id: widthSlider
                        width: parent.width
                        from: 80
                        to: 350
                        stepSize: 10
                        value: mainSettingsCol.loadValue("pillMaxWidth", 160)
                        onValueChanged: mainSettingsCol.saveValue("pillMaxWidth", Math.round(value))
                    }
                }

                // 3. Now Duration
                Column {
                    width: parent.width
                    spacing: 4
                    RowLayout {
                        width: parent.width
                        StyledText { text: "进行中状态时长 (Now Duration)"; font.weight: Font.Medium; color: Theme.surfaceText }
                        Item { Layout.fillWidth: true }
                        StyledText { text: Math.round(nowSlider.value) + " 分钟"; color: Theme.primary; font.weight: Font.Bold }
                    }
                    StyledText { text: "事件开始后显示为【Now 进行中】的时长 (设为 0 关闭)"; font.pixelSize: 11; color: Theme.surfaceVariantText }
                    DankSlider {
                        id: nowSlider
                        width: parent.width
                        from: 0
                        to: 30
                        stepSize: 1
                        value: mainSettingsCol.loadValue("nowWindowMinutes", 5)
                        onValueChanged: mainSettingsCol.saveValue("nowWindowMinutes", Math.round(value))
                    }
                }

                // 4. Agenda Days Back
                Column {
                    width: parent.width
                    spacing: 4
                    RowLayout {
                        width: parent.width
                        StyledText { text: "日程回溯天数 (Agenda: Days Back)"; font.weight: Font.Medium; color: Theme.surfaceText }
                        Item { Layout.fillWidth: true }
                        StyledText { text: Math.round(backSlider.value) + " 天"; color: Theme.primary; font.weight: Font.Bold }
                    }
                    StyledText { text: "弹窗日程视图中可向上回溯查看的历史天数"; font.pixelSize: 11; color: Theme.surfaceVariantText }
                    DankSlider {
                        id: backSlider
                        width: parent.width
                        from: 0
                        to: 90
                        stepSize: 1
                        value: mainSettingsCol.loadValue("agendaPastDays", 7)
                        onValueChanged: mainSettingsCol.saveValue("agendaPastDays", Math.round(value))
                    }
                }

                // 5. Agenda Days Ahead
                Column {
                    width: parent.width
                    spacing: 4
                    RowLayout {
                        width: parent.width
                        StyledText { text: "日程展望天数 (Agenda: Days Ahead)"; font.weight: Font.Medium; color: Theme.surfaceText }
                        Item { Layout.fillWidth: true }
                        StyledText { text: Math.round(aheadSlider.value) + " 天"; color: Theme.primary; font.weight: Font.Bold }
                    }
                    StyledText { text: "弹窗日程视图中向下加载的未来日程天数"; font.pixelSize: 11; color: Theme.surfaceVariantText }
                    DankSlider {
                        id: aheadSlider
                        width: parent.width
                        from: 7
                        to: 90
                        stepSize: 7
                        value: mainSettingsCol.loadValue("agendaFutureDays", 30)
                        onValueChanged: mainSettingsCol.saveValue("agendaFutureDays", Math.round(value))
                    }
                }

                // 6. Look Ahead
                Column {
                    width: parent.width
                    spacing: 4
                    RowLayout {
                        width: parent.width
                        StyledText { text: "前瞻检测天数 (Look Ahead Days)"; font.weight: Font.Medium; color: Theme.surfaceText }
                        Item { Layout.fillWidth: true }
                        StyledText { text: Math.round(lookSlider.value) + " 天"; color: Theme.primary; font.weight: Font.Bold }
                    }
                    StyledText { text: "顶栏 Pill 寻找下一个最近日程的向前扫描范围"; font.pixelSize: 11; color: Theme.surfaceVariantText }
                    DankSlider {
                        id: lookSlider
                        width: parent.width
                        from: 1
                        to: 14
                        stepSize: 1
                        value: mainSettingsCol.loadValue("lookAheadDays", 1)
                        onValueChanged: mainSettingsCol.saveValue("lookAheadDays", Math.round(value))
                    }
                }

                // Toggles
                DankToggle {
                    width: parent.width
                    text: "动态自适应药丸宽度 (Dynamic Width)"
                    description: "根据当前日程标题长度自适应药丸尺寸，而非固定宽度"
                    checked: mainSettingsCol.loadValue("dynamicWidth", false)
                    onToggled: isChecked => mainSettingsCol.saveValue("dynamicWidth", isChecked)
                }

                DankToggle {
                    width: parent.width
                    text: "悬浮提示气泡 (Hover Tooltip)"
                    description: "鼠标指针悬停在顶栏 Pill 时展示完整日程标题与时间"
                    checked: mainSettingsCol.loadValue("showTooltip", true)
                    onToggled: isChecked => mainSettingsCol.saveValue("showTooltip", isChecked)
                }

                DankToggle {
                    width: parent.width
                    text: "长标题平滑滚动 (Scroll Long Titles)"
                    description: "当日程标题超出 Pill 显示宽度时自动滚动循环展示"
                    checked: mainSettingsCol.loadValue("scrollTitle", true)
                    onToggled: isChecked => mainSettingsCol.saveValue("scrollTitle", isChecked)
                }
            }
        }
    }
}
