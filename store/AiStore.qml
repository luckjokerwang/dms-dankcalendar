import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Item {
    id: store

    DankCalendarConstants { id: constants }

    // Session State
    property string currentSessionId: ""
    property string currentSessionTitle: "新排程会话"
    property var sessionsList: []
    property var messages: []

    // Generation State
    property bool isGenerating: false
    property string streamingAssistantText: ""
    property var currentProposal: null
    property bool aiNotificationEnabled: true

    signal generationFinished()
    signal proposalConfirmed(var result)
    signal sessionChanged()

    function sendNotification(summary, body, icon) {
        if (!store.aiNotificationEnabled) return;
        var s = (summary || "").trim();
        var b = (body || "").trim();
        if (!s) return;
        var ic = icon || "dialog-information";
        var cmd = [
            "sh", "-c",
            'if command -v dms >/dev/null 2>&1; then ' +
            '  dms notify "$1" "$2" --app "Dank Calendar Plus" --icon "$3"; ' +
            'elif command -v notify-send >/dev/null 2>&1; then ' +
            '  notify-send -a "Dank Calendar Plus" -i "$3" "$1" "$2"; ' +
            'fi',
            "sh", s, b, ic
        ];
        Quickshell.execDetached(cmd);
    }

    function notifyAssistantReply(text, proposal) {
        if (!store.aiNotificationEnabled) return;
        var hasProposal = proposal && ((proposal.events && proposal.events.length > 0) || (proposal.tasks && proposal.tasks.length > 0));
        if (hasProposal) {
            var evCount = (proposal.events && Array.isArray(proposal.events)) ? proposal.events.length : 0;
            var taskCount = (proposal.tasks && Array.isArray(proposal.tasks)) ? proposal.tasks.length : 0;
            var parts = [];
            if (evCount > 0) parts.push(evCount + " 项日程");
            if (taskCount > 0) parts.push(taskCount + " 项待办");

            var sample = "";
            if (evCount > 0 && proposal.events[0] && proposal.events[0].summary) {
                sample = proposal.events[0].summary;
            } else if (taskCount > 0 && proposal.tasks[0] && proposal.tasks[0].summary) {
                sample = proposal.tasks[0].summary;
            }

            var body = "已规划 " + parts.join("、") + (sample ? ("：包含「" + sample + "」等") : "");
            store.sendNotification("📅 排程建议已就绪", body, "dialog-information");
        } else {
            var raw = (text || "").trim();
            var clean = raw.replace(/```[\s\S]*?```/g, "");
            clean = clean.replace(/^#+\s+/gm, "");
            clean = clean.replace(/[*_~`]/g, "");
            clean = clean.replace(/\s+/g, " ").trim();
            if (clean.length > 80) {
                clean = clean.slice(0, 80) + "...";
            }
            if (!clean) clean = "回复已生成，点击查看详情";
            store.sendNotification("🤖 AI 助手已回复", clean, "dialog-information");
        }
    }

    // 1. Stream Process (Streaming SSE chunks)
    Process {
        id: streamProc
        command: []
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                var trimmed = line.trim();
                if (!trimmed) return;
                try {
                    var obj = JSON.parse(trimmed);
                    if (obj.type === "chunk" && obj.text) {
                        store.streamingAssistantText += obj.text;
                    } else if (obj.type === "done") {
                        var full = obj.fullText || store.streamingAssistantText;
                        var prop = obj.proposal || null;
                        var newMsgs = store.messages.slice();
                        newMsgs.push({
                            role: "assistant",
                            content: full,
                            timestamp: new Date().toISOString(),
                            proposal: prop
                        });
                        store.messages = newMsgs;
                        store.currentProposal = prop;
                        store.streamingAssistantText = "";
                        store.isGenerating = false;
                        store.saveCurrentSession();
                        store.notifyAssistantReply(full, prop);
                        store.generationFinished();
                    } else if (obj.type === "error") {
                        var errMsg = obj.message || "未知错误";
                        var errMsgs = store.messages.slice();
                        errMsgs.push({
                            role: "system",
                            content: "❌ 请求失败: " + errMsg,
                            timestamp: new Date().toISOString()
                        });
                        store.messages = errMsgs;
                        store.streamingAssistantText = "";
                        store.isGenerating = false;
                        store.saveCurrentSession();
                        store.sendNotification("❌ AI 助手请求失败", errMsg, "dialog-error");
                        store.generationFinished();
                    }
                } catch (e) {}
            }
        }
        onExited: (code) => {
            if (store.isGenerating) {
                store.isGenerating = false;
                store.streamingAssistantText = "";
                var interruptMsg = "⚠️ 连接已中断 (退出码: " + code + ")，请检查服务商 API 端点或密匙配置";
                var msgs = store.messages.slice();
                msgs.push({
                    role: "system",
                    content: interruptMsg,
                    timestamp: new Date().toISOString()
                });
                store.messages = msgs;
                store.saveCurrentSession();
                store.sendNotification("⚠️ AI 助手连接中断", interruptMsg, "dialog-warning");
                store.generationFinished();
            }
        }
    }

    // 2. Session List Process
    Process {
        id: sessionsListProc
        command: [constants.coreScriptPath, "session", "list"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var trimmed = (text || "").trim();
                if (!trimmed) return;
                try {
                    var res = JSON.parse(trimmed);
                    if (res.status === "ok" && res.data && res.data.sessions) {
                        store.sessionsList = res.data.sessions;
                    }
                } catch (e) {}
            }
        }
    }

    // 3. Get Session Process
    Process {
        id: sessionGetProc
        command: []
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var trimmed = (text || "").trim();
                if (!trimmed) return;
                try {
                    var res = JSON.parse(trimmed);
                    if (res.status === "ok" && res.data) {
                        var d = res.data;
                        store.currentSessionId = d.id;
                        store.currentSessionTitle = d.title || "新排程会话";
                        store.messages = d.messages || [];
                        store.currentProposal = d.proposal || null;
                        store.sessionChanged();
                    }
                } catch (e) {}
            }
        }
    }

    // 4. Batch Create Proposal Process
    Process {
        id: batchProc
        command: []
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var trimmed = (text || "").trim();
                if (!trimmed) return;
                try {
                    var res = JSON.parse(trimmed);
                    if (res.status === "ok") {
                        if (store.currentProposal) {
                            var p = Object.assign({}, store.currentProposal, { confirmed: true });
                            store.currentProposal = p;
                            var msgs = store.messages.slice();
                            for (var i = msgs.length - 1; i >= 0; i--) {
                                if (msgs[i].proposal) {
                                    msgs[i].proposal = Object.assign({}, msgs[i].proposal, { confirmed: true });
                                    break;
                                }
                            }
                            store.messages = msgs;
                            store.saveCurrentSession();
                        }
                        var evCount = (res.data && res.data.events && Array.isArray(res.data.events)) ? res.data.events.length : 0;
                        var taskCount = (res.data && res.data.tasks && Array.isArray(res.data.tasks)) ? res.data.tasks.length : 0;
                        var detail = "已写入 " + (evCount > 0 ? (evCount + " 项日程") : "") + (evCount > 0 && taskCount > 0 ? "、" : "") + (taskCount > 0 ? (taskCount + " 项待办") : "");
                        store.sendNotification("✅ 排程已写入清单", detail, "emblem-default");
                        store.proposalConfirmed(res.data);
                    }
                } catch (e) {}
            }
        }
    }

    function loadSessions() {
        if (!sessionsListProc.running) sessionsListProc.running = true;
    }

    function newSession() {
        store.currentSessionId = "session_" + Date.now();
        store.currentSessionTitle = "新排程会话";
        store.messages = [];
        store.currentProposal = null;
        store.streamingAssistantText = "";
        store.isGenerating = false;
        store.sessionChanged();
    }

    function switchSession(sessionId) {
        if (!sessionId) return;
        if (store.isGenerating) store.stopGeneration();
        sessionGetProc.command = [constants.coreScriptPath, "session", "get", "--id", sessionId];
        sessionGetProc.running = true;
    }

    function deleteSession(sessionId) {
        if (!sessionId) return;
        Quickshell.execDetached([constants.coreScriptPath, "session", "delete", "--id", sessionId]);
        if (store.currentSessionId === sessionId) {
            store.newSession();
        }
        store.loadSessions();
    }

    function saveCurrentSession() {
        if (!currentSessionId) return;
        var sessObj = {
            id: currentSessionId,
            title: currentSessionTitle,
            messages: messages,
            proposal: currentProposal,
            updatedAt: new Date().toISOString()
        };
        Quickshell.execDetached([constants.coreScriptPath, "session", "save", "--payload", JSON.stringify(sessObj)]);
        store.loadSessions();
    }

    function sendMessage(prompt, imagePath, filePath, modelId, systemPrompt) {
        if (!prompt && !imagePath && !filePath) return;
        if (!currentSessionId) {
            currentSessionId = "session_" + Date.now();
        }

        var newMsgs = messages.slice();
        newMsgs.push({
            role: "user",
            content: prompt,
            timestamp: new Date().toISOString(),
            imagePath: imagePath || "",
            filePath: filePath || ""
        });
        messages = newMsgs;
        streamingAssistantText = "";
        isGenerating = true;

        if (messages.length === 1 || currentSessionTitle === "新排程会话") {
            var smartTitlePayload = JSON.stringify({
                sessionId: currentSessionId,
                prompt: prompt,
                proposal: currentProposal,
                messages: messages
            });
            var smartTitleProc = Qt.createQmlObject('import Quickshell.Io; Process {}', store);
            smartTitleProc.command = [constants.coreScriptPath, "session", "smart-title", "--payload", smartTitlePayload];
            smartTitleProc.stdout = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', store);
            smartTitleProc.stdout.onStreamFinished = function() {
                try {
                    var r = JSON.parse((smartTitleProc.stdout.text || "").trim());
                    if (r.status === "ok" && r.data && r.data.title) {
                        store.currentSessionTitle = r.data.title;
                    }
                } catch(e) {}
            };
            smartTitleProc.running = true;
        }

        var cmd = [constants.coreScriptPath, "ai", "stream", "--messages", JSON.stringify(messages)];
        if (modelId) cmd.push("--model", modelId);
        if (systemPrompt) cmd.push("--system-prompt", systemPrompt);

        streamProc.command = cmd;
        streamProc.running = true;
    }

    function stopGeneration() {
        if (streamProc.running) {
            streamProc.running = false;
        }
        isGenerating = false;
        if (streamingAssistantText) {
            var newMsgs = messages.slice();
            newMsgs.push({
                role: "assistant",
                content: streamingAssistantText + " (已停止)",
                timestamp: new Date().toISOString()
            });
            messages = newMsgs;
            streamingAssistantText = "";
            saveCurrentSession();
        }
    }

    function confirmProposal(proposalObj) {
        if (!proposalObj) return;
        batchProc.command = [constants.coreScriptPath, "tasks", "batch-create", "--payload", JSON.stringify(proposalObj)];
        batchProc.running = true;
    }

    Component.onCompleted: {
        newSession();
        loadSessions();
    }
}
