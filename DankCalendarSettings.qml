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

    // Realtime Concurrent Model Benchmarking State (Per Model Latency Cache)
    property var modelBenchmarkMap: ({})

    // Tag Store & Management State
    property var registeredTags: []
    property string newTagNameInput: ""

    // Compositor & Cheat Sheet & AI Collapse State
    property string activeCompositor: "niri"
    property bool aiSectionExpanded: false
    property bool cheatSheetExpanded: false

    readonly property string niriCodeSnippet:
'// 将以下内容添加至 ~/.config/niri/config.kdl 的 binds { ... } 区块中:\n' +
'binds {\n' +
'    // 开闭主日历/待办面板\n' +
'    Mod+Alt+C { spawn "dms" "ipc" "call" "dankCalendarPlus" "toggle"; }\n' +
'    // 直达待办面板\n' +
'    Mod+Alt+T { spawn "dms" "ipc" "call" "dankCalendarPlus" "openTasks"; }\n' +
'    // 直达日程议程\n' +
'    Mod+Alt+A { spawn "dms" "ipc" "call" "dankCalendarPlus" "openAgenda"; }\n' +
'    // 呼出独立 AI 排程浮窗\n' +
'    Mod+Alt+I { spawn "dms" "ipc" "call" "dankCalendarPlus" "toggleAI"; }\n' +
'    // 打开插件设置与快捷键速查\n' +
'    Mod+Alt+S { spawn "dms" "ipc" "call" "dankCalendarPlus" "openSettings"; }\n' +
'}\n'

    readonly property string hyprlandCodeSnippet:
