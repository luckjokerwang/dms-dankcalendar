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
    property var presetList: []
    property string activeProviderId: "agnes"
    property string activeModelId: "agnes-2.5-flash"

    // Modal Dialog State (OpenCode Style)
    property bool showProviderModal: false
    property bool isEditingProvider: false
    property string modalProviderId: ""
    property string modalProviderName: ""
    property string modalProviderBaseUrl: ""
    property string modalProviderProtocol: "openai-completions"
    property string modalProviderApiKey: ""
    property string modalProviderIcon: "smart_toy"
    property string modalProviderColor: "#1565c0"
    property bool modalIsTesting: false
    property string modalTestResult: ""
    property bool modalTestSuccess: false

    function reloadProviders() {
        var script = providerScriptPath || "provider-manager"
        listProc.command = [script, "list"]
        listProc.running = true

        presetsProc.command = [script, "get-presets"]
        presetsProc.running = true
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
                        if (res.data.activeProvider) root.activeProviderId = res.data.activeProvider
                        if (res.data.activeModel) root.activeModelId = res.data.activeModel
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: presetsProc
        command: []
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                var trimmed = line.trim()
                if (!trimmed) return
                try {
                    var res = JSON.parse(trimmed)
                    if (res.status === "ok" && res.presets) {
                        root.presetList = res.presets
                    }
                } catch(e) {}
            }
        }
    }

    function openAddCustomProvider() {
        isEditingProvider = false
        modalProviderId = ""
        modalProviderName = ""
        modalProviderBaseUrl = "https://"
        modalProviderProtocol = "openai-completions"
        modalProviderApiKey = ""
        modalProviderIcon = "tune"
        modalProviderColor = "#546e7a"
        modalTestResult = ""
        modalTestSuccess = false
        showProviderModal = true
    }

    function openEditProvider(p) {
        if (!p) return
        isEditingProvider = true
        modalProviderId = p.id
        modalProviderName = p.name || p.id
        modalProviderBaseUrl = p.baseUrl || ""
        modalProviderProtocol = p.protocol || "openai-completions"
        modalProviderApiKey = p.apiKey || ""
        modalProviderIcon = p.icon || "smart_toy"
        modalProviderColor = p.color || "#1565c0"
        modalTestResult = ""
        modalTestSuccess = false
        showProviderModal = true
    }

    function openAddPreset(preset) {
        if (!preset) return
        // Check if already in allProviders
        for (var i = 0; i < allProviders.length; i++) {
            if (allProviders[i].id === preset.id) {
                openEditProvider(allProviders[i])
                return
            }
        }
        isEditingProvider = false
        modalProviderId = preset.id
        modalProviderName = preset.name
        modalProviderBaseUrl = preset.baseUrl
        modalProviderProtocol = "openai-completions"
        modalProviderApiKey = ""
        modalProviderIcon = preset.icon || "smart_toy"
        modalProviderColor = preset.color || "#1565c0"
        modalTestResult = ""
        modalTestSuccess = false
        showProviderModal = true
    }

    function saveAndTestFromModal() {
        var pId = modalProviderId.trim().toLowerCase()
        if (!pId) {
            modalTestResult = "❌ Provider ID 不能为空"
            modalTestSuccess = false
            return
        }
        var pName = modalProviderName.trim() || pId
        var pUrl = modalProviderBaseUrl.trim()
        if (!pUrl) {
            modalTestResult = "❌ API 地址不能为空"
            modalTestSuccess = false
            return
        }
        var pKey = modalProviderApiKey.trim()

        var newProv = {
            "id": pId,
            "name": pName,
            "baseUrl": pUrl,
            "apiKey": pKey,
            "enabled": true,
            "icon": modalProviderIcon,
            "color": modalProviderColor,
            "models": []
        }

        // Preserve existing models if editing
        if (isEditingProvider) {
            for (var i = 0; i < allProviders.length; i++) {
                if (allProviders[i].id === pId && allProviders[i].models) {
                    newProv.models = allProviders[i].models
                    break
                }
            }
        }

        var script = providerScriptPath || "provider-manager"
        saveModalProc.command = [script, "save-provider", JSON.stringify(newProv)]
        saveModalProc.running = true

        if (pKey || pId === "ollama") {
            modalIsTesting = true
            modalTestResult = "⏳ 正在保存并连接端点动态拉取模型..."
            modalFetchProc.command = [script, "fetch-models", pId]
            modalFetchProc.running = true
        } else {
            modalTestResult = "💾 配置已保存 (未填 Key，模型列表未同步)"
            modalTestSuccess = true
            root.reloadProviders()
        }
    }

    Process {
        id: saveModalProc
        command: []
        running: false
    }

    Process {
        id: modalFetchProc
        command: []
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                var trimmed = line.trim()
                if (!trimmed) return
                try {
                    var res = JSON.parse(trimmed)
                    if (res.status === "ok") {
                        root.modalTestSuccess = true
                        root.modalTestResult = "🟢 连通正常 (" + (res.latency || 0) + "ms) · 成功拉取 " + (res.count || 0) + " 个模型"
                        root.reloadProviders()
                    } else {
                        root.modalTestSuccess = false
                        root.modalTestResult = "❌ " + (res.message || "拉取失败")
                    }
                } catch(e) {
                    root.modalTestSuccess = false
                    root.modalTestResult = "❌ 解析响应失败: " + e.message
                }
                root.modalIsTesting = false
            }
        }
        onExited: (code) => {
            root.modalIsTesting = false
        }
    }

    function deleteProvider(pId) {
        if (!pId) return
        var script = providerScriptPath || "provider-manager"
        delProvProc.command = [script, "delete-provider", pId]
        delProvProc.running = true
    }

    Process {
        id: delProvProc
        command: []
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                root.reloadProviders()
            }
        }
    }

    function setAsPrimaryProvider(pId, mId) {
        var script = providerScriptPath || "provider-manager"
        if (mId) {
            setActiveProc.command = [script, "set-active", pId, mId]
        } else {
            setActiveProc.command = [script, "set-active", pId]
        }
        setActiveProc.running = true
    }

    Process {
        id: setActiveProc
        command: []
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                root.reloadProviders()
            }
        }
    }

    function quickFetchModels(pId) {
        var script = providerScriptPath || "provider-manager"
        quickFetchProc.command = [script, "fetch-models", pId]
        quickFetchProc.running = true
    }

    Process {
        id: quickFetchProc
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
        // 1. AI 动态服务商与模型管理中心 (OpenCode 架构)
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

                // 1. Header & Add Custom Provider Button
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
                            text: "🤖 AI 大模型服务商管理 (OpenCode 规范)"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: "统一凭证管理 · 点击服务商填写 API Key 并自动拉取官方最新模型"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }

                    // ➕ 添加自定义提供方按钮
                    StyledRect {
                        implicitWidth: addCustomBtnRow.implicitWidth + Theme.spacingM * 2
                        implicitHeight: 32
                        radius: 8
                        color: Theme.primary

                        RowLayout {
                            id: addCustomBtnRow
                            anchors.centerIn: parent
                            spacing: 4

                            DankIcon { name: "add"; size: 16; color: "#ffffff" }
                            StyledText {
                                text: "添加自定义提供方"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Bold
                                color: "#ffffff"
                            }
                        }

                        HoverHandler { id: addCustomHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openAddCustomProvider()
                        }
                    }
                }

                // 2. Preset Quick-Add Pills (DeepSeek, OpenAI, Claude, Ollama, etc.)
                Column {
                    width: parent.width
                    spacing: 4

                    StyledText {
                        text: "预置大厂快捷配置 (点击即可调起配置表单并填 Key):"
                        font.pixelSize: 11
                        color: Theme.surfaceVariantText
                    }

                    Flow {
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: root.presetList
                            delegate: StyledRect {
                                required property var modelData
                                readonly property bool isConfigured: {
                                    for (var i = 0; i < root.allProviders.length; i++) {
                                        if (root.allProviders[i].id === modelData.id) {
                                            return !!(root.allProviders[i].apiKey || modelData.id === "ollama")
                                        }
                                    }
                                    return false
                                }

                                implicitWidth: preChipRow.implicitWidth + Theme.spacingM * 2
                                implicitHeight: 28
                                radius: 6
                                color: preChipHover.hovered ? Theme.surfaceContainerHighest : Theme.surfaceContainerLowest
                                border.width: 1
                                border.color: isConfigured ? "#2e7d32" : Theme.outlineVariant

                                RowLayout {
                                    id: preChipRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    DankIcon {
                                        name: modelData.icon || "smart_toy"
                                        size: 13
                                        color: modelData.color || Theme.primary
                                    }

                                    StyledText {
                                        text: modelData.name
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        text: isConfigured ? "🟢" : "⚪"
                                        font.pixelSize: 8
                                    }
                                }

                                HoverHandler { id: preChipHover }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openAddPreset(modelData)
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

                // 3. Configured Providers Card Stream
                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        text: "已接入的服务商列表 (" + root.allProviders.length + " 个):"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                    }

                    Repeater {
                        model: root.allProviders
                        delegate: StyledRect {
                            required property var modelData
                            readonly property bool isPrimary: (root.activeProviderId === modelData.id)
                            readonly property bool hasKey: !!(modelData.apiKey && modelData.apiKey.trim().length > 0) || modelData.id === "ollama"
                            readonly property int modelCount: (modelData.models ? modelData.models.length : 0)

                            width: providerCol.width
                            implicitHeight: pCardCol.implicitHeight + Theme.spacingM * 2
                            radius: 10
                            color: isPrimary ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                            border.width: isPrimary ? 2 : 1
                            border.color: isPrimary ? Theme.primary : Theme.outlineVariant

                            ColumnLayout {
                                id: pCardCol
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingS

                                // Top row: Icon + Name + Badge + Actions
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingS

                                    // Avatar Icon
                                    StyledRect {
                                        implicitWidth: 32
                                        implicitHeight: 32
                                        radius: 8
                                        color: modelData.color || Theme.primary

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: modelData.icon || "smart_toy"
                                            size: 18
                                            color: "#ffffff"
                                        }
                                    }

                                    // Name & URL
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        RowLayout {
                                            spacing: Theme.spacingS

                                            StyledText {
                                                text: modelData.name || modelData.id
                                                font.pixelSize: Theme.fontSizeMedium * 0.95
                                                font.weight: Font.Bold
                                                color: Theme.surfaceText
                                            }

                                            StyledText {
                                                text: "(" + modelData.id + ")"
                                                font.pixelSize: 11
                                                color: Theme.surfaceVariantText
                                            }

                                            // Status Badge
                                            StyledRect {
                                                implicitWidth: stBadgeText.implicitWidth + 8
                                                implicitHeight: 18
                                                radius: 4
                                                color: hasKey ? Qt.rgba(46/255, 125/255, 50/255, 0.15) : Qt.rgba(198/255, 40/255, 40/255, 0.15)

                                                StyledText {
                                                    id: stBadgeText
                                                    anchors.centerIn: parent
                                                    text: hasKey ? ("🟢 已配置 · " + modelCount + " 个模型") : "⚪ 未配置 Key"
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                    color: hasKey ? "#2e7d32" : "#c62828"
                                                }
                                            }

                                            // Primary Star
                                            StyledRect {
                                                visible: isPrimary
                                                implicitWidth: priBadgeText.implicitWidth + 8
                                                implicitHeight: 18
                                                radius: 4
                                                color: Theme.primary

                                                StyledText {
                                                    id: priBadgeText
                                                    anchors.centerIn: parent
                                                    text: "★ 主力服务商"
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                    color: "#ffffff"
                                                }
                                            }
                                        }

                                        StyledText {
                                            text: modelData.baseUrl || "默认端点"
                                            font.pixelSize: 11
                                            color: Theme.surfaceVariantText
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }
                                    }

                                    // Action: Set Primary
                                    StyledRect {
                                        visible: !isPrimary && hasKey
                                        implicitWidth: setPriText.implicitWidth + 12
                                        implicitHeight: 28
                                        radius: 6
                                        color: setPriHover.hovered ? Theme.surfaceContainerHighest : Theme.surfaceContainerLowest
                                        border.width: 1
                                        border.color: Theme.outlineVariant

                                        StyledText {
                                            id: setPriText
                                            anchors.centerIn: parent
                                            text: "设为主力"
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            color: Theme.primary
                                        }
                                        HoverHandler { id: setPriHover }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.setAsPrimaryProvider(modelData.id)
                                        }
                                    }

                                    // Action: Quick Sync Models
                                    StyledRect {
                                        visible: hasKey
                                        implicitWidth: 30
                                        implicitHeight: 28
                                        radius: 6
                                        color: syncHov.hovered ? Theme.surfaceContainerHighest : Theme.surfaceContainerLowest
                                        border.width: 1
                                        border.color: Theme.outlineVariant

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "bolt"
                                            size: 15
                                            color: Theme.primary
                                        }
                                        HoverHandler { id: syncHov }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.quickFetchModels(modelData.id)
                                        }
                                    }

                                    // Action: Edit / Configure Key Button
                                    StyledRect {
                                        implicitWidth: editBtnText.implicitWidth + 14
                                        implicitHeight: 28
                                        radius: 6
                                        color: hasKey ? (editHover.hovered ? Theme.surfaceContainerHighest : Theme.surfaceContainerLowest) : Theme.primary
                                        border.width: hasKey ? 1 : 0
                                        border.color: Theme.outlineVariant

                                        RowLayout {
                                            id: editBtnText
                                            anchors.centerIn: parent
                                            spacing: 3
                                            DankIcon {
                                                name: hasKey ? "settings" : "key"
                                                size: 13
                                                color: hasKey ? Theme.surfaceText : "#ffffff"
                                            }
                                            StyledText {
                                                text: hasKey ? "编辑" : "配置 Key"
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                color: hasKey ? Theme.surfaceText : "#ffffff"
                                            }
                                        }

                                        HoverHandler { id: editHover }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.openEditProvider(modelData)
                                        }
                                    }

                                    // Action: Delete Provider (if not default)
                                    StyledRect {
                                        visible: modelData.id !== "agnes" && root.allProviders.length > 1
                                        implicitWidth: 28
                                        implicitHeight: 28
                                        radius: 6
                                        color: delHov.hovered ? Qt.rgba(1, 0, 0, 0.15) : "transparent"

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "delete"
                                            size: 15
                                            color: "#d32f2f"
                                        }
                                        HoverHandler { id: delHov }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.deleteProvider(modelData.id)
                                        }
                                    }
                                }

                                // Models Tags Flow (Click to activate)
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    visible: modelCount > 0

                                    Repeater {
                                        model: modelData.models || []
                                        delegate: StyledRect {
                                            required property var modelData
                                            readonly property bool isCurrentModel: (isPrimary && root.activeModelId === modelData.id)

                                            implicitWidth: mChipRow.implicitWidth + Theme.spacingS * 2
                                            implicitHeight: 24
                                            radius: 6
                                            color: isCurrentModel ? Theme.primaryContainer : mChipHov.hovered ? Theme.surfaceContainerHighest : Theme.surfaceContainerLowest
                                            border.width: isCurrentModel ? 2 : 1
                                            border.color: isCurrentModel ? Theme.primary : Theme.outlineVariant

                                            RowLayout {
                                                id: mChipRow
                                                anchors.centerIn: parent
                                                spacing: 3

                                                DankIcon {
                                                    name: isCurrentModel ? "check" : "smart_toy"
                                                    size: 11
                                                    color: isCurrentModel ? Theme.primary : Theme.surfaceVariantText
                                                }

                                                StyledText {
                                                    text: modelData.name || modelData.id
                                                    font.pixelSize: 10
                                                    font.weight: isCurrentModel ? Font.Bold : Font.Normal
                                                    color: isCurrentModel ? Theme.onPrimaryContainer : Theme.surfaceText
                                                }
                                            }

                                            HoverHandler { id: mChipHov }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.setAsPrimaryProvider(pCardCol.parent.modelData.id, modelData.id)
                                            }
                                        }
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

    // =========================================================
    // 3. OpenCode 风格「自定义 / 预设提供方」模态弹窗 (Modal Dialog)
    // =========================================================
    Rectangle {
        id: modalMask
        visible: root.showProviderModal
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        z: 999

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (!root.modalIsTesting) {
                    root.showProviderModal = false
                }
            }
        }

        StyledRect {
            id: modalCard
            anchors.centerIn: parent
            width: Math.min(parent.width - 32, 460)
            implicitHeight: modalFormCol.implicitHeight + Theme.spacingL * 2
            radius: 16
            color: Theme.surfaceContainerHighest
            border.width: 1
            border.color: Theme.outlineVariant

            MouseArea {
                anchors.fill: parent
                // prevent click through
            }

            ColumnLayout {
                id: modalFormCol
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingS

                    DankIcon {
                        name: "hub"
                        size: 20
                        color: Theme.primary
                    }

                    StyledText {
                        text: root.isEditingProvider ? ("配置提供方: " + root.modalProviderName) : "自定义提供方 (Custom Provider)"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                    }

                    Item { Layout.fillWidth: true }

                    StyledRect {
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: 13
                        color: closeMHover.hovered ? Theme.surfaceContainerHigh : "transparent"
                        DankIcon {
                            anchors.centerIn: parent
                            name: "close"
                            size: 16
                            color: Theme.surfaceVariantText
                        }
                        HoverHandler { id: closeMHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showProviderModal = false
                        }
                    }
                }

                // 1. Provider ID
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: "Provider ID"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                    }

                    DankTextField {
                        id: mIdField
                        Layout.fillWidth: true
                        text: root.modalProviderId
                        readOnly: root.isEditingProvider
                        placeholderText: "acme-gateway"
                        onTextChanged: root.modalProviderId = text
                    }

                    StyledText {
                        text: "以小写字母开头的标识，在请求中唯一标识该提供方，并用于派生凭据名。"
                        font.pixelSize: 10
                        color: Theme.surfaceVariantText
                    }
                }

                // 2. 显示名称
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: "显示名称"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                    }

                    DankTextField {
                        id: mNameField
                        Layout.fillWidth: true
                        text: root.modalProviderName
                        placeholderText: "例如: SiliconFlow 硅基流动 / Agnes AI"
                        onTextChanged: root.modalProviderName = text
                    }
                }

                // 3. API 地址
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: "API 地址"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                    }

                    DankTextField {
                        id: mUrlField
                        Layout.fillWidth: true
                        text: root.modalProviderBaseUrl
                        placeholderText: "https://api.openai.com/v1"
                        onTextChanged: root.modalProviderBaseUrl = text
                    }
                }

                // 4. API 协议
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: "API 协议"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                    }

                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: 36
                        radius: 8
                        color: Theme.surfaceContainerLowest
                        border.width: 1
                        border.color: Theme.outlineVariant

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingM
                            anchors.rightMargin: Theme.spacingM

                            StyledText {
                                text: "openai-completions (OpenAI 兼容协议)"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }

                            Item { Layout.fillWidth: true }

                            DankIcon {
                                name: "expand_more"
                                size: 16
                                color: Theme.surfaceVariantText
                            }
                        }
                    }
                }

                // 5. API 密钥
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: "API 密钥"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        DankTextField {
                            id: mKeyField
                            Layout.fillWidth: true
                            text: root.modalProviderApiKey
                            placeholderText: "sk-..."
                            echoMode: mShowKeyBtn.showKey ? TextInput.Normal : TextInput.Password
                            onTextChanged: root.modalProviderApiKey = text
                        }

                        StyledRect {
                            id: mShowKeyBtn
                            property bool showKey: false
                            implicitWidth: 36
                            implicitHeight: 36
                            radius: 8
                            color: mShowKeyHover.hovered ? Theme.surfaceContainerHigh : "transparent"

                            DankIcon {
                                anchors.centerIn: parent
                                name: mShowKeyBtn.showKey ? "visibility_off" : "visibility"
                                size: 18
                                color: Theme.surfaceVariantText
                            }

                            HoverHandler { id: mShowKeyHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mShowKeyBtn.showKey = !mShowKeyBtn.showKey
                            }
                        }
                    }
                }

                // Status message inside modal
                StyledText {
                    visible: !!root.modalTestResult
                    Layout.fillWidth: true
                    text: root.modalTestResult
                    font.pixelSize: 11
                    color: root.modalTestSuccess ? "#2e7d32" : "#c62828"
                    wrapMode: Text.WrapAnywhere
                }

                // Action Buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM
                    Layout.topMargin: Theme.spacingS

                    StyledRect {
                        implicitWidth: 80
                        implicitHeight: 34
                        radius: 8
                        color: cancelMHover.hovered ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
                        border.width: 1
                        border.color: Theme.outlineVariant

                        StyledText {
                            anchors.centerIn: parent
                            text: "取消"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                        }

                        HoverHandler { id: cancelMHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showProviderModal = false
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Save & Test Button
                    StyledRect {
                        implicitWidth: saveMBtnRow.implicitWidth + Theme.spacingM * 2
                        implicitHeight: 34
                        radius: 8
                        color: root.modalIsTesting ? Theme.surfaceContainerHighest : Theme.primary

                        RowLayout {
                            id: saveMBtnRow
                            anchors.centerIn: parent
                            spacing: 4

                            DankIcon {
                                name: root.modalIsTesting ? "sync" : "bolt"
                                size: 16
                                color: "#ffffff"
                            }

                            StyledText {
                                text: root.modalIsTesting ? "正在拉取模型..." : "💾 保存并测试拉取模型"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Bold
                                color: "#ffffff"
                            }
                        }

                        HoverHandler { id: saveMHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: !root.modalIsTesting
                            onClicked: root.saveAndTestFromModal()
                        }
                    }
                }
            }
        }
    }
}
