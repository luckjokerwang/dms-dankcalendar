import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services

Item {
    id: store

    property string pluginId: (parent && parent.pluginId) ? parent.pluginId : "dankCalendarPlus"

    DankCalendarConstants { id: constants }

    // State
    property var pendingTasks: []
    property var completedTasks: []
    property int pendingTasksCount: 0
    property int completedTasksCount: 0
    property string defaultTaskCalendarId: ""
    property var taskCalendars: []
    property var allTags: []
    property bool tasksLoading: false
    property bool isClassifyingBatch: false
    property int refreshInterval: 10000

    // Multi-Monitor / Cross-Process Synchronization via PluginGlobalVar
    PluginGlobalVar {
        id: globalTasksRevision
        varName: "dankCalendarTasksRevision"
        defaultValue: 0
        onValueChanged: {
            store.fetchTasks();
        }
    }

    Timer {
        id: autoSyncTimer
        interval: store.refreshInterval
        running: store.refreshInterval > 0
        repeat: true
        onTriggered: {
            store.fetchTasks();
        }
    }

    function notifyTasksChanged() {
        globalTasksRevision.set(Date.now());
    }

    // Action Queue for robust sequential writes
    property var taskActionQueue: []
    property bool isActionRunning: false

    Process {
        id: fetchTasksProc
        command: [constants.coreScriptPath, "tasks", "list"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var trimmed = (text || "").trim();
                if (!trimmed) return;
                try {
                    var res = JSON.parse(trimmed);
                    if (res && res.pending !== undefined) {
                        store.pendingTasks = res.pending || [];
                        store.completedTasks = res.completed || [];
                        store.pendingTasksCount = res.pendingCount || 0;
                        store.completedTasksCount = res.completedCount || 0;
                        store.defaultTaskCalendarId = res.defaultCalendarId || "";
                        store.taskCalendars = res.taskCalendars || [];
                        store.allTags = res.allTags || [];
                    }
                } catch (e) {
                    console.warn("[TaskStore] parse error:", e);
                }
                store.tasksLoading = false;
            }
        }
        onExited: (code) => {
            store.tasksLoading = false;
        }
    }

    Process {
        id: singleActionProc
        command: []
        running: false
        onExited: (code) => {
            if (code !== 0) {
                console.warn("[TaskStore] Task action failed with exit code:", code);
            }
            store.isActionRunning = false;
            store.processNextTaskAction();
            store.notifyTasksChanged();
        }
    }

    function showToast(type, message) {
        if (!message) return;
        try {
            if (typeof ToastService !== "undefined") {
                if (type === "error" && typeof ToastService.showError === "function") {
                    ToastService.showError(message);
                } else if (type === "warning" && typeof ToastService.showWarning === "function") {
                    ToastService.showWarning(message);
                } else if (typeof ToastService.showInfo === "function") {
                    ToastService.showInfo(message);
                }
            } else {
                console.log("[TaskStore Toast]", type, message);
            }
        } catch (e) {
            console.warn("[TaskStore] Toast failed:", e, message);
        }
    }

    Process {
        id: classifyBatchProc
        command: [constants.coreScriptPath, "tasks", "classify-batch"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var trimmed = (text || "").trim();
                if (!trimmed) {
                    store.isClassifyingBatch = false;
                    return;
                }
                try {
                    var res = JSON.parse(trimmed);
                    if (res && res.status === "ok" && res.data && res.data.tasks && res.data.tasks.length > 0) {
                        var updates = [];
                        for (var i = 0; i < res.data.tasks.length; i++) {
                            var t = res.data.tasks[i];
                            updates.push({
                                id: t.id,
                                taggedSummary: t.taggedSummary,
                                cleanSummary: t.cleanSummary || t.summary
                            });
                        }
                        store.applyBatchTags(updates);
                    } else if (res && res.status === "ok") {
                        store.isClassifyingBatch = false;
                        store.showToast("info", "暂无需要整理或调整分类的待办");
                    } else {
                        store.isClassifyingBatch = false;
                        var errMsg = (res && res.error && res.error.message) ? res.error.message : "智能分类执行失败";
                        if (res && res.error && res.error.details) {
                            errMsg += (" (" + res.error.details + ")");
                        }
                        store.showToast("error", errMsg);
                    }
                } catch (e) {
                    store.isClassifyingBatch = false;
                    console.warn("[TaskStore] classify batch parse error:", e);
                    store.showToast("error", "AI 整理待办返回解析失败");
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                var trimmed = (text || "").trim();
                if (trimmed) {
                    console.warn("[TaskStore] classify batch stderr:", trimmed);
                }
            }
        }
        onExited: (code) => {
            if (code !== 0 && store.isClassifyingBatch) {
                store.isClassifyingBatch = false;
                store.showToast("error", "AI 智能分类进程异常退出 (code: " + code + ")");
            }
        }
    }

    property string lastApplyTagsStdout: ""
    property string lastApplyTagsStderr: ""

    Process {
        id: applyBatchTagsProc
        command: []
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                store.lastApplyTagsStdout = (text || "").trim();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                store.lastApplyTagsStderr = (text || "").trim();
            }
        }
        onExited: (code) => {
            store.isClassifyingBatch = false;
            var outText = store.lastApplyTagsStdout;
            if (outText) {
                try {
                    var res = JSON.parse(outText);
                    if (res && res.status === "ok" && res.data && res.data.success) {
                        var count = res.data.successCount || 0;
                        store.showToast("info", "✨ 已成功智能整理 " + count + " 项待办分类");
                    } else {
                        var errMsg = "待办分类写入失败";
                        if (res && res.error && res.error.details) {
                            errMsg = res.error.details;
                        } else if (res && res.data && res.data.errors && res.data.errors.length > 0) {
                            errMsg = res.data.errors.join("; ");
                        }
                        store.showToast("error", "⚠️ " + errMsg);
                    }
                } catch (e) {
                    console.warn("[TaskStore] applyBatchTags parse error:", e, outText);
                    if (code !== 0) {
                        store.showToast("error", "⚠️ 待办标签写入失败 (code: " + code + ")");
                    }
                }
            } else if (code !== 0) {
                store.showToast("error", "⚠️ 待办标签写入异常退出: " + (store.lastApplyTagsStderr || ("code " + code)));
            }

            store.fetchTasks();
            store.notifyTasksChanged();
        }
    }

    function fetchTasks() {
        if (!fetchTasksProc.running) {
            store.tasksLoading = true;
            fetchTasksProc.running = true;
        }
    }

    function autoClassifyUncategorizedTasks() {
        if (isClassifyingBatch) return;
        isClassifyingBatch = true;
        classifyBatchProc.running = true;
    }

    function applyBatchTags(updates) {
        if (!updates || updates.length === 0) {
            store.isClassifyingBatch = false;
            return;
        }
        store.lastApplyTagsStdout = "";
        store.lastApplyTagsStderr = "";
        applyBatchTagsProc.command = [
            constants.coreScriptPath, "tasks", "apply-tags",
            "--payload", JSON.stringify(updates)
        ];
        applyBatchTagsProc.running = true;
    }

    function processNextTaskAction() {
        if (isActionRunning || taskActionQueue.length === 0) {
            if (!isActionRunning && taskActionQueue.length === 0) {
                store.fetchTasks();
            }
            return;
        }
        var nextCmd = taskActionQueue.shift();
        isActionRunning = true;
        singleActionProc.command = Array.isArray(nextCmd) ? nextCmd : ["sh", "-c", nextCmd];
        singleActionProc.running = true;
    }

    function queueTaskAction(cmd) {
        taskActionQueue.push(cmd);
        processNextTaskAction();
    }

    function createTask(summary, calendarId, defaultTag) {
        var cid = calendarId || defaultTaskCalendarId || (taskCalendars.length > 0 ? taskCalendars[0].id : "");
        if (!cid) {
            console.warn("[TaskStore] No task calendar available");
            return;
        }
        var calName = "Tasks";
        for (var i = 0; i < taskCalendars.length; i++) {
            if (taskCalendars[i].id === cid) {
                calName = taskCalendars[i].name;
                break;
            }
        }

        var cleanSummary = summary.trim();
        var priorityVal = 0;
        var m = cleanSummary.match(/^!(1|2|3|h|m|l|high|med|low)\s*/i);
        if (m) {
            var tag = m[1].toLowerCase();
            if (tag === "1" || tag === "h" || tag === "high") priorityVal = constants.priorityHigh;
            else if (tag === "2" || tag === "m" || tag === "med") priorityVal = constants.priorityMedium;
            else if (tag === "3" || tag === "l" || tag === "low") priorityVal = constants.priorityLow;
            cleanSummary = cleanSummary.substring(m[0].length).trim();
        }

        // 如果在特定标签下创建且未手动指定任何 #标签，自动继承该标签（排除到期聚合标签）
        if (defaultTag && defaultTag !== "__due__") {
            var hasExplicitTag = /(?:^|\s)#[^\s#]+/.test(cleanSummary);
            if (!hasExplicitTag) {
                cleanSummary = cleanSummary + " #" + defaultTag.trim();
            }
        }

        // 乐观解析待办标签与洁净标题，确保当前标签视图下即时渲染无闪烁
        var optTags = [];
        var tagRegex = /(?:^|\s)#([^\s#]+)/g;
        var match;
        while ((match = tagRegex.exec(cleanSummary)) !== null) {
            var tagName = match[1];
            if (tagName) {
                var foundColor = "#0284c7";
                var foundIcon = "label";
                for (var ti = 0; ti < store.allTags.length; ti++) {
                    if (store.allTags[ti].name === tagName) {
                        foundColor = store.allTags[ti].color || foundColor;
                        foundIcon = store.allTags[ti].icon || foundIcon;
                        break;
                    }
                }
                optTags.push({
                    name: tagName,
                    color: foundColor,
                    icon: foundIcon
                });
            }
        }
        var optCleanText = cleanSummary.replace(/(?:^|\s)#[^\s#]+/g, "").trim();

        var tempTask = {
            id: "temp-" + Date.now(),
            summary: cleanSummary,
            cleanSummary: optCleanText || cleanSummary,
            tags: optTags,
            calendarId: cid,
            calendarName: calName,
            status: "needs_action",
            percentComplete: 0,
            priority: priorityVal,
            due: null
        };
        var newPending = pendingTasks.concat([tempTask]);
        pendingTasks = newPending;
        pendingTasksCount = newPending.length;

        var cmdArgs = [constants.coreScriptPath, "tasks", "create", "--calendar-id", cid, "--summary", cleanSummary, "--auto-classify"];
        if (priorityVal > 0) {
            cmdArgs.push("--priority");
            cmdArgs.push(String(priorityVal));
        }
        queueTaskAction(cmdArgs);
    }

    function completeTask(taskId, completed) {
        if (completed) {
            var found = null;
            var newPending = [];
            for (var i = 0; i < pendingTasks.length; i++) {
                if (pendingTasks[i].id === taskId) {
                    found = Object.assign({}, pendingTasks[i], { status: "completed", percentComplete: 100 });
                } else {
                    newPending.push(pendingTasks[i]);
                }
            }
            if (found) {
                pendingTasks = newPending;
                pendingTasksCount = newPending.length;
                completedTasks = [found].concat(completedTasks);
                completedTasksCount = completedTasks.length;
            }
        } else {
            var foundUncomp = null;
            var newComp = [];
            for (var j = 0; j < completedTasks.length; j++) {
                if (completedTasks[j].id === taskId) {
                    foundUncomp = Object.assign({}, completedTasks[j], { status: "needs_action", percentComplete: 0 });
                } else {
                    newComp.push(completedTasks[j]);
                }
            }
            if (foundUncomp) {
                completedTasks = newComp;
                completedTasksCount = newComp.length;
                pendingTasks = pendingTasks.concat([foundUncomp]);
                pendingTasksCount = pendingTasks.length;
            }
        }

        queueTaskAction(["dcal", "ipc", "tasks.complete", "id=" + taskId, "completed=" + (completed ? "true" : "false")]);
    }

    function deleteTask(taskId) {
        pendingTasks = pendingTasks.filter(t => t.id !== taskId);
        pendingTasksCount = pendingTasks.length;
        completedTasks = completedTasks.filter(t => t.id !== taskId);
        completedTasksCount = completedTasks.length;

        queueTaskAction(["dcal", "ipc", "tasks.delete", "id=" + taskId]);
    }

    Component.onCompleted: {
        fetchTasks();
    }
}
