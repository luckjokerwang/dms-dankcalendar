import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Item {
    id: store

    property DankCalendarConstants constants: DankCalendarConstants {}

    // State
    property var pendingTasks: []
    property var completedTasks: []
    property int pendingTasksCount: 0
    property int completedTasksCount: 0
    property string defaultTaskCalendarId: ""
    property var taskCalendars: []
    property bool tasksLoading: false

    // Action Queue for robust sequential writes
    property var taskActionQueue: []
    property bool isActionRunning: false

    Process {
        id: fetchTasksProc
        command: [store.constants.coreScriptPath, "tasks", "list"]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                var trimmed = line.trim();
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
                    }
                } catch (e) {}
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
                // Trigger full sync to recover state
                store.fetchTasks();
            }
            store.isActionRunning = false;
            store.processNextTaskAction();
        }
    }

    function fetchTasks() {
        if (!fetchTasksProc.running) {
            store.tasksLoading = true;
            fetchTasksProc.running = true;
        }
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

    function createTask(summary, calendarId) {
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
        var m = cleanSummary.match(/^!(1|2|3|h|m|l|high|med|low)\s+/i);
        if (m) {
            var tag = m[1].toLowerCase();
            if (tag === "1" || tag === "h" || tag === "high") priorityVal = constants.priorityHigh;
            else if (tag === "2" || tag === "m" || tag === "med") priorityVal = constants.priorityMedium;
            else if (tag === "3" || tag === "l" || tag === "low") priorityVal = constants.priorityLow;
            cleanSummary = cleanSummary.substring(m[0].length).trim();
        }

        var tempTask = {
            id: "temp-" + Date.now(),
            summary: cleanSummary,
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

        var cmdArgs = ["dcal", "ipc", "tasks.create", "calendarId=" + cid, "summary=" + cleanSummary];
        if (priorityVal > 0) {
            cmdArgs.push("priority=" + priorityVal);
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
