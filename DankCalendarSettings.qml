import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services
import "./store"

PluginSettings {
    id: root

    pluginId: "dankCalendarPlus"

    ProviderStore {
        id: providerStore
    }

    // Provider Form Editing State
    property bool showEditForm: false
    property bool isEditingProvider: false
    property string editProviderId: ""
    property string editProviderName: ""
    property string editProviderBaseUrl: "https://"
    property string editProviderApiKey: ""
    property var editProviderFetchedModels: []
    property var editProviderSelectedModelIds: []
    property string customModelInput: ""
    property bool isTesting: false
    property string testResultText: ""
    property bool testSuccess: false

    Process {
        id: testModelsProc
        command: []
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var trimmed = (text || "").trim();
                if (!trimmed) return;
                try {
                    var res = JSON.parse(trimmed);
                    if (res.status === "ok") {
                        root.testResultText = "🟢 连接成功 (" + (res.latency || 0) + "ms) · 发现 " + (res.count || 0) + " 个模型";
                        root.testSuccess = true;
                        var fetched = res.models || [];
                        root.editProviderFetchedModels = fetched;
                        var ids = [];
                        for (var i = 0; i < fetched.length; i++) {
                            ids.push(fetched[i].id);
                        }
                        root.editProviderSelectedModelIds = ids;
                    } else {
                        root.testResultText = "❌ " + (res.message || "连接失败");
                        root.testSuccess = false;
                    }
                } catch(e) {
                    root.testResultText = "❌ 解析响应失败: " + e;
                    root.testSuccess = false;
                }
                root.isTesting = false;
            }
        }
        onExited: (code) => {
            root.isTesting = false;
        }
    }

    function openAddCustomProvider() {
        isEditingProvider = false;
        editProviderId = "";
        editProviderName = "";
        editProviderBaseUrl = "https://";
        editProviderApiKey = "";
        editProviderFetchedModels = [];
        editProviderSelectedModelIds = [];
        customModelInput = "";
        testResultText = "";
        testSuccess = false;
        showEditForm = true;
    }

    function openEditProvider(p) {
        if (!p) return;
        isEditingProvider = true;
        editProviderId = p.id || "";
        editProviderName = p.name || "";
        editProviderBaseUrl = p.baseUrl || "https://";
        editProviderApiKey = p.apiKey || "";
        editProviderFetchedModels = p.models || [];
        var ids = [];
        for (var i = 0; i < (p.models || []).length; i++) {
            ids.push(p.models[i].id);
        }
        editProviderSelectedModelIds = ids;
        customModelInput = "";
        testResultText = "";
        testSuccess = false;
        showEditForm = true;
    }

    function openAddPreset(preset) {
        if (!preset) return;
        for (var i = 0; i < providerStore.allProviders.length; i++) {
            if (providerStore.allProviders[i].id === preset.id) {
                openEditProvider(providerStore.allProviders[i]);
                return;
            }
        }
        isEditingProvider = false;
        editProviderId = preset.id || "";
        editProviderName = preset.name || "";
        editProviderBaseUrl = preset.baseUrl || "https://";
        editProviderApiKey = "";
        editProviderFetchedModels = preset.models || [];
        var ids = [];
        for (var j = 0; j < (preset.models || []).length; j++) {
            ids.push(preset.models[j].id);
        }
        editProviderSelectedModelIds = ids;
        customModelInput = "";
        testResultText = "";
        testSuccess = false;
        showEditForm = true;
    }

    function isModelSelected(modelId) {
        return editProviderSelectedModelIds.indexOf(modelId) !== -1;
    }

    function toggleModelSelection(modelId) {
        var arr = editProviderSelectedModelIds.slice();
        var idx = arr.indexOf(modelId);
        if (idx !== -1) {
            arr.splice(idx, 1);
        } else {
            arr.push(modelId);
        }
        editProviderSelectedModelIds = arr;
    }

    function addCustomModel() {
        var mid = customModelInput.trim();
        if (!mid) return;
        var existing = false;
        for (var i = 0; i < editProviderFetchedModels.length; i++) {
            if (editProviderFetchedModels[i].id === mid) {
                existing = true;
                break;
            }
        }
        if (!existing) {
            var newModels = editProviderFetchedModels.concat([{
                "id": mid,
                "name": mid,
                "desc": "用户自定义模型"
            }]);
            editProviderFetchedModels = newModels;
        }
        if (editProviderSelectedModelIds.indexOf(mid) === -1) {
            editProviderSelectedModelIds = editProviderSelectedModelIds.concat([mid]);
        }
        customModelInput = "";
    }

    // ==========================================
    // 1. AI 动态服务商与模型管理中心
    // ==========================================
    Rectangle {
        width: parent.width
        implicitHeight: providerCol.implicitHeight + Theme.spacingM * 2
        color: Theme.surfaceContainer
        radius: Theme.cornerRadius
        border.color: Theme.outline
        border.width: 1

        Column {
            id: providerCol
            width: parent.width - Theme.spacingM * 2
            x: Theme.spacingM
            y: Theme.spacingM
            spacing: Theme.spacingM

            // Header & Add Custom Button
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
                        text: "统一凭证管理 · 填入 API Key 后一键拉取官方最新模型，支持按需勾选启用"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }

                Rectangle {
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
                            text: "添加服务商"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                            color: "#ffffff"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openAddCustomProvider()
                    }
                }
            }

            // Preset Pills
            Column {
                width: parent.width
                spacing: 6

                StyledText {
                    text: "主流厂商快速配置 (点击调出配置表单并填 Key):"
                    font.pixelSize: 11
                    color: Theme.surfaceVariantText
                }

                Flow {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: providerStore.presetList
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool isConfigured: {
                                for (var i = 0; i < providerStore.allProviders.length; i++) {
                                    if (providerStore.allProviders[i].id === modelData.id) {
                                        return !!(providerStore.allProviders[i].apiKey || modelData.id === "ollama");
                                    }
                                }
                                return false;
                            }

                            implicitWidth: presetRow.implicitWidth + 16
                            implicitHeight: 28
                            radius: 14
                            color: isConfigured ? Theme.withAlpha(Theme.primary, 0.15) : Theme.surfaceContainerHigh
                            border.width: 1
                            border.color: isConfigured ? Theme.primary : Theme.outlineVariant

                            RowLayout {
                                id: presetRow
                                anchors.centerIn: parent
                                spacing: 4

                                DankIcon {
                                    name: modelData.icon || "smart_toy"
                                    size: 14
                                    color: modelData.color || Theme.primary
                                }

                                StyledText {
                                    text: modelData.name
                                    font.pixelSize: 11
                                    color: Theme.surfaceText
                                }

                                StyledText {
                                    visible: isConfigured
                                    text: "✓"
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: Theme.primary
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openAddPreset(modelData)
                            }
                        }
                    }
                }
            }

            // Inline Edit / Add Form
            Rectangle {
                visible: root.showEditForm
                width: parent.width
                implicitHeight: visible ? (editFormCol.implicitHeight + Theme.spacingM * 2) : 0
                radius: Theme.cornerRadiusSmall
                color: Theme.surfaceContainerLowest
                border.width: 1
                border.color: Theme.primary

                Column {
                    id: editFormCol
                    width: parent.width - Theme.spacingM * 2
                    x: Theme.spacingM
                    y: Theme.spacingM
                    spacing: Theme.spacingS

                    RowLayout {
                        width: parent.width
                        StyledText {
                            text: root.isEditingProvider ? ("✏️ 编辑服务商: " + root.editProviderId) : "➕ 添加新服务商"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                            color: Theme.primary
                        }
                        Item { Layout.fillWidth: true }
                        DankActionButton {
                            iconName: "close"
                            onClicked: root.showEditForm = false
                        }
                    }

                    StyledText { text: "服务商 ID (英文小写标识):"; font.pixelSize: 11; color: Theme.surfaceVariantText }
                    DankTextField {
                        width: parent.width
                        text: root.editProviderId
                        placeholderText: "例如: sensenova / deepseek / siliconflow"
                        enabled: !root.isEditingProvider
                        onTextChanged: root.editProviderId = text
                    }

                    StyledText { text: "显示名称:"; font.pixelSize: 11; color: Theme.surfaceVariantText }
                    DankTextField {
                        width: parent.width
                        text: root.editProviderName
                        placeholderText: "例如: 商汤日日新 / DeepSeek 官方"
                        onTextChanged: root.editProviderName = text
                    }

                    StyledText { text: "API Base URL 地址:"; font.pixelSize: 11; color: Theme.surfaceVariantText }
                    DankTextField {
                        width: parent.width
                        text: root.editProviderBaseUrl
                        placeholderText: "https://api.openai.com/v1"
                        onTextChanged: root.editProviderBaseUrl = text
                    }

                    StyledText { text: "API Key (密匙):"; font.pixelSize: 11; color: Theme.surfaceVariantText }
                    DankTextField {
                        width: parent.width
                        text: root.editProviderApiKey
                        placeholderText: "sk-..."
                        echoMode: TextInput.Password
                        onTextChanged: root.editProviderApiKey = text
                    }

                    // Test Status and Latency Text
                    StyledText {
                        visible: !!root.testResultText
                        width: parent.width
                        text: root.testResultText
                        font.pixelSize: 11
                        color: root.testSuccess ? "#4caf50" : Theme.error
                        wrapMode: Text.Wrap
                    }

                    // Model Selection and Filtering Section
                    Column {
                        visible: root.editProviderFetchedModels.length > 0
                        width: parent.width
                        spacing: 6

                        RowLayout {
                            width: parent.width
                            StyledText {
                                text: "启用模型选择 (点击标签勾选或取消):"
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }
                            Item { Layout.fillWidth: true }
                            StyledText {
                                text: "全选"
                                font.pixelSize: 11
                                color: Theme.primary
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var ids = [];
                                        for (var i = 0; i < root.editProviderFetchedModels.length; i++) {
                                            ids.push(root.editProviderFetchedModels[i].id);
                                        }
                                        root.editProviderSelectedModelIds = ids;
                                    }
                                }
                            }
                            StyledText { text: "·"; font.pixelSize: 11; color: Theme.surfaceVariantText }
                            StyledText {
                                text: "清空"
                                font.pixelSize: 11
                                color: Theme.surfaceVariantText
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.editProviderSelectedModelIds = []
                                }
                            }
                        }

                        Flow {
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: root.editProviderFetchedModels
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool selected: root.isModelSelected(modelData.id)

                                    implicitWidth: chipRow.implicitWidth + 14
                                    implicitHeight: 26
                                    radius: 13
                                    color: selected ? Theme.withAlpha(Theme.primary, 0.2) : Theme.surfaceContainerHigh
                                    border.width: 1
                                    border.color: selected ? Theme.primary : Theme.outlineVariant

                                    RowLayout {
                                        id: chipRow
                                        anchors.centerIn: parent
                                        spacing: 4

                                        DankIcon {
                                            name: selected ? "check_circle" : "radio_button_unchecked"
                                            size: 13
                                            color: selected ? Theme.primary : Theme.surfaceVariantText
                                        }

                                        StyledText {
                                            text: modelData.name || modelData.id
                                            font.pixelSize: 10
                                            font.weight: selected ? Font.Bold : Font.Normal
                                            color: selected ? Theme.primary : Theme.surfaceText
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toggleModelSelection(modelData.id)
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
                            Layout.fillWidth: true
                            text: root.customModelInput
                            placeholderText: "手动添加指定模型 ID (如 deepseek-reasoner)..."
                            onTextChanged: root.customModelInput = text
                            Keys.onReturnPressed: root.addCustomModel()
                        }

                        Rectangle {
                            implicitWidth: 80
                            implicitHeight: 32
                            radius: 6
                            color: Theme.surfaceContainerHigh
                            StyledText {
                                anchors.centerIn: parent
                                text: "添加模型"
                                font.pixelSize: 11
                                color: Theme.surfaceText
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.addCustomModel()
                            }
                        }
                    }

                    // Form Action Buttons
                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM

                        Rectangle {
                            implicitWidth: 140
                            implicitHeight: 32
                            radius: 6
                            color: Theme.surfaceContainerHigh
                            StyledText {
                                anchors.centerIn: parent
                                text: root.isTesting ? "⏳ 测试拉取中..." : "🔍 测试并拉取模型"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.isTesting = true;
                                    root.testResultText = "⏳ 正在连接测试端点...";
                                    testModelsProc.command = [
                                        Qt.resolvedUrl("./core/dms-calendar-core").toString().replace(/^file:\/\//, ""),
                                        "provider", "fetch-models",
                                        "--id", root.editProviderId,
                                        "--base-url", root.editProviderBaseUrl,
                                        "--api-key", root.editProviderApiKey
                                    ];
                                    testModelsProc.running = true;
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            implicitWidth: 100
                            implicitHeight: 32
                            radius: 6
                            color: Theme.primary
                            StyledText {
                                anchors.centerIn: parent
                                text: "💾 保存配置"
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: "#ffffff"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var pId = root.editProviderId.trim().toLowerCase();
                                    if (!pId) {
                                        root.testResultText = "❌ 服务商 ID 不能为空";
                                        return;
                                    }

                                    // Filter selected models
                                    var chosenModels = [];
                                    for (var i = 0; i < root.editProviderFetchedModels.length; i++) {
                                        var m = root.editProviderFetchedModels[i];
                                        if (root.editProviderSelectedModelIds.indexOf(m.id) !== -1) {
                                            chosenModels.push(m);
                                        }
                                    }

                                    if (chosenModels.length === 0 && root.editProviderSelectedModelIds.length > 0) {
                                        for (var j = 0; j < root.editProviderSelectedModelIds.length; j++) {
                                            var sid = root.editProviderSelectedModelIds[j];
                                            chosenModels.push({"id": sid, "name": sid, "desc": "模型"});
                                        }
                                    }

                                    var pObj = {
                                        "id": pId,
                                        "name": root.editProviderName.trim() || pId,
                                        "baseUrl": root.editProviderBaseUrl.trim(),
                                        "apiKey": root.editProviderApiKey.trim(),
                                        "enabled": true,
                                        "icon": "smart_toy",
                                        "color": "#1565c0",
                                        "models": chosenModels
                                    };
                                    providerStore.saveProvider(pObj);
                                    root.showEditForm = false;
                                }
                            }
                        }
                    }
                }
            }

            // Configured Providers List
            Column {
                width: parent.width
                spacing: Theme.spacingS

                StyledText {
                    text: "已配置的服务商列表:"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                }

                Repeater {
                    model: providerStore.allProviders
                    delegate: Rectangle {
                        id: provCard
                        required property var modelData
                        readonly property bool isPrimary: providerStore.activeProviderId === modelData.id

                        width: providerCol.width
                        implicitHeight: provCardCol.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadiusSmall
                        color: isPrimary ? Theme.withAlpha(Theme.primary, 0.08) : Theme.surfaceContainerLowest
                        border.width: isPrimary ? 1.5 : 1
                        border.color: isPrimary ? Theme.primary : Theme.outlineVariant

                        Column {
                            id: provCardCol
                            width: parent.width - Theme.spacingM * 2
                            x: Theme.spacingM
                            y: Theme.spacingM
                            spacing: Theme.spacingS

                            RowLayout {
                                width: parent.width
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: modelData.icon || "smart_toy"
                                    size: 20
                                    color: modelData.color || Theme.primary
                                }

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    RowLayout {
                                        spacing: 6
                                        StyledText {
                                            text: modelData.name || modelData.id
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Bold
                                            color: Theme.surfaceText
                                        }

                                        Rectangle {
                                            visible: isPrimary
                                            implicitWidth: primTxt.implicitWidth + 8
                                            implicitHeight: 18
                                            radius: 4
                                            color: Theme.primary
                                            StyledText {
                                                id: primTxt
                                                anchors.centerIn: parent
                                                text: "当前激活"
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                                color: "#ffffff"
                                            }
                                        }
                                    }

                                    StyledText {
                                        text: modelData.baseUrl || ""
                                        font.pixelSize: 11
                                        color: Theme.surfaceVariantText
                                        elide: Text.ElideRight
                                    }
                                }

                                // Action Buttons
                                DankActionButton {
                                    iconName: "edit"
                                    onClicked: root.openEditProvider(modelData)
                                }

                                DankActionButton {
                                    iconName: "delete"
                                    visible: modelData.id !== "agnes"
                                    onClicked: providerStore.deleteProvider(modelData.id)
                                }
                            }

                            // Model Chips
                            Flow {
                                width: parent.width
                                spacing: 4
                                Repeater {
                                    model: modelData.models || []
                                    delegate: Rectangle {
                                        required property var modelData
                                        readonly property bool isSelected: providerStore.activeModelId === modelData.id && provCard.isPrimary

                                        implicitWidth: mTxt.implicitWidth + 12
                                        implicitHeight: 22
                                        radius: 4
                                        color: isSelected ? Theme.primary : Theme.surfaceContainerHigh

                                        StyledText {
                                            id: mTxt
                                            anchors.centerIn: parent
                                            text: modelData.name || modelData.id
                                            font.pixelSize: 10
                                            font.weight: isSelected ? Font.Bold : Font.Normal
                                            color: isSelected ? "#ffffff" : Theme.surfaceText
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                providerStore.setActive(provCard.modelData.id, modelData.id);
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
    }

    // ==========================================
    // 2. 日历与待办常规参数配置 (完整 8 项统一中文)
    // ==========================================
    StyledText {
        text: "📅 日历与待办常规设置"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    SliderSetting {
        settingKey: "refreshInterval"
        label: "刷新间隔"
        description: "后台轮询日历与待办变更的周期 (秒)"
        defaultValue: 30
        minimum: 5
        maximum: 300
        unit: "s"
    }

    ToggleSetting {
        settingKey: "dynamicWidth"
        label: "动态宽度适应"
        description: "短标题自动收缩顶栏胶囊宽度，避免占用过多顶栏空间"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "scrollTitle"
        label: "超长标题跑马灯滚动"
        description: "当日程标题超出顶栏宽度时平滑来回滚动展示，关闭则直接截断显示省略号"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showTooltip"
        label: "鼠标悬停提示"
        description: "鼠标悬停在顶栏胶囊上时，浮现完整的日程详情与倒计时提示框"
        defaultValue: true
    }

    SliderSetting {
        settingKey: "pillMaxWidth"
        label: "顶栏胶囊最大宽度"
        description: "顶栏显示事件标题的最大宽度 (像素)"
        defaultValue: 200
        minimum: 40
        maximum: 400
        unit: "px"
    }

    SliderSetting {
        settingKey: "nowWindowMinutes"
        label: "进行中 ('Now') 判定时长"
        description: "事件开始后持续在顶栏与列表中显示为 'Now' 的分钟数 (设为 0 关闭)"
        defaultValue: 5
        minimum: 0
        maximum: 60
        unit: "m"
    }

    SliderSetting {
        settingKey: "agendaPastDays"
        label: "历史日程回溯天数"
        description: "弹窗日程列表中向上滚动可查看的历史日程天数"
        defaultValue: 7
        minimum: 0
        maximum: 30
        unit: "d"
    }

    SliderSetting {
        settingKey: "agendaFutureDays"
        label: "未来日程覆盖天数"
        description: "弹窗日程列表中展示的未来日程天数"
        defaultValue: 30
        minimum: 1
        maximum: 90
        unit: "d"
    }

    SliderSetting {
        settingKey: "lookAheadDays"
        label: "顶栏前瞻检索天数"
        description: "顶栏胶囊向前检索下一个待办日程的最大天数"
        defaultValue: 1
        minimum: 1
        maximum: 14
        unit: "d"
    }
}