'# 将以下内容添加至 ~/.config/hypr/hyprland.conf 中:\n' +
'# 开闭主日历/待办面板\n' +
'bind = SUPER ALT, C, exec, dms ipc call dankCalendarPlus toggle\n' +
'# 直达待办面板\n' +
'bind = SUPER ALT, T, exec, dms ipc call dankCalendarPlus openTasks\n' +
'# 直达日程议程\n' +
'bind = SUPER ALT, A, exec, dms ipc call dankCalendarPlus openAgenda\n' +
'# 呼出独立 AI 排程浮窗\n' +
'bind = SUPER ALT, I, exec, dms ipc call dankCalendarPlus toggleAI\n' +
'# 打开插件设置与快捷键速查\n' +
'bind = SUPER ALT, S, exec, dms ipc call dankCalendarPlus openSettings\n'

    readonly property var cheatSheetSections: [
        {
            title: "🌟 顶栏胶囊与鼠标交互",
            icon: "mouse",
            items: [
                { key: "左键单击", desc: "切换展开 / 收起日历与待办主面板 (Popout)" },
                { key: "中键单击", desc: "唤起系统默认完整日程应用 (如 GNOME Calendar)" },
                { key: "右键单击", desc: "强制全量同步并重新加载日历与待办数据" },
                { key: "滚轮滚动", desc: "在待办与日程视图间平滑切换或翻看未来事件" }
            ]
        },
        {
            title: "🔀 页面导航与 Tab 秒切",
            icon: "tab",
            items: [
                { key: "1 / 2 / 3", desc: "未聚焦输入框时，秒级直达【日程】/【待办】/【助理】" },
                { key: "Ctrl + 1 / 2 / 3", desc: "全局强制秒切对应 Tab 页面 (不受输入框焦点限制)" },
                { key: "Ctrl + Tab", desc: "向后顺序轮换切换下一个 Tab 标签页" },
                { key: "Ctrl + Shift + Tab", desc: "向前顺序轮换切换上一个 Tab 标签页" }
            ]
        },
        {
            title: "⌨️ 键盘漫游与条目操作",
            icon: "keyboard",
            items: [
                { key: "j / k 或 ↓ / ↑", desc: "列表中平滑上下漫游高亮选中项" },
                { key: "m", desc: "一键快速打开并加入选中日程的视频会议链接" },
                { key: "Space (空格)", desc: "即刻切换选中待办的完成状态 (打勾 / 取消)" },
                { key: "c", desc: "一键复制当前选中待办或日程的标题至剪贴板" },
                { key: "d / Delete", desc: "快速删除当前选中的待办事项" },
                { key: "t / Home", desc: "在日程议程视图中一键直达“今天”" }
            ]
        },
        {
            title: "⚡ 快速创建与标记语法",
            icon: "edit_note",
            items: [
                { key: "Ctrl + N", desc: "瞬间聚焦新建待办输入框 (任意时刻呼出)" },
                { key: "Enter", desc: "确认并保存新建的待办事项" },
                { key: "!1 / !2 / !3", desc: "智能优先级：!1 高优(红) · !2 中优(黄) · !3 低优(绿)" },
                { key: "#标签名", desc: "智能标签：如 #工作 #学习，自动关联本地标签库" }
            ]
        },
        {
            title: "🤖 AI 助理全键盘流与多模态",
            icon: "smart_toy",
            items: [
                { key: "Ctrl + V", desc: "剪贴板截图直接粘贴 OCR 多模态视觉解析并排程" },
                { key: "Enter", desc: "发送当前自然语言排程与规划指令" },
                { key: "Shift + Enter", desc: "在多行输入框内换行输入长文本" },
                { key: "↑ / ↓", desc: "光标在首尾时快速回溯上一条 / 下一条 Prompt" },
                { key: "/", desc: "快速呼出内置指令补全 (/today, /plan 等)" }
            ]
        },
        {
            title: "🛠️ 通用操作与窗口控制",
            icon: "tune",
            items: [
                { key: "Ctrl + R", desc: "强制全量刷新同步日历与待办数据" },
                { key: "Esc", desc: "快速退出当前主弹窗或关闭子浮窗" }
            ]
        }
    ]


    function copyToClipboard(txt, msg) {
        if (!txt) return;
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy 2>/dev/null || printf '%s' \"$1\" | xclip -selection clipboard 2>/dev/null", "sh", txt]);
        try {
            ToastService.showInfo(msg || "已复制到剪贴板");
        } catch (e) {
            console.log("[Settings] Copied:", txt);
        }
    }

    Process {
        id: loadTagsProc
        command: [
            Qt.resolvedUrl("./core/dms-calendar-core").toString().replace(/^file:\/\//, ""),
            "tag", "list"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var trimmed = (text || "").trim();
                if (!trimmed) return;
                try {
                    var res = JSON.parse(trimmed);
                    if (res.status === "ok" && res.data && res.data.tags) {
                        root.registeredTags = res.data.tags;
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: addTagProc
        command: []
        running: false
        onExited: (code) => {
            loadTagsProc.running = true;
        }
    }

    Process {
        id: deleteTagProc
        command: []
        running: false
        onExited: (code) => {
            loadTagsProc.running = true;
        }
    }

    function addTag() {
        var name = root.newTagNameInput.trim().replace(/^#/, "");
        if (!name) return;
        addTagProc.command = [
            Qt.resolvedUrl("./core/dms-calendar-core").toString().replace(/^file:\/\//, ""),
            "tag", "add",
            "--name", name
        ];
        addTagProc.running = true;
        root.newTagNameInput = "";
    }

    function deleteTag(tagId) {
        if (!tagId) return;
        deleteTagProc.command = [
            Qt.resolvedUrl("./core/dms-calendar-core").toString().replace(/^file:\/\//, ""),
            "tag", "delete",
            "--id", String(tagId)
        ];
        deleteTagProc.running = true;
    }

    Component {
        id: benchmarkProcComp
        Process {
            id: bProc
            property string targetModelId: ""
            command: []
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    var trimmed = (text || "").trim();
                    if (!trimmed) {
                        bProc.destroy();
                        return;
                    }
                    try {
                        var res = JSON.parse(trimmed);
                        var map = Object.assign({}, root.modelBenchmarkMap);
                        var mKey = res.model || bProc.targetModelId;
                        map[mKey] = {
                            latency: res.latency || 0,
                            totalMs: res.totalMs || 0,
                            status: res.status || "error",
                            message: res.message || ""
                        };
                        root.modelBenchmarkMap = map;
                    } catch (e) {
                        var errMap = Object.assign({}, root.modelBenchmarkMap);
                        errMap[bProc.targetModelId] = { status: "error", message: "解析失败" };
                        root.modelBenchmarkMap = errMap;
                    }
                    bProc.destroy();
                }
            }
            onExited: (code) => {
                if (bProc.targetModelId && (!root.modelBenchmarkMap[bProc.targetModelId] || root.modelBenchmarkMap[bProc.targetModelId].status === "loading")) {
                    var m = Object.assign({}, root.modelBenchmarkMap);
                    m[bProc.targetModelId] = { status: "error", message: "执行异常退出 (" + code + ")" };
                    root.modelBenchmarkMap = m;
                }
                bProc.destroy();
            }
        }
    }

    function benchmarkModel(providerId, modelId, baseUrl, apiKey) {
        if (!modelId) return;
        var map = Object.assign({}, root.modelBenchmarkMap);
        map[modelId] = { status: "loading" };
        root.modelBenchmarkMap = map;

        var cmd = [
            Qt.resolvedUrl("./core/dms-calendar-core").toString().replace(/^file:\/\//, ""),
            "provider", "benchmark",
            "--id", providerId || "",
            "--model", modelId
        ];
        if (baseUrl) cmd.push("--base-url", baseUrl);
        if (apiKey) cmd.push("--api-key", apiKey);

        var p = benchmarkProcComp.createObject(root, {
            "targetModelId": modelId,
            "command": cmd
        });
        if (p) {
            p.running = true;
        }
    }

    function benchmarkAllModels(providerObj) {
        if (!providerObj || !providerObj.models) return;
        for (var i = 0; i < providerObj.models.length; i++) {
            var m = providerObj.models[i];
            benchmarkModel(providerObj.id, m.id, providerObj.baseUrl, providerObj.apiKey);
        }
    }

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
        root.aiSectionExpanded = true;
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
        root.aiSectionExpanded = true;
        if (!p) return;
        isEditingProvider = true;
        editProviderId = p.id || "";
        editProviderName = p.name || "";
        editProviderBaseUrl = p.baseUrl || "https://";
        editProviderApiKey = p.apiKey || "";
        var fetched = [];
        var ids = [];
        for (var i = 0; i < (p.models || []).length; i++) {
            var m = p.models[i];
            fetched.push({
                "id": m.id,
                "name": m.name || m.id,
                "desc": m.desc || "模型",
                "vision": !!m.vision
            });
            ids.push(m.id);
        }
        editProviderFetchedModels = fetched;
        editProviderSelectedModelIds = ids;
        customModelInput = "";
        testResultText = "";
        testSuccess = false;
        showEditForm = true;
    }

    function openAddPreset(preset) {
        root.aiSectionExpanded = true;
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
        var fetched = [];
        var ids = [];
        for (var j = 0; j < (preset.models || []).length; j++) {
            var pm = preset.models[j];
            fetched.push({
                "id": pm.id,
                "name": pm.name || pm.id,
                "desc": pm.desc || "预设模型",
                "vision": !!pm.vision
            });
            ids.push(pm.id);
        }
        editProviderFetchedModels = fetched;
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

    function toggleModelVision(modelId) {
        var list = root.editProviderFetchedModels.slice();
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === modelId) {
                var item = Object.assign({}, list[i]);
                item.vision = !item.vision;
                list[i] = item;
                break;
            }
        }
        root.editProviderFetchedModels = list;
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
                "desc": "用户自定义模型",
                "vision": false
            }]);
            editProviderFetchedModels = newModels;
        }
        if (editProviderSelectedModelIds.indexOf(mid) === -1) {
            editProviderSelectedModelIds = editProviderSelectedModelIds.concat([mid]);
        }
        customModelInput = "";
    }



    // ==========================================
    // 1. 🚀 全功能操作与快捷键汇总速查指南 (Cheat Sheet Dashboard - Collapsible)
    // ==========================================
    Rectangle {
        width: parent.width
        implicitHeight: root.cheatSheetExpanded ? (csContentCol.implicitHeight + Theme.spacingM * 2) : (csHeaderRow.implicitHeight + Theme.spacingM * 2)
        clip: true
        color: Theme.surfaceContainer
        radius: Theme.cornerRadius
        border.color: root.cheatSheetExpanded ? Theme.primary : Theme.outlineVariant
        border.width: 1

        Behavior on implicitHeight {
            NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
        }

        Column {
            id: csContentCol
            width: parent.width - Theme.spacingM * 2
            x: Theme.spacingM
            y: Theme.spacingM
            spacing: Theme.spacingM

            // 头部：标题与展开/收起按钮
            RowLayout {
                id: csHeaderRow
                width: parent.width
                spacing: Theme.spacingS

                Rectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 8
                    color: Theme.withAlpha(Theme.primary, 0.15)

                    DankIcon {
                        anchors.centerIn: parent
                        name: "bolt"
                        size: 20
                        color: Theme.primary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: "🚀 全功能操作与快捷键指南 (Cheat Sheet)"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                    }

                    StyledText {
                        text: root.cheatSheetExpanded
                              ? "涵盖鼠标手势、Tab秒切、漫游标记、多模态AI排程及全局快捷键"
                              : "点击右侧展开速查表 · 快速查看 6 大核心按键流与合成器配置"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }

                // 折叠/展开切换按钮
                Rectangle {
                    implicitWidth: csCollapseBtnRow.implicitWidth + 16
                    implicitHeight: 32
                    radius: 8
                    color: root.cheatSheetExpanded ? Theme.withAlpha(Theme.primary, 0.12) : Theme.surfaceContainerHighest
                    border.width: 1
                    border.color: root.cheatSheetExpanded ? Theme.primary : Theme.outlineVariant

                    RowLayout {
                        id: csCollapseBtnRow
                        anchors.centerIn: parent
                        spacing: 4
                        DankIcon {
                            name: root.cheatSheetExpanded ? "expand_less" : "expand_more"
                            size: 16
                            color: Theme.primary
                        }
                        StyledText {
                            text: root.cheatSheetExpanded ? "收起速查表" : "展开速查表"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cheatSheetExpanded = !root.cheatSheetExpanded
                    }
                }
            }

            // 可折叠内容区
            Column {
                width: parent.width
                spacing: Theme.spacingM
                visible: root.cheatSheetExpanded

                // 6 大核心交互板块网格
                GridLayout {
                    id: cheatSheetGrid
                    width: parent.width
                    columns: root.width >= 700 ? 2 : 1
                    rowSpacing: Theme.spacingM
                    columnSpacing: Theme.spacingM

                    Repeater {
                        model: root.cheatSheetSections
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            implicitHeight: cardInnerCol.implicitHeight + Theme.spacingM * 2
                            radius: Theme.cornerRadius
                            color: Theme.surfaceContainerLowest
                            border.width: 1
                            border.color: Theme.outlineVariant

                            ColumnLayout {
                                id: cardInnerCol
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: 10

                                // 板块标题
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        implicitWidth: 28
                                        implicitHeight: 28
                                        radius: 6
                                        color: Theme.withAlpha(Theme.primary, 0.12)

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: modelData.icon || "info"
                                            size: 16
                                            color: Theme.primary
                                        }
                                    }

                                    StyledText {
                                        text: modelData.title
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Bold
                                        color: Theme.surfaceText
                                        Layout.fillWidth: true
                                    }
                                }

                                // 分割细线
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 1
                                    color: Theme.withAlpha(Theme.outlineVariant, 0.4)
                                }

                                // 快捷键列表
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Repeater {
                                        model: modelData.items
                                        delegate: RowLayout {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            spacing: 8

                                            // 按键芯片 Badge
                                            Rectangle {
                                                implicitWidth: kbdText.implicitWidth + 14
                                                implicitHeight: 22
                                                radius: 4
                                                color: Theme.surfaceContainerHighest
                                                border.width: 1
                                                border.color: Theme.withAlpha(Theme.outline, 0.3)

                                                StyledText {
                                                    id: kbdText
                                                    anchors.centerIn: parent
                                                    text: modelData.key
                                                    font.family: "Monospace"
                                                    font.pixelSize: 10
                                                    font.weight: Font.DemiBold
                                                    color: Theme.primary
                                                }
                                            }

                                            // 说明文字
                                            StyledText {
                                                Layout.fillWidth: true
                                                text: modelData.desc
                                                font.pixelSize: 11
                                                color: Theme.surfaceVariantText
                                                wrapMode: Text.Wrap
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 桌面合成器全局快捷键配置卡片 (Niri / Hyprland)
                Rectangle {
                    width: parent.width
                    implicitHeight: compositorCol.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerLowest
                    border.width: 1
                    border.color: Theme.outlineVariant

                    ColumnLayout {
                        id: compositorCol
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: 10

                        // 第 1 行：图标 + 标题
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingS

                            Rectangle {
                                implicitWidth: 28
                                implicitHeight: 28
                                radius: 6
                                color: Theme.withAlpha(Theme.primary, 0.12)

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "terminal"
                                    size: 16
                                    color: Theme.primary
                                }
                            }

                            StyledText {
                                text: "🖥️ Wayland 桌面合成器全局快捷键配置"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                                Layout.fillWidth: true
                            }
                        }

                        // 第 2 行：副标题说明（独立整行，绝不挤压右侧按钮）
                        StyledText {
                            text: "添加至合成器配置后，即可在任意前台窗口通过全局物理按键秒级唤起面板或对应视图。"
                            font.pixelSize: 11
                            color: Theme.surfaceVariantText
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }

                        // 第 3 行：配置切换与操作工具栏
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            StyledText {
                                text: root.activeCompositor === "niri" ? "~/.config/niri/config.kdl" : "~/.config/hypr/hyprland.conf"
                                font.family: "Monospace"
                                font.pixelSize: 10
                                color: Theme.surfaceVariantText
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle
                            }

                            // 合成器切换 Segmented Switcher (Niri / Hyprland)
                            Rectangle {
                                implicitWidth: segRow.implicitWidth + 6
                                implicitHeight: 28
                                radius: 14
                                color: Theme.surfaceContainerHighest
                                border.width: 1
                                border.color: Theme.outlineVariant

                                RowLayout {
                                    id: segRow
                                    anchors.centerIn: parent
                                    spacing: 2

                                    // Niri Pill
                                    Rectangle {
                                        implicitWidth: niriLabel.implicitWidth + 14
                                        implicitHeight: 22
                                        radius: 11
                                        color: root.activeCompositor === "niri" ? Theme.primary : "transparent"

                                        StyledText {
                                            id: niriLabel
                                            anchors.centerIn: parent
                                            text: "Niri"
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            color: root.activeCompositor === "niri" ? "#ffffff" : Theme.surfaceVariantText
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.activeCompositor = "niri"
                                        }
                                    }

                                    // Hyprland Pill
                                    Rectangle {
                                        implicitWidth: hyprLabel.implicitWidth + 14
                                        implicitHeight: 22
                                        radius: 11
                                        color: root.activeCompositor === "hyprland" ? Theme.primary : "transparent"

                                        StyledText {
                                            id: hyprLabel
                                            anchors.centerIn: parent
                                            text: "Hyprland"
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            color: root.activeCompositor === "hyprland" ? "#ffffff" : Theme.surfaceVariantText
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.activeCompositor = "hyprland"
                                        }
                                    }
                                }
                            }

                            // 复制代码按钮
                            Rectangle {
                                implicitWidth: copyCompText.implicitWidth + 20
                                implicitHeight: 28
                                radius: 14
                                color: copyCompMouse.containsMouse ? Theme.primaryHover : Theme.primary

                                property bool copied: false
                                Timer {
                                    id: compCopyTimer
                                    interval: 1500
                                    onTriggered: parent.copied = false
                                }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    DankIcon {
                                        name: parent.parent.copied ? "check" : "content_copy"
                                        size: 13
                                        color: "#ffffff"
                                    }

                                    StyledText {
                                        id: copyCompText
                                        text: parent.parent.copied ? "已复制" : "复制代码"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: "#ffffff"
                                    }
                                }

                                MouseArea {
                                    id: copyCompMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var snippet = root.activeCompositor === "niri" ? root.niriCodeSnippet : root.hyprlandCodeSnippet;
                                        var name = root.activeCompositor === "niri" ? "Niri" : "Hyprland";
                                        root.copyToClipboard(snippet, name + " 快捷键配置已复制到剪贴板");
                                        parent.copied = true;
                                        compCopyTimer.restart();
                                    }
                                }
                            }
                        }

                        // 第 4 行：代码展示框
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: compCodeEdit.implicitHeight + 16
                            radius: Theme.cornerRadiusSmall
                            color: Theme.surfaceContainerHighest
                            border.width: 1
                            border.color: Theme.outlineVariant

                            TextEdit {
                                id: compCodeEdit
                                anchors.fill: parent
                                anchors.margins: 10
                                readOnly: true
                                selectByMouse: true
                                cursorVisible: false
                                wrapMode: Text.Wrap
                                font.family: "Monospace"
                                font.pixelSize: 11
                                color: Theme.surfaceText
                                selectionColor: Theme.primary
                                selectedTextColor: Theme.primaryText
                                text: root.activeCompositor === "niri" ? root.niriCodeSnippet : root.hyprlandCodeSnippet
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

    // ==========================================
    // 3. 🔔 桌面通知与事件提醒偏好 (Freedesktop / dms notify)
    // ==========================================
    StyledText {
        text: "🔔 系统原生通知与事件提醒偏好"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        text: "支持接入 Linux 原生桌面通知体系 (dms notify / org.freedesktop.Notifications)，兼顾即时弹出与通知中心历史留存"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }

    SelectionSetting {
        settingKey: "notificationMode"
        label: "通知模式偏好"
        description: "选择插件消息提醒的分发方式（双轨通知兼顾屏幕前台即时高亮与通知中心历史留存）"
        defaultValue: "both"
        options: [
            { value: "both", label: "双轨通知 (桌面通知 + Toast 胶囊)" },
            { value: "native", label: "仅系统原生桌面通知" },
            { value: "toast", label: "仅 DMS Toast 悬浮胶囊" },
            { value: "none", label: "完全关闭通知" }
        ]
    }

    ToggleSetting {
        settingKey: "eventReminderEnabled"
        label: "日程即将开始提前通知"
        description: "在下一个日程开始前发送桌面通知，避免错过重要会议与日程"
        defaultValue: true
    }

    SliderSetting {
        settingKey: "eventReminderMinutes"
        label: "日程提前提醒时长"
        description: "日程开始前多少分钟触发桌面提醒"
        defaultValue: 5
        minimum: 1
        maximum: 30
        unit: "m"
    }

    ToggleSetting {
        settingKey: "taskOverdueReminderEnabled"
        label: "待办到期通知提醒"
        description: "当待办事项到达设定到期时间或临期时，在桌面弹出通知提醒"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "aiNotificationEnabled"
        label: "AI 助理回复与报错通知"
        description: "AI 思考回复完毕、生成排程建议或遇到请求错误时发送桌面通知提醒（便于后台等待）"
        defaultValue: true
    }

    // 发送测试通知卡片
    Rectangle {
        width: parent.width
        implicitHeight: testNotifyRow.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerLowest
        border.width: 1
        border.color: Theme.outlineVariant

        RowLayout {
            id: testNotifyRow
            width: parent.width - Theme.spacingM * 2
            x: Theme.spacingM
            y: Theme.spacingM
            spacing: Theme.spacingM

            Rectangle {
                implicitWidth: 32
                implicitHeight: 32
                radius: 8
                color: Theme.withAlpha(Theme.primary, 0.12)
                Image {
                    id: dcalAppIcon
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: "file:///usr/share/icons/hicolor/scalable/apps/com.danklinux.dankcalendar.svg"
                    sourceSize.width: 20
                    sourceSize.height: 20
                    visible: status === Image.Ready
                }
                DankIcon {
                    anchors.centerIn: parent
                    name: "notifications_active"
                    size: 18
                    color: Theme.primary
                    visible: !dcalAppIcon.visible
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                StyledText {
                    text: "测试通知连通性"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                }
                StyledText {
                    text: "按当前设置的通知模式立即触发一条测试通知，检验桌面通知中心与 Toast 气泡"
                    font.pixelSize: 11
                    color: Theme.surfaceVariantText
                }
            }

            Rectangle {
                implicitWidth: testBtnText.implicitWidth + 24
                implicitHeight: 30
                radius: 15
                color: testBtnMouse.containsMouse ? Theme.primaryHover : Theme.primary

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    DankIcon { name: "send"; size: 14; color: "#ffffff" }
                    StyledText {
                        id: testBtnText
                        text: "发送测试通知"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }
                }

                MouseArea {
                    id: testBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["dms", "ipc", "call", "dankCalendarPlus", "testNotification"]);
                    }
                }
            }
        }
    }

    // ==========================================
    // 4. 🏷️ 常用分类标签库管理 (SQLite)
    // ==========================================
    StyledText {
        text: "🏷️ 常用分类标签管理"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        text: "自定义全局预设标签与主题配色，支持跨端 CalDAV #tag 同步识别与多色彩分类"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }

    Rectangle {
        width: parent.width
        implicitHeight: tagCol.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerLowest
        border.width: 1
        border.color: Theme.outlineVariant

        Column {
            id: tagCol
            width: parent.width - Theme.spacingM * 2
            x: Theme.spacingM
            y: Theme.spacingM
            spacing: Theme.spacingM

            // Existing Tags Flow
            Flow {
                width: parent.width
                spacing: 8

                Repeater {
                    model: root.registeredTags
                    delegate: Rectangle {
                        required property var modelData
                        readonly property string tagColor: modelData.color || Theme.primary

                        implicitWidth: tChipRow.implicitWidth + 12
                        implicitHeight: 28
                        radius: 14
                        color: Theme.withAlpha(tagColor, 0.12)
                        border.width: 1
                        border.color: Theme.withAlpha(tagColor, 0.4)

                        RowLayout {
                            id: tChipRow
                            anchors.centerIn: parent
                            spacing: 4

                            DankIcon {
                                name: modelData.icon || "label"
                                size: 14
                                color: tagColor
                            }

                            StyledText {
                                text: "#" + modelData.name
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: tagColor
                            }

                            // Delete button
                            Rectangle {
                                implicitWidth: 16
                                implicitHeight: 16
                                radius: 8
                                color: delTagMouse.containsMouse ? Theme.withAlpha(Theme.error, 0.2) : "transparent"

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "close"
                                    size: 11
                                    color: delTagMouse.containsMouse ? Theme.error : Theme.surfaceVariantText
                                }

                                MouseArea {
                                    id: delTagMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.deleteTag(modelData.id)
                                }
                            }
                        }
                    }
                }
            }

            // Add Tag Input Row
            RowLayout {
                width: parent.width
                spacing: Theme.spacingS

                DankTextField {
                    Layout.fillWidth: true
                    text: root.newTagNameInput
                    placeholderText: "添加新分类标签 (如: 运动 / 读书 / 会议)..."
                    onTextChanged: root.newTagNameInput = text
                    Keys.onReturnPressed: root.addTag()
                }

                Rectangle {
                    implicitWidth: 80
                    implicitHeight: 32
                    radius: 6
                    color: Theme.primary

                    StyledText {
                        anchors.centerIn: parent
                        text: "添加标签"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.addTag()
                    }
                }
            }
        }
    }


    // ==========================================
    // 5. 🤖 AI 大模型服务商与模型管理中心
    // ==========================================
    Rectangle {
        width: parent.width
        implicitHeight: root.aiSectionExpanded ? (providerCol.implicitHeight + Theme.spacingM * 2) : (aiHeaderRow.implicitHeight + Theme.spacingM * 2)
        clip: true
        Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
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

            // Header & Collapse Button & Add Custom Button
            RowLayout {
                id: aiHeaderRow
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
                        text: root.aiSectionExpanded ? "统一凭证管理 · 填入 API Key 后一键拉取官方最新模型，支持按需勾选启用" : ("当前已配置 " + providerStore.allProviders.length + " 个服务商 · 点击右侧展开完整管理")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }

                // 折叠/展开切换按钮
                Rectangle {
                    implicitWidth: collapseBtnRow.implicitWidth + 16
                    implicitHeight: 32
                    radius: 8
                    color: Theme.surfaceContainerHighest
                    border.width: 1
                    border.color: Theme.outlineVariant

                    RowLayout {
                        id: collapseBtnRow
                        anchors.centerIn: parent
                        spacing: 4
                        DankIcon {
                            name: root.aiSectionExpanded ? "expand_less" : "expand_more"
                            size: 16
                            color: Theme.primary
                        }
                        StyledText {
                            text: root.aiSectionExpanded ? "收起" : "展开配置"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.aiSectionExpanded = !root.aiSectionExpanded
                    }
                }

                Rectangle {
                    visible: root.aiSectionExpanded
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

            // AI Body Content (Collapsible)
            Column {
                width: parent.width
                spacing: Theme.spacingM
                visible: root.aiSectionExpanded

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
                                    id: editChip
                                    required property var modelData
                                    readonly property bool selected: root.isModelSelected(modelData.id)
                                    readonly property bool isVision: !!modelData.vision

                                    implicitWidth: chipRow.implicitWidth + 14
                                    implicitHeight: 28
                                    radius: 14
                                    color: selected ? Theme.withAlpha(Theme.primary, 0.2) : Theme.surfaceContainerHigh
                                    border.width: 1
                                    border.color: selected ? Theme.primary : Theme.outlineVariant

                                    RowLayout {
                                        id: chipRow
                                        anchors.centerIn: parent
                                        spacing: 5

                                        DankIcon {
                                            name: selected ? "check_circle" : "radio_button_unchecked"
                                            size: 14
                                            color: selected ? Theme.primary : Theme.surfaceVariantText
                                        }

                                        StyledText {
                                            text: modelData.name || modelData.id
                                            font.pixelSize: 11
                                            font.weight: selected ? Font.Bold : Font.Normal
                                            color: selected ? Theme.primary : Theme.surfaceText
                                        }

                                        // Manual Vision Toggle Icon Button
                                        Rectangle {
                                            implicitWidth: 20
                                            implicitHeight: 20
                                            radius: 10
                                            color: isVision ? Theme.primary : Theme.surfaceContainerHighest
                                            border.width: 1
                                            border.color: isVision ? Theme.primary : Theme.outlineVariant

                                            DankIcon {
                                                anchors.centerIn: parent
                                                name: isVision ? "visibility" : "visibility_off"
                                                size: 12
                                                color: isVision ? "#ffffff" : Theme.surfaceVariantText
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.toggleModelVision(modelData.id)
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        z: -1
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
                                    iconName: "bolt"
                                    visible: (modelData.models || []).length > 0
                                    onClicked: root.benchmarkAllModels(modelData)
                                }

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
                                spacing: 6
                                Repeater {
                                    model: modelData.models || []
                                    delegate: Rectangle {
                                        id: mChip
                                        required property var modelData
                                        readonly property bool isSelected: providerStore.activeModelId === modelData.id && provCard.isPrimary
                                        readonly property var benchInfo: root.modelBenchmarkMap[modelData.id] || null
                                        readonly property bool isBenchmarking: benchInfo && benchInfo.status === "loading"

                                        implicitWidth: mChipRow.implicitWidth + 12
                                        implicitHeight: 26
                                        radius: 13
                                        color: isSelected ? Theme.primary : Theme.surfaceContainerHigh
                                        border.width: 1
                                        border.color: isSelected ? Theme.primary : Theme.outlineVariant

                                        RowLayout {
                                            id: mChipRow
                                            anchors.centerIn: parent
                                            spacing: 4

                                            // Vision icon indicator if model supports vision
                                            DankIcon {
                                                visible: !!modelData.vision
                                                name: "visibility"
                                                size: 13
                                                color: isSelected ? "#ffffff" : Theme.primary
                                            }

                                            StyledText {
                                                text: modelData.name || modelData.id
                                                font.pixelSize: 10
                                                font.weight: isSelected ? Font.Bold : Font.Normal
                                                color: isSelected ? "#ffffff" : Theme.surfaceText
                                            }

                                            // Benchmark Speed tag
                                            StyledText {
                                                visible: !!benchInfo && benchInfo.status === "ok"
                                                text: "⚡" + (benchInfo ? benchInfo.latency : 0) + "ms"
                                                font.pixelSize: 9
                                                font.weight: Font.Bold
                                                color: isSelected ? "#e0e7ff" : "#16a34a"
                                            }

                                            StyledText {
                                                visible: !!benchInfo && benchInfo.status === "error"
                                                text: "❌"
                                                font.pixelSize: 9
                                                color: isSelected ? "#fecaca" : Theme.error
                                            }

                                            // Speed test trigger button
                                            Rectangle {
                                                implicitWidth: 18
                                                implicitHeight: 18
                                                radius: 9
                                                color: isSelected ? Theme.withAlpha("#ffffff", 0.25) : Theme.surfaceContainerHighest
                                                border.width: 1
                                                border.color: isSelected ? Theme.withAlpha("#ffffff", 0.4) : Theme.outlineVariant

                                                DankIcon {
                                                    anchors.centerIn: parent
                                                    name: isBenchmarking ? "hourglass_top" : "bolt"
                                                    size: 11
                                                    color: isSelected ? "#ffffff" : Theme.primary
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        root.benchmarkModel(provCard.modelData.id, modelData.id, provCard.modelData.baseUrl, provCard.modelData.apiKey);
                                                    }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            z: -1
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
    }
}
