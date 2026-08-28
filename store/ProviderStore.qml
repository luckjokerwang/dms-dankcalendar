import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Item {
    id: store

    DankCalendarConstants { id: constants }

    property var allProviders: []
    property var presetList: []
    property string activeProviderId: "agnes"
    property string activeModelId: "agnes-2.5-flash"

    signal providerSaved(string providerId, bool success)
    signal modelsFetched(string providerId, bool success, var data)

    readonly property var availableModelsList: {
        var list = [];
        for (var i = 0; i < allProviders.length; i++) {
            var p = allProviders[i];
            if ((p.enabled && (p.apiKey || p.id === "ollama")) || p.id === activeProviderId) {
                var models = p.models || [];
                for (var j = 0; j < models.length; j++) {
                    var m = models[j];
                    list.push({
                        "id": m.id,
                        "name": m.name || m.id,
                        "providerId": p.id,
                        "providerName": p.name,
                        "desc": m.desc || "排程大模型",
                        "icon": p.icon || "smart_toy",
                        "color": p.color || Theme.primary,
                        "baseUrl": p.baseUrl,
                        "apiKey": p.apiKey || ""
                    });
                }
            }
        }
        return list;
    }

    Process {
        id: listProc
        command: [constants.coreScriptPath, "provider", "list"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var trimmed = (text || "").trim();
                if (!trimmed) return;
                try {
                    var res = JSON.parse(trimmed);
                    if (res.status === "ok" && res.data) {
                        store.allProviders = res.data.providers || [];
                        if (res.data.activeProvider) store.activeProviderId = res.data.activeProvider;
                        if (res.data.activeModel) store.activeModelId = res.data.activeModel;
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: presetsProc
        command: [constants.coreScriptPath, "provider", "get-presets"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var trimmed = (text || "").trim();
                if (!trimmed) return;
                try {
                    var res = JSON.parse(trimmed);
                    if (res.status === "ok" && res.data && res.data.presets) {
                        store.presetList = res.data.presets;
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: saveProc
        command: []
        running: false
        onExited: (code) => {
            store.reloadProviders();
        }
    }

    Process {
        id: deleteProc
        command: []
        running: false
        onExited: (code) => {
            store.reloadProviders();
        }
    }

    function reloadProviders() {
        if (!listProc.running) listProc.running = true;
        if (!presetsProc.running) presetsProc.running = true;
    }

    function saveProvider(providerObj) {
        saveProc.command = [constants.coreScriptPath, "provider", "save", "--payload", JSON.stringify(providerObj)];
        saveProc.running = true;
    }

    function deleteProvider(providerId) {
        deleteProc.command = [constants.coreScriptPath, "provider", "delete", "--id", providerId];
        deleteProc.running = true;
    }

    function setActive(providerId, modelId) {
        if (providerId) store.activeProviderId = providerId;
        if (modelId) store.activeModelId = modelId;
        var cmd = [constants.coreScriptPath, "provider", "set-active"];
        if (providerId) cmd.push("--provider", providerId);
        if (modelId) cmd.push("--model", modelId);
        Quickshell.execDetached(cmd);
    }

    Component.onCompleted: {
        reloadProviders();
    }
}
