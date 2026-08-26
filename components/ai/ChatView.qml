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

    property string aiBaseUrl: "https://apihub.agnes-ai.com/v1"
    property string aiApiKey: ""
    property string aiModel: "agnes-2.5-flash"
    property string customSystemPrompt: ""

    property string currentSessionId: ""
    property string currentSessionTitle: "新会话"
    property var messages: []
    property bool isGenerating: false
    property string streamingAssistantText: ""
    property var currentProposal: null
    property string attachedImagePath: ""
    property string attachedFilePath: ""
    property bool showDrawer: false

    // Slash command suggestions popup
    readonly property var availableCommands: [
        { "cmd": "/new", "desc": "开启全新排程会话", "icon": "add_comment" },
        { "cmd": "/session", "desc": "展开会话历史抽屉", "icon": "history" },
        { "cmd": "/model", "desc": "切换当前生效的大模型", "icon": "psychology" },
        { "cmd": "/clear", "desc": "清空当前会话消息", "icon": "delete_sweep" },
        { "cmd": "/help", "desc": "查看指令与快捷键指南", "icon": "help_outline" }
    ]

    property var filteredCommands: []
    property int selectedSlashIndex: 0

    signal scheduleConfirmed()
    signal filePickedAndReady()

    color: "transparent"
    clip: true

    Component.onCompleted: {
        initNewSession()
    }

    function initNewSession() {
        currentSessionId = "session_" + Date.now()
        currentSessionTitle = "新会话"
        messages = []
        streamingAssistantText = ""
        currentProposal = null
        attachedImagePath = ""
        attachedFilePath = ""
        filteredCommands = []
        selectedSlashIndex = 0
    }

    function loadSession(sessionId) {
        currentSessionId = sessionId
        var script = sessionScriptPath || Qt.resolvedUrl("../../session-manager").toString().replace(/^file:\/\//, "")
        loadSessionProc.command = [script, "get", sessionId]
        loadSessionProc.running = true
    }

    Process {
        id: loadSessionProc
        command: []
        running: false
        stdout: StdioCollector {
            id: loadSessionCollector
            onDataChanged: {
                try {
                    var data = JSON.parse(value.trim())
                    root.currentSessionId = data.id || root.currentSessionId
                    root.currentSessionTitle = data.title || "未命名会话"
                    root.messages = data.messages || []
                    Qt.callLater(() => {
                        msgListView.positionViewAtEnd()
                    })
                } catch(e) {}
            }
        }
        onExited: (code) => {
            if (code === 0) {
                try {
                    var data = JSON.parse(loadSessionCollector.value.trim())
                    root.currentSessionId = data.id || root.currentSessionId
                    root.currentSessionTitle = data.title || "未命名会话"
                    root.messages = data.messages || []
                    Qt.callLater(() => {
                        msgListView.positionViewAtEnd()
                    })
                } catch(e) {}
            }
        }
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
                        root.finishGeneration(ev.title, root.currentProposal)
                    } else if (ev.type === "error") {
                        root.handleError(ev.code, ev.message)
                    }
                } catch(e) {}
            }
        }

        onExited: (exitCode) => {
            if (root.isGenerating) {
                if (root.streamingAssistantText) {
                    root.finishGeneration(root.currentSessionTitle, root.currentProposal)
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
            finishGeneration(currentSessionTitle, currentProposal)
        } else {
            isGenerating = false
        }
    }

    function finishGeneration(sessionTitle, proposal) {
        if (sessionTitle && currentSessionTitle === "新会话") {
            currentSessionTitle = sessionTitle
        }
        var newMsgs = messages.slice()
        newMsgs.push({
            role: "assistant",
            content: streamingAssistantText,
            proposal: proposal,
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

        if (cmd === "/new" || cmd === "/clear") {
            initNewSession()
            chatInputField.text = ""
        } else if (cmd === "/session" || cmd === "/history") {
            showDrawer = !showDrawer
            chatInputField.text = ""
        } else if (cmd === "/model") {
            if (parts.length > 1) {
                aiModel = parts[1].trim()
                var sysMsgs = messages.slice()
                sysMsgs.push({
                    role: "system",
                    content: "已切换模型为: " + aiModel,
                    timestamp: new Date().toISOString()
                })
                messages = sysMsgs
            } else {
                var mMsgs = messages.slice()
                mMsgs.push({
                    role: "system",
                    content: "当前模型: " + aiModel + "\n可用命令: /model <模型名> (例如 /model deepseek-chat 或 /model agnes-2.5-flash)",
                    timestamp: new Date().toISOString()
                })
                messages = mMsgs
            }
            chatInputField.text = ""
        } else if (cmd === "/help") {
            var helpMsgs = messages.slice()
            helpMsgs.push({
                role: "system",
                content: "【支持的指令与快捷键】\n• /new 或 /clear : 开启全新排程会话\n• /session : 历史会话管理\n• /model <name> : 切换大模型\n• Ctrl+N : 新建会话\n• Ctrl+H : 打开历史抽屉\n• Ctrl+V : 粘贴剪贴板截图/图片\n• Shift+Enter : 换行\n• Esc : 中止思考或关闭面板",
                timestamp: new Date().toISOString()
            })
            messages = helpMsgs
            chatInputField.text = ""
        }
        filteredCommands = []
        selectedSlashIndex = 0
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

        var newMsgs = messages.slice()
        newMsgs.push({
            role: "user",
            content: clean || (userImg ? "已发送截图/图片附件" : "已发送文档附件"),
            imagePath: userImg,
            filePath: userFile,
            timestamp: new Date().toISOString()
        })
        messages = newMsgs

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

    // Direct Shortcut for Smart Clipboard Paste
    Shortcut {
        sequences: ["Ctrl+V", "Control+V"]
        onActivated: {
            root.triggerPasteClipboard()
        }
    }

    function triggerPasteClipboard() {
        var script = pasteHelperPath || Qt.resolvedUrl("../../clipboard-paste-helper").toString().replace(/^file:\/\//, "")
        pasteClipboardProc.command = [script]
        pasteClipboardProc.running = true
    }

    // Python Clipboard paste helper process
    Process {
        id: pasteClipboardProc
        command: []
        running: false
        stdout: StdioCollector {
            id: pasteCollector
            onDataChanged: {
                try {
                    var res = JSON.parse(value.trim())
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
        onExited: (code) => {
            if (code === 0) {
                try {
                    var res = JSON.parse(pasteCollector.value.trim())
                    if (res.status === "ok") {
                        if (res.type === "image") {
                            root.attachedImagePath = res.path
                        } else if (res.type === "file") {
                            root.attachedFilePath = res.path
                        }
                    }
                } catch(e) {}
            }
        }
    }

    // Native DMS File Browser Modal (keeps popout open and avoids focus loss)
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
        anchors.topMargin: Theme.spacingS
        spacing: Theme.spacingS

        // 1. Session Sub-Header Bar (Clean & Compact)
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 34
            color: Theme.surfaceContainerHigh
            radius: Theme.cornerRadiusSmall

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                spacing: Theme.spacingS

                // Session drawer toggle
                StyledRect {
                    implicitWidth: 26
                    implicitHeight: 26
                    radius: 4
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
                }

                // Model Badge
                StyledRect {
                    implicitWidth: modelText.implicitWidth + 12
                    implicitHeight: 22
                    radius: 6
                    color: Theme.surfaceContainerLowest

                    StyledText {
                        id: modelText
                        anchors.centerIn: parent
                        text: root.aiModel
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: Theme.primary
                    }
                }

                // New Chat Button
                StyledRect {
                    implicitWidth: 26
                    implicitHeight: 26
                    radius: 4
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
                spacing: Theme.spacingS
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
                            radius: Theme.cornerRadiusSmall

                            ColumnLayout {
                                id: uCol
                                anchors.fill: parent
                                anchors.margins: Theme.spacingS
                                spacing: Theme.spacingXS

                                // Image if present
                                Image {
                                    visible: !!modelData.imagePath
                                    source: modelData.imagePath ? ("file://" + modelData.imagePath) : ""
                                    Layout.preferredWidth: Math.min(240, userBubble.width - 20)
                                    Layout.preferredHeight: 140
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }

                                // File pill if present
                                StyledRect {
                                    visible: !!modelData.filePath
                                    implicitWidth: fRow.implicitWidth + 12
                                    implicitHeight: 22
                                    radius: 4
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

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.content || ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.onPrimaryContainer
                                    wrapMode: Text.WrapAnywhere
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
                            spacing: Theme.spacingXS

                            DankIcon {
                                name: modelData.error ? "error" : "smart_toy"
                                size: 15
                                color: modelData.error ? "#d32f2f" : Theme.primary
                            }

                            StyledText {
                                text: modelData.error ? "排程助理 (错误)" : "排程助理"
                                font.pixelSize: Theme.fontSizeSmall * 0.85
                                font.weight: Font.Bold
                                color: modelData.error ? "#d32f2f" : Theme.primary
                            }
                        }

                        StyledRect {
                            Layout.fillWidth: true
                            implicitHeight: aText.implicitHeight + Theme.spacingM * 2
                            color: modelData.error ? "#ffebee" : Theme.surfaceContainerHigh
                            radius: Theme.cornerRadiusSmall
                            border.width: modelData.error ? 1 : 0
                            border.color: "#d32f2f"

                            StyledText {
                                id: aText
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                text: modelData.content || ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: modelData.error ? "#c62828" : Theme.surfaceText
                                wrapMode: Text.WrapAnywhere
                            }
                        }

                        // Embedded Proposal Card if present
                        ScheduleProposalCard {
                            Layout.fillWidth: true
                            visible: !!modelData.proposal
                            proposal: modelData.proposal
                            batchScriptPath: root.batchScriptPath
                            onConfirmed: {
                                root.scheduleConfirmed()
                            }
                        }
                    }

                    // System message
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        visible: modelData.role === "system"
                        text: modelData.content || ""
                        font.pixelSize: Theme.fontSizeSmall * 0.85
                        color: Theme.surfaceVariantText
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
                        radius: Theme.cornerRadiusSmall

                        StyledText {
                            id: streamingText
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            text: root.streamingAssistantText + " ▍"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            wrapMode: Text.WrapAnywhere
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
                        size: 36
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

                    // Suggestion Pills
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        StyledRect {
                            Layout.fillWidth: true
                            implicitHeight: 32
                            radius: Theme.cornerRadiusSmall
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
                            implicitHeight: 32
                            radius: Theme.cornerRadiusSmall
                            color: sug2Hover.hovered ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

                            StyledText {
                                anchors.centerIn: parent
                                text: "📸 粘贴截图提取日程与待办 (按 Ctrl+V 或 📋 粘贴)"
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

        // 3. Input & Attachment Area
        Item {
            Layout.fillWidth: true
            implicitHeight: inputContainer.implicitHeight

            // Floating Slash Commands Popup Menu
            StyledRect {
                id: slashPopup
                visible: root.filteredCommands.length > 0
                anchors.bottom: inputContainer.top
                anchors.bottomMargin: Theme.spacingS
                anchors.left: parent.left
                anchors.right: parent.right
                implicitHeight: slashCol.implicitHeight + Theme.spacingS * 2
                radius: Theme.cornerRadiusSmall
                color: Theme.surfaceContainerHighest
                border.width: 1
                border.color: Theme.outlineVariant
                z: 10

                ColumnLayout {
                    id: slashCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    spacing: 2

                    StyledText {
                        text: "快捷指令 (按 ↑/↓ 选择，Enter/Tab 执行):"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: Theme.surfaceVariantText
                        Layout.leftMargin: Theme.spacingS
                    }

                    Repeater {
                        model: root.filteredCommands
                        delegate: StyledRect {
                            required property var modelData
                            required property int index
                            readonly property bool isSelected: (root.selectedSlashIndex === index || cmdHover.hovered)
                            Layout.fillWidth: true
                            implicitHeight: 30
                            radius: Theme.cornerRadiusSmall
                            color: isSelected ? Theme.primary : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingM
                                anchors.rightMargin: Theme.spacingM
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: modelData.icon || "terminal"
                                    size: 15
                                    color: isSelected ? "#ffffff" : Theme.primary
                                }

                                StyledText {
                                    text: modelData.cmd
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Bold
                                    color: isSelected ? "#ffffff" : Theme.surfaceText
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: "— " + modelData.desc
                                    font.pixelSize: Theme.fontSizeSmall * 0.85
                                    color: isSelected ? Qt.rgba(1, 1, 1, 0.85) : Theme.surfaceVariantText
                                    elide: Text.ElideRight
                                }
                            }

                            HoverHandler {
                                id: cmdHover
                                onHoveredChanged: {
                                    if (hovered) root.selectedSlashIndex = index
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.executeCommand(modelData.cmd)
                                }
                            }
                        }
                    }
                }
            }

            // Input Container
            StyledRect {
                id: inputContainer
                width: parent.width
                implicitHeight: inputCol.implicitHeight + Theme.spacingS * 2
                color: Theme.surfaceContainerHigh
                radius: Theme.cornerRadiusSmall

                ColumnLayout {
                    id: inputCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    spacing: Theme.spacingXS

                    // Attached Media Cards (Real Visual Thumbnail & Doc Card)
                    RowLayout {
                        visible: !!root.attachedImagePath || !!root.attachedFilePath
                        spacing: Theme.spacingS

                        // Image Preview Card (Real Thumbnail + Delete Button)
                        StyledRect {
                            visible: !!root.attachedImagePath
                            implicitWidth: 64
                            implicitHeight: 64
                            radius: Theme.cornerRadiusSmall
                            color: Theme.surfaceContainerHighest
                            clip: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: 2
                                source: root.attachedImagePath ? ("file://" + root.attachedImagePath) : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            // Delete button badge
                            StyledRect {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 2
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
                            radius: Theme.cornerRadiusSmall
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

                    // Input Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        // Paste from Clipboard Button (📋)
                        StyledRect {
                            implicitWidth: 32
                            implicitHeight: 32
                            radius: Theme.cornerRadiusSmall
                            color: pasteClipHover.hovered ? Theme.surfaceContainerHighest : "transparent"

                            DankIcon {
                                anchors.centerIn: parent
                                name: "content_paste"
                                size: 18
                                color: root.attachedImagePath ? Theme.primary : Theme.surfaceText
                            }

                            HoverHandler { id: pasteClipHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.triggerPasteClipboard()
                            }
                        }

                        // Attach 📎 button
                        StyledRect {
                            implicitWidth: 32
                            implicitHeight: 32
                            radius: Theme.cornerRadiusSmall
                            color: clipHover.hovered ? Theme.surfaceContainerHighest : "transparent"

                            DankIcon {
                                anchors.centerIn: parent
                                name: "attach_file"
                                size: 18
                                color: Theme.surfaceText
                            }

                            HoverHandler { id: clipHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openAttachmentPicker()
                            }
                        }

                        // Input Field
                        DankTextField {
                            id: chatInputField
                            Layout.fillWidth: true
                            placeholderText: "输入排程需求、Ctrl+V 粘贴截图或选用指令..."
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
                                root.updateSlashSuggestions(text)
                            }

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier)) {
                                    event.accepted = true
                                    root.triggerPasteClipboard()
                                    return
                                }

                                if (root.filteredCommands.length > 0) {
                                    if (event.key === Qt.Key_Up) {
                                        event.accepted = true
                                        root.selectedSlashIndex = (root.selectedSlashIndex - 1 + root.filteredCommands.length) % root.filteredCommands.length
                                        return
                                    } else if (event.key === Qt.Key_Down) {
                                        event.accepted = true
                                        root.selectedSlashIndex = (root.selectedSlashIndex + 1) % root.filteredCommands.length
                                        return
                                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Tab) {
                                        event.accepted = true
                                        if (root.selectedSlashIndex >= 0 && root.selectedSlashIndex < root.filteredCommands.length) {
                                            root.executeCommand(root.filteredCommands[root.selectedSlashIndex].cmd)
                                        }
                                        return
                                    } else if (event.key === Qt.Key_Escape) {
                                        event.accepted = true
                                        root.filteredCommands = []
                                        return
                                    }
                                }

                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (event.modifiers & Qt.ShiftModifier) {
                                        // Shift+Enter inserts newline
                                    } else {
                                        event.accepted = true
                                        if (root.isGenerating) {
                                            root.stopGeneration()
                                        } else {
                                            root.sendMessage(text)
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
                                    }
                                }
                            }
                        }

                        // Send or Stop Button
                        StyledRect {
                            implicitWidth: 32
                            implicitHeight: 32
                            radius: Theme.cornerRadiusSmall
                            color: root.isGenerating ? "#d32f2f" : Theme.primary

                            DankIcon {
                                anchors.centerIn: parent
                                name: root.isGenerating ? "stop" : "send"
                                size: 17
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
