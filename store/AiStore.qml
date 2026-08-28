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

    signal generationFinished()
    signal proposalConfirmed(var result)
    signal sessionChanged()

    // 1. Stream Process
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
                        store.generationFinished();
                    } else if (obj.type === "error") {
                        var errMsgs = store.messages.slice();
                        errMsgs.push({
                            role: "system",
                            content: "❌ 请求失败: " + (obj.message || "未知错误"),
                            timestamp: new Date().toISOString()
                        });
                        store.messages = errMsgs;
                        store.streamingAssistantText = "";
                        store.isGenerating = false;
                        store.saveCurrentSession();
                        store.generationFinished();
                    }
                } catch (e) {}
            }
        }
        onExited: (code) => {
            if (store.isGenerating) {
                store.isGenerating = false;
                store.streamingAssistantText = "";
            }
        }
    }

    // 2. Session List Process
    Process {
        id: sessionsListProc
        command: [constants.coreScriptPath, "session", "list"]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                var trimmed = line.trim();
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
        stdout: SplitParser {
            onRead: (line) => {
                var trimmed = line.trim();
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
        stdout: SplitParser {
            onRead: (line) => {
                var trimmed = line.trim();
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
            smartTitleProc.stdout = Qt.createQmlObject('import Quickshell.Io; SplitParser {}', store);
            smartTitleProc.stdout.onRead = function(line) {
                try {
                    var r = JSON.parse(line.trim());
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
