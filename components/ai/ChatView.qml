import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import "file:/usr/share/quickshell/dms/Modals/FileBrowser" as DMSFileBrowser

StyledRect {
    id: root

    property string aiScriptPath: ""
    property string batchScriptPath: ""
    property string sessionScriptPath: ""
    property string pasteHelperPath: ""
    property string providerScriptPath: Qt.resolvedUrl("../../provider-manager").toString().replace(/^file:\/\//, "")

    property string aiBaseUrl: ""
    property string aiApiKey: ""
    property string aiModel: "agnes-2.5-flash"
    property string customSystemPrompt: ""

    property string currentSessionId: ""
    property string currentSessionTitle: "新排程会话"
    property var messages: []
    property bool isGenerating: false
    property string streamingAssistantText: ""
    property var currentProposal: null
    property string attachedImagePath: ""
    property string attachedFilePath: ""
    property bool showDrawer: false
    property bool showModelMenu: false
    property bool quickAddExpanded: false
    property string modelSearchFilter: ""

    // Input prompt history navigation (Up / Down arrows like ChatGPT / Terminal)
    property var inputHistory: []
    property int inputHistoryIndex: -1
    property string temporaryDraft: ""

    function copyToClipboard(txt) {
        if (!txt) return
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy 2>/dev/null || printf '%s' \"$1\" | xclip -selection clipboard 2>/dev/null", "sh", txt])
    }

    // Dynamic Providers & Models from ~/.config/dms-ai/providers.json
    property var configuredProviders: []
    property string activeProviderId: "agnes"

    function loadProvidersConfig() {
        var script = providerScriptPath || "provider-manager"
        loadProvidersProc.command = [script, "list"]
        loadProvidersProc.running = true
    }

    Process {
        id: loadProvidersProc
        command: []
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                var trimmed = line.trim()
                if (!trimmed) return
                try {
                    var res = JSON.parse(trimmed)
                    if (res.status === "ok" && res.data) {
                        root.providersConfig = res.data
                        root.configuredProviders = res.data.providers || []
                        if (res.data.activeModel) {
                            root.aiModel = res.data.activeModel
                        }
                        if (res.data.activeProvider) {
                            root.activeProviderId = res.data.activeProvider
                        }
                    }
                } catch(e) {}
            }
        }
    }

    property var providersConfig: null
    property bool showCommandPalette: false

    // Direct In-Chat Provider Modal State
    property bool showInChatProviderModal: false
    property var inChatProviderData: null
    property string inChatApiKey: ""
    property string inChatBaseUrl: ""
    property bool inChatIsTesting: false
    property string inChatStatusText: ""

    function openInChatProviderConfig(pId) {
        var prov = null
        if (providersConfig && providersConfig.providers) {
            for (var i = 0; i < providersConfig.providers.length; i++) {
                if (providersConfig.providers[i].id === pId) {
                    prov = providersConfig.providers[i]
                    break
                }
            }
        }
        if (!prov) {
            prov = {
                id: pId,
                name: pId,
                baseUrl: "https://api." + pId + ".com/v1",
                apiKey: "",
                enabled: true,
                models: []
            }
        }
        inChatProviderData = prov
        inChatApiKey = prov.apiKey || ""
        inChatBaseUrl = prov.baseUrl || ""
        inChatStatusText = ""
        showInChatProviderModal = true
    }

    function saveAndSyncInChatProvider() {
        if (!inChatProviderData) return
        var key = inChatApiKey.trim()
        var url = inChatBaseUrl.trim()
        if (!url) {
            inChatStatusText = "❌ API 地址不能为空"
            return
        }

        var updated = Object.assign({}, inChatProviderData)
        updated.baseUrl = url
        updated.apiKey = key
        updated.enabled = true

        var script = providerScriptPath || "provider-manager"
        saveInChatProc.command = [script, "save-provider", JSON.stringify(updated)]
        saveInChatProc.running = true

        inChatIsTesting = true
        inChatStatusText = "⏳ 正在保存并连接端点动态拉取模型..."
        fetchInChatProc.command = [script, "fetch-models", inChatProviderData.id]
        fetchInChatProc.running = true
    }

    Process {
        id: saveInChatProc
        command: []
        running: false
    }

    Process {
        id: fetchInChatProc
        command: []
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                var trimmed = line.trim()
                if (!trimmed) return
                try {
                    var res = JSON.parse(trimmed)
                    if (res.status === "ok") {
                        root.inChatStatusText = "🟢 同步成功 (" + (res.latency || 0) + "ms) · 获得 " + (res.count || 0) + " 个模型"
                        root.activeProviderId = root.inChatProviderData.id
                        if (res.models && res.models.length > 0) {
                            root.aiModel = res.models[0].id
                        }
                        root.loadProvidersConfig()
                        var okMsgs = root.messages.slice()
                        okMsgs.push({
                            role: "system",
                            content: "✅ 已成功配置服务商 [" + (root.inChatProviderData.name || root.inChatProviderData.id) + "] 并激活模型: " + root.aiModel,
                            timestamp: new Date().toISOString()
                        })
                        root.messages = okMsgs
                        Qt.callLater(() => {
                            msgListView.positionViewAtEnd()
                            root.showInChatProviderModal = false
                        })
                    } else {
                        root.inChatStatusText = "❌ " + (res.message || "连接失败")
                    }
                } catch(e) {
                    root.inChatStatusText = "❌ 解析失败: " + e.message
                }
                root.inChatIsTesting = false
            }
        }
        onExited: (code) => {
            root.inChatIsTesting = false
        }
    }

    // Filtered list of models ONLY from enabled / configured providers
    readonly property var availableModelsList: {
        var list = []
        for (var i = 0; i < configuredProviders.length; i++) {
            var p = configuredProviders[i]
            // Only include enabled providers that have an API key or are active
            if ((p.enabled && (p.apiKey || p.id === "ollama")) || p.id === activeProviderId) {
                var models = p.models || []
                for (var j = 0; j < models.length; j++) {
                    var m = models[j]
                    list.push({
                        "id": m.id,
                        "name": m.name || m.id,
                        "providerId": p.id,
                        "providerName": p.name,
                        "desc": m.desc || "排程大模型",
                        "icon": p.icon || "smart_toy",
                        "color": p.color || Theme.primary,
                        "baseUrl": p.baseUrl,
                        "apiKey": p.apiKey
                    })
                }
            }
        }
        // Fallback default if nothing loaded yet
        if (list.length === 0) {
            list.push({
                "id": "agnes-2.5-flash",
                "name": "Agnes 2.5 Flash",
                "providerId": "agnes",
                "providerName": "Agnes AI",
                "desc": "极速响应 · 默认推荐",
                "icon": "bolt",
                "color": "#e65100"
            })
        }
        return list
    }

    readonly property var filteredModelsList: {
        if (!modelSearchFilter || !modelSearchFilter.trim()) {
            return availableModelsList
        }
        var q = modelSearchFilter.trim().toLowerCase()
        var out = []
        for (var i = 0; i < availableModelsList.length; i++) {
            var m = availableModelsList[i]
            if (m.id.toLowerCase().indexOf(q) !== -1 || m.name.toLowerCase().indexOf(q) !== -1 || m.providerName.toLowerCase().indexOf(q) !== -1) {
                out.push(m)
            }
        }
        return out
    }

    // Slash command suggestions popup
    readonly property var availableCommands: [
        { "cmd": "/new", "desc": "开启全新排程会话", "icon": "add_comment" },
        { "cmd": "/session", "desc": "展开历史会话抽屉", "icon": "history" },
        { "cmd": "/model", "desc": "切换当前生效的大模型", "icon": "psychology" },
        { "cmd": "/clear", "desc": "清空当前会话消息", "icon": "delete_sweep" },
        { "cmd": "/help", "desc": "查看指令与快捷键指南", "icon": "help_outline" }
    ]

    property var filteredCommands: []
    property int selectedSlashIndex: 0

    signal scheduleConfirmed()

    color: Theme.surfaceContainerLowest
    radius: Theme.cornerRadius
    clip: true

    Component.onCompleted: {
        initNewSession()
        loadProvidersConfig()
    }

    function initNewSession() {
        currentSessionId = "session_" + Date.now()
        currentSessionTitle = "新排程会话"
        messages = []
        streamingAssistantText = ""
        currentProposal = null
        attachedImagePath = ""
        attachedFilePath = ""
        filteredCommands = []
        selectedSlashIndex = 0
        showModelMenu = false
        quickAddExpanded = false
        modelSearchFilter = ""
        inputHistoryIndex = -1
        temporaryDraft = ""
    }

    function extractProposalFromText(txt) {
        if (!txt) return null
        var match = txt.match(/```(?:json:schedule|schedule|json)?\s*\n([\s\S]*?)\n```/)
        if (match && match[1]) {
            try {
                var p = JSON.parse(match[1].trim())
                if (p && (p.events || p.tasks)) {
                    return p
                }
            } catch(e) {}
        }
        return null
    }

    function loadSession(sessionId) {
        currentSessionId = sessionId
        var script = sessionScriptPath || Qt.resolvedUrl("../../session-manager").toString().replace(/^file:\/\//, "")
        loadSessionProc.running = false
        loadSessionProc.command = [script, "get", sessionId]
        loadSessionProc.running = true
    }

    Process {
        id: loadSessionProc
        command: []
        running: false
        stdout: StdioCollector {
            id: loadSessionCollector
            onStreamFinished: {
                var raw = (text || "").trim()
                if (!raw) return
                try {
                    var data = JSON.parse(raw)
                    root.currentSessionId = data.id || root.currentSessionId
                    root.currentSessionTitle = data.title || "未命名会话"
                    root.messages = data.messages || []
                    var hist = []
                    var loadedMsgs = data.messages || []
                    for (var i = loadedMsgs.length - 1; i >= 0; i--) {
                        if (loadedMsgs[i].role === "user" && loadedMsgs[i].content) {
                            if (hist.length === 0 || hist[hist.length - 1] !== loadedMsgs[i].content) {
                                hist.push(loadedMsgs[i].content)
                            }
                        }
                    }
                    root.inputHistory = hist
                    root.inputHistoryIndex = -1
                    root.temporaryDraft = ""
                    Qt.callLater(() => {
                        msgListView.positionViewAtEnd()
                    })
                } catch(e) {
                    console.warn("[dankCalendarAgenda] load session parse failed:", e)
                }
            }
        }

        onExited: (code) => {
            if (code === 0 && loadSessionCollector.text) {
                try {
                    var raw = loadSessionCollector.text.trim()
                    if (raw) {
                        var data = JSON.parse(raw)
                        root.currentSessionId = data.id || root.currentSessionId
                        root.currentSessionTitle = data.title || "未命名会话"
                        root.messages = data.messages || []
                        var hist = []
                        var loadedMsgs = data.messages || []
                        for (var i = loadedMsgs.length - 1; i >= 0; i--) {
                            if (loadedMsgs[i].role === "user" && loadedMsgs[i].content) {
                                if (hist.length === 0 || hist[hist.length - 1] !== loadedMsgs[i].content) {
                                    hist.push(loadedMsgs[i].content)
                                }
                            }
                        }
                        root.inputHistory = hist
                        root.inputHistoryIndex = -1
                        root.temporaryDraft = ""
                        Qt.callLater(() => {
                            msgListView.positionViewAtEnd()
                        })
                    }
                } catch(e) {}
            }
        }
    }

    function updateMessageProposal(msgIndex, updatedProposal) {
        if (msgIndex >= 0 && msgIndex < messages.length) {
            var prevContentY = msgListView.contentY
            var newMsgs = messages.slice()
            var targetMsg = Object.assign({}, newMsgs[msgIndex])
            targetMsg.proposal = updatedProposal
            newMsgs[msgIndex] = targetMsg
            messages = newMsgs
            saveCurrentSessionToDisk()
            Qt.callLater(() => {
                msgListView.contentY = prevContentY
            })
        }
    }

    function saveCurrentSessionToDisk() {
        if (!currentSessionId) return
        var script = sessionScriptPath || Qt.resolvedUrl("../../session-manager").toString().replace(/^file:\/\//, "")
        var payload = {
            "id": currentSessionId,
            "title": currentSessionTitle,
            "messages": messages
        }
        saveSessionProc.running = false
        saveSessionProc.command = [script, "save", JSON.stringify(payload)]
        saveSessionProc.running = true
    }

    Process {
        id: saveSessionProc
        command: []
        running: false
    }

    // AI Generation Process
    Process {
        id: aiProc
        command: []
        running: false

        stdout: SplitParser {
            onRead: (line) => {
                var trimmed = line.trim()
                if (!trimmed.startsWith("data:")) return
                var dataStr = trimmed.substring(5).trim()
                if (!dataStr) return
                try {
                    var ev = JSON.parse(dataStr)
                    if (ev.type === "delta") {
                        root.streamingAssistantText += ev.content
                        Qt.callLater(() => msgListView.positionViewAtEnd())
                    } else if (ev.type === "proposal") {
                        root.currentProposal = ev.proposal
                    } else if (ev.type === "done") {
                        var finalProp = ev.proposal || root.currentProposal || root.extractProposalFromText(root.streamingAssistantText)
                        root.finishGeneration(ev.title, finalProp)
                    } else if (ev.type === "error") {
                        root.handleError(ev.code, ev.message)
                    }
                } catch(e) {}
            }
        }

        onExited: (exitCode) => {
            if (root.isGenerating) {
                if (root.streamingAssistantText) {
                    root.finishGeneration(root.currentSessionTitle, root.currentProposal || root.extractProposalFromText(root.streamingAssistantText))
                } else {
                    root.isGenerating = false
                }
            }
        }
    }

    function stopGeneration() {
        if (aiProc.running) {
            aiProc.running = false
        }
        if (streamingAssistantText) {
            finishGeneration(currentSessionTitle, currentProposal || extractProposalFromText(streamingAssistantText))
        } else {
            isGenerating = false
        }
    }

    function finishGeneration(sessionTitle, proposal) {
        if (sessionTitle && (currentSessionTitle === "新排程会话" || currentSessionTitle === "未命名会话" || currentSessionTitle.length <= 4)) {
            currentSessionTitle = sessionTitle
        }
        var finalProposal = proposal || extractProposalFromText(streamingAssistantText)
        var newMsgs = messages.slice()
        newMsgs.push({
            role: "assistant",
            content: streamingAssistantText,
            proposal: finalProposal,
            timestamp: new Date().toISOString()
        })
        messages = newMsgs
        streamingAssistantText = ""
        currentProposal = null
        isGenerating = false
        Qt.callLater(() => msgListView.positionViewAtEnd())
    }

    function handleError(code, errMsg) {
        var newMsgs = messages.slice()
        newMsgs.push({
            role: "assistant",
            content: errMsg || "发生未知错误，请检查网络或 API Key 设置。",
            error: true,
            timestamp: new Date().toISOString()
        })
        messages = newMsgs
        streamingAssistantText = ""
        currentProposal = null
        isGenerating = false
        Qt.callLater(() => msgListView.positionViewAtEnd())
    }

    function isLikelyFilePath(str) {
        if (!str) return false
        var s = str.trim()
        var lower = s.toLowerCase()
        var hasPrefix = s.startsWith("/") || s.startsWith("file://") || s.startsWith("~") || s.indexOf("/clipboard/") !== -1 || s.indexOf("/tmp/") !== -1
        var hasExt = lower.endsWith(".png") || lower.endsWith(".jpg") || lower.endsWith(".jpeg") || lower.endsWith(".webp") ||
                     lower.endsWith(".txt") || lower.endsWith(".md") || lower.endsWith(".json") || lower.endsWith(".pdf")
        return hasPrefix && hasExt
    }

    function isSlashCommand(str) {
        if (!str || !str.startsWith("/")) return false
        var firstWord = str.trim().split(" ")[0].toLowerCase()
        return firstWord === "/new" || firstWord === "/clear" || firstWord === "/session" || 
               firstWord === "/history" || firstWord === "/model" || firstWord === "/help"
    }

    function executeCommand(cmdStr) {
        var parts = cmdStr.trim().split(" ")
        var cmd = parts[0].toLowerCase()

        if (cmd === "/new") {
            initNewSession()
            chatInputField.text = ""
        } else if (cmd === "/clear") {
            messages = []
            saveCurrentSessionToDisk()
            chatInputField.text = ""
            var clearMsgs = []
            clearMsgs.push({
                role: "system",
                content: "已清空当前会话的消息记录。",
                timestamp: new Date().toISOString()
            })
            messages = clearMsgs
            Qt.callLater(() => msgListView.positionViewAtEnd())
        } else if (cmd === "/session" || cmd === "/history") {
            showDrawer = !showDrawer
            chatInputField.text = ""
        } else if (cmd === "/model") {
            if (parts.length > 1) {
                selectModel(parts[1].trim())
            } else {
                showCommandPalette = true
                commandPalette.enterMode("model")
            }
            chatInputField.text = ""
        } else if (cmd === "/provider") {
            showCommandPalette = true
            commandPalette.enterMode("provider")
            chatInputField.text = ""
        } else if (cmd === "/help") {
            var helpMsgs = messages.slice()
            helpMsgs.push({
                role: "system",
                content: "【支持的指令与快捷键】\n• 输入 / 唤出全键盘 Command Palette 指令浮层\n• /model : 上下键快速切换大模型\n• /history : 上下键快速切换历史会话\n• /provider : 快速切换 AI 服务商\n• /new : 开启全新排程会话\n• /clear : 清空当前会话内容\n• Ctrl+N : 新建会话 | Ctrl+H : 历史抽屉 | Ctrl+V : 粘贴截图",
                timestamp: new Date().toISOString()
            })
            messages = helpMsgs
            chatInputField.text = ""
            Qt.callLater(() => msgListView.positionViewAtEnd())
        }
        filteredCommands = []
        selectedSlashIndex = 0
    }

    function selectModel(modelId, providerId) {
        aiModel = modelId
        if (providerId) {
            activeProviderId = providerId
        } else if (configuredProviders && configuredProviders.length > 0) {
            for (var i = 0; i < configuredProviders.length; i++) {
                var p = configuredProviders[i]
                if (p.models) {
                    for (var j = 0; j < p.models.length; j++) {
                        if (p.models[j].id === modelId) {
                            activeProviderId = p.id
                            break
                        }
                    }
                }
            }
        }
        showModelMenu = false

        // Sync to providers.json
        var script = providerScriptPath || "provider-manager"
        setActiveProc.command = [script, "set-active", activeProviderId, modelId]
        setActiveProc.running = true

        var sysMsgs = messages.slice()
        sysMsgs.push({
            role: "system",
            content: "已切换生效模型为: " + modelId,
            timestamp: new Date().toISOString()
        })
        messages = sysMsgs
        Qt.callLater(() => msgListView.positionViewAtEnd())
    }

    function selectProvider(pId) {
        var targetProv = null
        if (providersConfig && providersConfig.providers) {
            for (var i = 0; i < providersConfig.providers.length; i++) {
                if (providersConfig.providers[i].id === pId) {
                    targetProv = providersConfig.providers[i]
                    break
                }
            }
        }

        var pName = targetProv ? (targetProv.name || pId) : pId
        var hasKey = targetProv ? (!!targetProv.apiKey && targetProv.apiKey.trim().length > 0) || pId === "ollama" : false
        var hasModels = targetProv && targetProv.models && targetProv.models.length > 0

        if (!hasKey) {
            var warnMsgs = messages.slice()
            warnMsgs.push({
                role: "system",
                content: "⚠️ 服务商 [" + pName + "] 尚未配置 API Key。已为您弹出配置窗口，可直接在下方填写并测试：",
                providerIdToConfig: pId,
                timestamp: new Date().toISOString()
            })
            messages = warnMsgs
            Qt.callLater(() => msgListView.positionViewAtEnd())
            openInChatProviderConfig(pId)
            return
        }

        activeProviderId = pId
        showModelMenu = false
        var script = providerScriptPath || "provider-manager"
        setActiveProc.command = [script, "set-active", pId]
        setActiveProc.running = true

        if (hasModels) {
            aiModel = targetProv.models[0].id
        }

        var sysMsgs = messages.slice()
        sysMsgs.push({
            role: "system",
            content: "已切换生效服务商为: " + pName + (aiModel ? (" (模型: " + aiModel + ")") : ""),
            timestamp: new Date().toISOString()
        })
        messages = sysMsgs
        Qt.callLater(() => msgListView.positionViewAtEnd())
        loadProvidersConfig()
    }

    Process {
        id: setActiveProc
        command: []
        running: false
    }

    function updateSlashSuggestions(text) {
        if (!text || !text.startsWith("/") || isLikelyFilePath(text)) {
            filteredCommands = []
            selectedSlashIndex = 0
            return
        }
        var query = text.toLowerCase()
        var matches = []
        for (var i = 0; i < availableCommands.length; i++) {
            var c = availableCommands[i]
            if (c.cmd.startsWith(query)) {
                matches.push(c)
            }
        }
        filteredCommands = matches
        selectedSlashIndex = 0
    }

    function sendMessage(text) {
        var clean = text ? text.trim() : ""

        // Check if input is a file path pasted directly
        if (isLikelyFilePath(clean)) {
            var fpath = clean.replace(/^file:\/\//, "")
            var lower = fpath.toLowerCase()
            if (lower.endsWith(".png") || lower.endsWith(".jpg") || lower.endsWith(".jpeg") || lower.endsWith(".webp")) {
                attachedImagePath = fpath
            } else {
                attachedFilePath = fpath
            }
            clean = ""
        }

        if (!clean && !attachedImagePath && !attachedFilePath) return

        // 1. Only handle registered slash commands
        if (isSlashCommand(clean)) {
            executeCommand(clean)
            return
        }

        // 2. User Message Construction
        var userImg = attachedImagePath
        var userFile = attachedFilePath
        attachedImagePath = ""
        attachedFilePath = ""
        filteredCommands = []
        selectedSlashIndex = 0
        showModelMenu = false

        var newMsgs = messages.slice()
        newMsgs.push({
            role: "user",
            content: clean || (userImg ? "已附加截图/图片" : "已附加日程文档"),
            imagePath: userImg,
            filePath: userFile,
            timestamp: new Date().toISOString()
        })
        messages = newMsgs

        if (clean) {
            var hist = root.inputHistory.slice()
            if (hist.length === 0 || hist[0] !== clean) {
                hist.unshift(clean)
            }
            root.inputHistory = hist
            root.inputHistoryIndex = -1
            root.temporaryDraft = ""
        }

        chatInputField.text = ""
        isGenerating = true
        streamingAssistantText = ""
        currentProposal = null

        Qt.callLater(() => msgListView.positionViewAtEnd())

        // 3. Launch Backend Streaming Request
        var reqPayload = {
            apiKey: aiApiKey,
            baseUrl: aiBaseUrl,
            model: aiModel,
            prompt: clean,
            imagePath: userImg,
            filePath: userFile,
            sessionId: currentSessionId,
            systemPrompt: customSystemPrompt
        }

        var script = aiScriptPath || Qt.resolvedUrl("../../ai-client").toString().replace(/^file:\/\//, "")
        aiProc.command = [script, JSON.stringify(reqPayload)]
        aiProc.running = true
    }

    // Window-level Shortcut for Ctrl+V
    Shortcut {
        sequences: ["Ctrl+V", "Control+V"]
        context: Qt.WindowShortcut
        onActivated: {
            root.triggerPasteClipboard()
        }
    }

    function triggerPasteClipboard() {
        var script = pasteHelperPath || Qt.resolvedUrl("../../clipboard-paste-helper").toString().replace(/^file:\/\//, "")
        pasteClipboardProc.command = [script]
        pasteClipboardProc.running = true
    }

    // Python Clipboard paste helper process using SplitParser for fresh execution
    Process {
        id: pasteClipboardProc
        command: []
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                var trimmed = line.trim()
                if (!trimmed) return
                try {
                    var res = JSON.parse(trimmed)
                    if (res.status === "ok") {
                        if (res.type === "image") {
                            root.attachedImagePath = res.path
                        } else if (res.type === "file") {
                            root.attachedFilePath = res.path
                        } else if (res.type === "text" && res.content) {
                            if (chatInputField.text) {
                                chatInputField.text += res.content
                            } else {
                                chatInputField.text = res.content
                            }
                        }
                    }
                } catch(e) {}
            }
        }
    }

    // Native DMS File Browser Modal
    DMSFileBrowser.FileBrowserSurfaceModal {
        id: nativeFileBrowser
        browserTitle: "选择图片或日程文档"
        browserIcon: "folder_open"
        fileExtensions: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.txt", "*.md", "*.json", "*.pdf"]
        allowStacking: true
        keepPopoutsOpen: true
        onFileSelected: (path) => {
            var cleanPath = path.toString().replace(/^file:\/\//, "")
            var lower = cleanPath.toLowerCase()
            if (lower.endsWith(".png") || lower.endsWith(".jpg") || lower.endsWith(".jpeg") || lower.endsWith(".webp")) {
                root.attachedImagePath = cleanPath
            } else {
                root.attachedFilePath = cleanPath
            }
        }
    }

    function openAttachmentPicker() {
        nativeFileBrowser.open()
    }

    // Drag and Drop support
    DropArea {
        anchors.fill: parent
        onDropped: (drop) => {
            if (drop.hasUrls && drop.urls.length > 0) {
                var url = drop.urls[0].toString().replace(/^file:\/\//, "")
                var lower = url.toLowerCase()
                if (lower.endsWith(".png") || lower.endsWith(".jpg") || lower.endsWith(".jpeg") || lower.endsWith(".webp")) {
                    root.attachedImagePath = url
                } else {
                    root.attachedFilePath = url
                }
                drop.accept()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingS
        spacing: Theme.spacingS

        // 1. Session Sub-Header Bar (Clean Material 3 Card)
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 36
            color: Theme.surfaceContainerHigh
            radius: Theme.cornerRadius

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                spacing: Theme.spacingS

                // Session drawer toggle button
                StyledRect {
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: 8
                    color: drawerHover.hovered ? Theme.surfaceContainerHighest : "transparent"

                    DankIcon {
                        anchors.centerIn: parent
                        name: "history"
                        size: 16
                        color: Theme.surfaceText
                    }

                    HoverHandler { id: drawerHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showDrawer = !root.showDrawer
                    }
                }

                // Title
                StyledText {
                    Layout.fillWidth: true
                    text: root.currentSessionTitle
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    wrapMode: Text.NoWrap
                }

                // Active Interactive Model Switcher Button (Raycast AI Style)
                StyledRect {
                    id: modelChipBtn
                    implicitWidth: modelRow.implicitWidth + Theme.spacingM * 2
                    implicitHeight: 24
                    radius: 12
                    color: modelChipHover.hovered ? Theme.primaryContainer : Theme.surfaceContainerLowest
                    border.width: 1
                    border.color: Theme.outlineVariant

                    RowLayout {
                        id: modelRow
                        anchors.centerIn: parent
                        spacing: 4

                        DankIcon {
                            name: "bolt"
                            size: 13
                            color: modelChipHover.hovered ? Theme.onPrimaryContainer : Theme.primary
                        }

                        StyledText {
                            text: root.aiModel
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: modelChipHover.hovered ? Theme.onPrimaryContainer : Theme.primary
                        }

                        DankIcon {
                            name: root.showModelMenu ? "expand_less" : "expand_more"
                            size: 13
                            color: modelChipHover.hovered ? Theme.onPrimaryContainer : Theme.surfaceVariantText
                        }
                    }

                    HoverHandler { id: modelChipHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.loadProvidersConfig()
                            if (root.showCommandPalette && commandPalette.currentMode === "model") {
                                root.showCommandPalette = false
                            } else {
                                root.showCommandPalette = true
                                commandPalette.enterMode("model")
                            }
                        }
                    }
                }

                // Quick Direct Provider Settings Button
                StyledRect {
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: 8
                    color: provQuickHover.hovered ? Theme.surfaceContainerHighest : "transparent"

                    DankIcon {
                        anchors.centerIn: parent
                        name: "tune"
                        size: 15
                        color: Theme.primary
                    }

                    HoverHandler { id: provQuickHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.openInChatProviderConfig(root.activeProviderId)
                        }
                    }
                }

                // New Chat Button
                StyledRect {
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: 8
                    color: newHover.hovered ? Theme.surfaceContainerHighest : "transparent"

                    DankIcon {
                        anchors.centerIn: parent
                        name: "add_comment"
                        size: 16
                        color: Theme.primary
                    }

                    HoverHandler { id: newHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.initNewSession()
                    }
                }
            }
        }

        // 2. Chat Messages Area
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: msgListView
                anchors.fill: parent
                clip: true
                spacing: Theme.spacingM
                model: root.messages

                delegate: ColumnLayout {
                    id: msgDelegate
                    required property var modelData
                    required property int index

                    width: msgListView.width
                    spacing: Theme.spacingXS

                    // User Message (Right-aligned)
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: userBubble.implicitHeight
                        visible: modelData.role === "user"

                        StyledRect {
                            id: userBubble
                            anchors.right: parent.right
                            width: Math.min(parent.width * 0.85, uCol.implicitWidth + Theme.spacingM * 2)
                            implicitHeight: uCol.implicitHeight + Theme.spacingS * 2
                            color: Theme.primaryContainer
                            radius: 14

                            ColumnLayout {
                                id: uCol
                                anchors.fill: parent
                                anchors.margins: Theme.spacingS
                                spacing: Theme.spacingXS

                                // Image Thumbnail inside bubble
                                Image {
                                    visible: !!modelData.imagePath
                                    source: modelData.imagePath ? ("file://" + modelData.imagePath) : ""
                                    Layout.preferredWidth: Math.min(220, userBubble.width - 24)
                                    Layout.preferredHeight: 130
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }

                                // File pill if present
                                StyledRect {
                                    visible: !!modelData.filePath
                                    implicitWidth: fRow.implicitWidth + 12
                                    implicitHeight: 22
                                    radius: 6
                                    color: Theme.surfaceContainerHighest

                                    RowLayout {
                                        id: fRow
                                        anchors.centerIn: parent
                                        spacing: 4

                                        DankIcon {
                                            name: "description"
                                            size: 13
                                            color: Theme.primary
                                        }
                                        StyledText {
                                            text: modelData.filePath ? modelData.filePath.split("/").pop() : ""
                                            font.pixelSize: 10
                                            color: Theme.surfaceText
                                        }
                                    }
                                }

                                TextEdit {
                                    Layout.fillWidth: true
                                    text: modelData.content || ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.onPrimaryContainer
                                    wrapMode: TextEdit.WrapAnywhere
                                    readOnly: true
                                    selectByMouse: true
                                    cursorVisible: false
                                    selectionColor: Theme.primary
                                    selectedTextColor: Theme.onPrimary
                                }
                            }
                        }
                    }

                    // Assistant Message (Left-aligned)
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: modelData.role === "assistant"
                        spacing: Theme.spacingXS

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingXS

                            DankIcon {
                                name: modelData.error ? "error" : "smart_toy"
                                size: 16
                                color: modelData.error ? "#d32f2f" : Theme.primary
                            }

                            StyledText {
                                text: modelData.error ? "排程助理 (遇到错误)" : "排程助理"
                                font.pixelSize: Theme.fontSizeSmall * 0.9
                                font.weight: Font.Bold
                                color: modelData.error ? "#d32f2f" : Theme.primary
                            }

                            Item { Layout.fillWidth: true }

                            // Quick Copy Button with visual feedback
                            StyledRect {
                                id: copyBtn
                                property bool copied: false
                                implicitWidth: copyRow.implicitWidth + 12
                                implicitHeight: 22
                                radius: 6
                                color: copyHover.hovered ? Theme.surfaceContainerHighest : "transparent"

                                Timer {
                                    id: resetCopyTimer
                                    interval: 2000
                                    onTriggered: copyBtn.copied = false
                                }

                                RowLayout {
                                    id: copyRow
                                    anchors.centerIn: parent
                                    spacing: 3

                                    DankIcon {
                                        name: copyBtn.copied ? "check" : "content_copy"
                                        size: 12
                                        color: copyBtn.copied ? "#2e7d32" : (copyHover.hovered ? Theme.primary : Theme.surfaceVariantText)
                                    }

                                    StyledText {
                                        text: copyBtn.copied ? "已复制" : "复制"
                                        font.pixelSize: 10
                                        color: copyBtn.copied ? "#2e7d32" : (copyHover.hovered ? Theme.primary : Theme.surfaceVariantText)
                                    }
                                }

                                HoverHandler { id: copyHover }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.copyToClipboard(modelData.content || "");
                                        copyBtn.copied = true;
                                        resetCopyTimer.restart();
                                    }
                                }
                            }
                        }

                        StyledRect {
                            Layout.fillWidth: true
                            implicitHeight: aText.implicitHeight + Theme.spacingM * 2
                            color: modelData.error ? "#ffebee" : Theme.surfaceContainerHigh
                            radius: 14
                            border.width: modelData.error ? 1 : 0
                            border.color: "#d32f2f"

                            TextEdit {
                                id: aText
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                text: modelData.content || ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: modelData.error ? "#c62828" : Theme.surfaceText
                                wrapMode: TextEdit.WrapAnywhere
                                readOnly: true
                                selectByMouse: true
                                cursorVisible: false
                                selectionColor: Theme.primary
                                selectedTextColor: Theme.onPrimary
                                textFormat: TextEdit.AutoText
                            }
                        }

                        // Embedded Proposal Card if present
                        ScheduleProposalCard {
                            Layout.fillWidth: true
                            visible: !!modelData.proposal
                            proposal: modelData.proposal
                            batchScriptPath: root.batchScriptPath
                            onConfirmed: (updatedProposal) => {
                                root.updateMessageProposal(index, updatedProposal)
                                root.scheduleConfirmed()
                            }
                        }
                    }

                    // System message
                    StyledRect {
                        Layout.fillWidth: true
                        visible: modelData.role === "system"
                        implicitHeight: sysCol.implicitHeight + Theme.spacingS * 2
                        radius: 8
                        color: (modelData.content && modelData.content.indexOf("⚠️") !== -1) ? Qt.rgba(255/255, 160/255, 0, 0.12) : "transparent"
                        border.width: (modelData.content && modelData.content.indexOf("⚠️") !== -1) ? 1 : 0
                        border.color: Qt.rgba(255/255, 160/255, 0, 0.3)

                        ColumnLayout {
                            id: sysCol
                            anchors.fill: parent
                            anchors.margins: Theme.spacingS
                            spacing: 4

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.content || ""
                                font.pixelSize: Theme.fontSizeSmall * 0.85
                                color: (modelData.content && modelData.content.indexOf("⚠️") !== -1) ? "#ffb300" : Theme.surfaceVariantText
                                wrapMode: Text.WrapAnywhere
                            }

                            StyledRect {
                                visible: !!modelData.providerIdToConfig
                                implicitWidth: cfgBtnText.implicitWidth + 16
                                implicitHeight: 24
                                radius: 6
                                color: Theme.primary

                                StyledText {
                                    id: cfgBtnText
                                    anchors.centerIn: parent
                                    text: "⚙️ 立即在此配置 API Key"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: "#ffffff"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openInChatProviderConfig(modelData.providerIdToConfig)
                                }
                            }
                        }
                    }
                }

                // Streaming Assistant Response
                footer: ColumnLayout {
                    width: msgListView.width
                    visible: root.isGenerating
                    spacing: Theme.spacingXS

                    RowLayout {
                        spacing: Theme.spacingXS

                        DankIcon {
                            name: "smart_toy"
                            size: 15
                            color: Theme.primary
                        }

                        StyledText {
                            text: "排程助理正在思考与规划..."
                            font.pixelSize: Theme.fontSizeSmall * 0.85
                            font.weight: Font.Bold
                            color: Theme.primary
                        }
                    }

                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: streamingText.implicitHeight + Theme.spacingM * 2
                        color: Theme.surfaceContainerHigh
                        radius: 14

                        TextEdit {
                            id: streamingText
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            text: root.streamingAssistantText + " ▍"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            wrapMode: TextEdit.WrapAnywhere
                            readOnly: true
                            selectByMouse: true
                            cursorVisible: false
                            textFormat: TextEdit.AutoText
                        }
                    }
                }
            }

            // Starter Suggestions (When empty)
            Item {
                anchors.fill: parent
                visible: root.messages.length === 0 && !root.isGenerating

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Theme.spacingM
                    width: parent.width - Theme.spacingL * 2

                    DankIcon {
                        Layout.alignment: Qt.AlignHCenter
                        name: "auto_awesome"
                        size: 38
                        color: Theme.primary
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Dank Calendar 智能排程助理"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: "输入排程需求、Ctrl+V 粘贴截图或选用快捷指令"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    // Modern Starter Cards
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        StyledRect {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: Theme.cornerRadius
                            color: sug1Hover.hovered ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

                            StyledText {
                                anchors.centerIn: parent
                                text: "💡 规划明天下午 14:00-14:30 午休并添加待办"
                                font.pixelSize: Theme.fontSizeSmall * 0.9
                                color: Theme.primary
                            }

                            HoverHandler { id: sug1Hover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.sendMessage("帮我规划明天下午 14:00 到 14:30 午休，并创建对应的待办。")
                            }
                        }

                        StyledRect {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: Theme.cornerRadius
                            color: sug2Hover.hovered ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

                            StyledText {
                                anchors.centerIn: parent
                                text: "📸 粘贴截图提取日程与待办 (按 Ctrl+V 或点击 📋 粘贴)"
                                font.pixelSize: Theme.fontSizeSmall * 0.9
                                color: Theme.secondary || Theme.primary
                            }

                            HoverHandler { id: sug2Hover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.triggerPasteClipboard()
                            }
                        }
                    }
                }
            }



            Process {
                id: quickAddProc
                command: []
                running: false
                stdout: SplitParser {
                    onRead: (line) => {
                        root.loadProvidersConfig()
                    }
                }
            }

            // Slide-out Session Drawer
            SessionDrawer {
                id: sessionDrawer
                anchors.fill: parent
                visible: root.showDrawer
                sessionScriptPath: root.sessionScriptPath
                currentSessionId: root.currentSessionId
                onSessionSelected: (sId) => {
                    root.loadSession(sId)
                    root.showDrawer = false
                }
                onCloseRequested: {
                    root.showDrawer = false
                }
                onSessionCleared: {
                    root.initNewSession()
                    root.showDrawer = false
                }
            }
        }

        // 3. Modern LLM Input Box Container (ChatGPT / Claude Style)
        Item {
            Layout.fillWidth: true
            implicitHeight: inputCard.implicitHeight

            // Floating OpenCode-Style Hierarchical Command Palette
            CommandPalette {
                id: commandPalette
                visible: root.showCommandPalette
                anchors.bottom: inputCard.top
                anchors.bottomMargin: Theme.spacingS
                anchors.left: parent.left
                anchors.right: parent.right
                z: 50

                sessionList: sessionDrawer.sessionsList
                providerConfig: root.providersConfig

                onSelectSession: (sId) => {
                    root.loadSession(sId)
                    chatInputField.text = ""
                    root.showCommandPalette = false
                }

                onSelectModel: (mId, pId) => {
                    root.selectModel(mId, pId)
                    chatInputField.text = ""
                    root.showCommandPalette = false
                }

                onSelectProvider: (pId) => {
                    root.selectProvider(pId)
                    chatInputField.text = ""
                    root.showCommandPalette = false
                }

                onExecuteCommand: (cmd) => {
                    root.executeCommand(cmd)
                    chatInputField.text = ""
                    root.showCommandPalette = false
                }

                onCloseRequested: {
                    root.showCommandPalette = false
                }
            }

            // Outer Input Card (Full ChatGPT Style)
            StyledRect {
                id: inputCard
                width: parent.width
                implicitHeight: inputCardCol.implicitHeight + Theme.spacingS * 2
                color: Theme.surfaceContainerHigh
                radius: 16
                border.width: 1
                border.color: chatInputField.activeFocus ? Theme.primary : Theme.outlineVariant

                ColumnLayout {
                    id: inputCardCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    spacing: Theme.spacingXS

                    // Attached Media Previews (Rich 60x60 thumbnail & doc pill)
                    RowLayout {
                        visible: !!root.attachedImagePath || !!root.attachedFilePath
                        spacing: Theme.spacingS
                        Layout.bottomMargin: 2

                        // Image Preview Card (Real Thumbnail + Delete Button)
                        StyledRect {
                            visible: !!root.attachedImagePath
                            implicitWidth: 64
                            implicitHeight: 64
                            radius: 10
                            color: Theme.surfaceContainerHighest
                            clip: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: 2
                                source: root.attachedImagePath ? ("file://" + root.attachedImagePath) : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            // Delete badge
                            StyledRect {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 3
                                width: 18
                                height: 18
                                radius: 9
                                color: "#cc000000"

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "close"
                                    size: 12
                                    color: "#ffffff"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.attachedImagePath = ""
                                }
                            }
                        }

                        // Document Preview Card
                        StyledRect {
                            visible: !!root.attachedFilePath
                            implicitWidth: docRow.implicitWidth + Theme.spacingM * 2
                            implicitHeight: 32
                            radius: 8
                            color: Theme.surfaceContainerHighest

                            RowLayout {
                                id: docRow
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS

                                DankIcon {
                                    name: "description"
                                    size: 16
                                    color: Theme.primary
                                }

                                StyledText {
                                    text: root.attachedFilePath ? root.attachedFilePath.split("/").pop() : "文档"
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }

                                DankIcon {
                                    name: "close"
                                    size: 14
                                    color: Theme.surfaceVariantText

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.attachedFilePath = ""
                                    }
                                }
                            }
                        }
                    }

                    // Main Text Input Field
                    DankTextField {
                        id: chatInputField
                        Layout.fillWidth: true
                        placeholderText: "输入排程需求、按 Ctrl+V 粘贴截图或输入 / 选用指令..."
                        focus: true
                        keyForwardTargets: [chatInputField]

                        onTextChanged: {
                            if (root.isLikelyFilePath(text)) {
                                var fpath = text.trim().replace(/^file:\/\//, "")
                                var lower = fpath.toLowerCase()
                                if (lower.endsWith(".png") || lower.endsWith(".jpg") || lower.endsWith(".jpeg") || lower.endsWith(".webp")) {
                                    root.attachedImagePath = fpath
                                } else {
                                    root.attachedFilePath = fpath
                                }
                                text = ""
                                return
                            }

                            if (text.startsWith("/")) {
                                root.showCommandPalette = true
                                var clean = text.substring(1).trim()
                                if (clean.startsWith("history")) {
                                    commandPalette.enterMode("history", clean.substring(7).trim())
                                } else if (clean.startsWith("model")) {
                                    commandPalette.enterMode("model", clean.substring(5).trim())
                                } else if (clean.startsWith("provider")) {
                                    commandPalette.enterMode("provider", clean.substring(8).trim())
                                } else {
                                    commandPalette.enterMode("root", clean)
                                }
                            } else {
                                root.showCommandPalette = false
                            }
                        }

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier)) {
                                event.accepted = true
                                root.triggerPasteClipboard()
                                return
                            }

                            if (root.showCommandPalette) {
                                if (commandPalette.handleKey(event)) {
                                    return
                                }
                            }

                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (event.modifiers & Qt.ShiftModifier) {
                                    // Shift+Enter
                                } else {
                                    event.accepted = true
                                    if (root.isGenerating) {
                                        root.stopGeneration()
                                    } else {
                                        root.sendMessage(text)
                                    }
                                }
                            } else if (event.key === Qt.Key_Up) {
                                if (!root.showCommandPalette) {
                                    if (root.inputHistory.length > 0) {
                                        if (root.inputHistoryIndex === -1) {
                                            root.temporaryDraft = chatInputField.text
                                        }
                                        if (root.inputHistoryIndex < root.inputHistory.length - 1) {
                                            root.inputHistoryIndex++
                                            chatInputField.text = root.inputHistory[root.inputHistoryIndex]
                                            event.accepted = true
                                            return
                                        }
                                    }
                                }
                            } else if (event.key === Qt.Key_Down) {
                                if (!root.showCommandPalette) {
                                    if (root.inputHistoryIndex > 0) {
                                        root.inputHistoryIndex--
                                        chatInputField.text = root.inputHistory[root.inputHistoryIndex]
                                        event.accepted = true
                                        return
                                    } else if (root.inputHistoryIndex === 0) {
                                        root.inputHistoryIndex = -1
                                        chatInputField.text = root.temporaryDraft
                                        event.accepted = true
                                        return
                                    }
                                }
                            } else if (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier)) {
                                event.accepted = true
                                root.initNewSession()
                            } else if (event.key === Qt.Key_H && (event.modifiers & Qt.ControlModifier)) {
                                event.accepted = true
                                root.showDrawer = !root.showDrawer
                            } else if (event.key === Qt.Key_Escape) {
                                if (root.isGenerating) {
                                    event.accepted = true
                                    root.stopGeneration()
                                } else if (root.showDrawer) {
                                    event.accepted = true
                                    root.showDrawer = false
                                } else if (root.showModelMenu) {
                                    event.accepted = true
                                    root.showModelMenu = false
                                }
                            }
                        }
                    }

                    // Bottom Action Toolbar Row (ChatGPT / Gemini Style)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        // 1. Paste Screenshot Button (📋)
                        StyledRect {
                            implicitWidth: 30
                            implicitHeight: 30
                            radius: 8
                            color: pasteClipHover.hovered ? Theme.surfaceContainerHighest : "transparent"

                            DankIcon {
                                anchors.centerIn: parent
                                name: "content_paste"
                                size: 17
                                color: root.attachedImagePath ? Theme.primary : Theme.surfaceText
                            }

                            HoverHandler { id: pasteClipHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.triggerPasteClipboard()
                            }
                        }

                        // 2. Attach File Button (📎)
                        StyledRect {
                            implicitWidth: 30
                            implicitHeight: 30
                            radius: 8
                            color: clipHover.hovered ? Theme.surfaceContainerHighest : "transparent"

                            DankIcon {
                                anchors.centerIn: parent
                                name: "attach_file"
                                size: 17
                                color: Theme.surfaceText
                            }

                            HoverHandler { id: clipHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openAttachmentPicker()
                            }
                        }

                        // 3. Slash Command Shortcut Pill (/)
                        StyledRect {
                            implicitWidth: slashPillRow.implicitWidth + 12
                            implicitHeight: 24
                            radius: 6
                            color: slashPillHover.hovered ? Theme.surfaceContainerHighest : "transparent"

                            RowLayout {
                                id: slashPillRow
                                anchors.centerIn: parent
                                spacing: 2

                                DankIcon {
                                    name: "terminal"
                                    size: 13
                                    color: Theme.surfaceVariantText
                                }

                                StyledText {
                                    text: "指令 (/)"
                                    font.pixelSize: 11
                                    color: Theme.surfaceVariantText
                                }
                            }

                            HoverHandler { id: slashPillHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    chatInputField.text = "/"
                                    chatInputField.forceActiveFocus()
                                }
                            }
                        }

                        // Spacer
                        Item { Layout.fillWidth: true }

                        // 4. Send / Stop Circle Button
                        StyledRect {
                            implicitWidth: 32
                            implicitHeight: 32
                            radius: 16
                            color: root.isGenerating ? "#d32f2f" : Theme.primary

                            DankIcon {
                                anchors.centerIn: parent
                                name: root.isGenerating ? "stop" : "arrow_upward"
                                size: 18
                                color: "#ffffff"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.isGenerating) {
                                        root.stopGeneration()
                                    } else {
                                        root.sendMessage(chatInputField.text)
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
