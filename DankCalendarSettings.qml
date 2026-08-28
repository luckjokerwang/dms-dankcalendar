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
import "./components/common"

PluginSettings {
    id: root

    pluginId: "dankCalendarPlus"

    ProviderStore {
        id: providerStore
    }

    // Modal Dialog State
    property bool showProviderModal: false
    property var selectedProviderData: null

    function openAddCustomProvider() {
        selectedProviderData = {
            id: "",
            name: "",
            baseUrl: "https://",
            apiKey: "",
            icon: "tune",
            color: "#546e7a"
        };
        showProviderModal = true;
    }

    function openEditProvider(p) {
        if (!p) return;
        selectedProviderData = p;
        showProviderModal = true;
    }

    function openAddPreset(preset) {
        if (!preset) return;
        for (var i = 0; i < providerStore.allProviders.length; i++) {
            if (providerStore.allProviders[i].id === preset.id) {
                openEditProvider(providerStore.allProviders[i]);
                return;
            }
        }
        selectedProviderData = {
            id: preset.id,
            name: preset.name,
            baseUrl: preset.baseUrl,
            apiKey: "",
            icon: preset.icon || "smart_toy",
            color: preset.color || "#1565c0"
        };
        showProviderModal = true;
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
        // 1. AI 动态服务商与模型管理中心
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
                            text: "🤖 AI 大模型服务商管理"
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
                                text: "添加提供方"
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
                            model: providerStore.presetList
                            delegate: StyledRect {
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
                        delegate: StyledRect {
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
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
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

                                            StyledRect {
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
                                        delegate: StyledRect {
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
        // 2. 日历常规配置
        // ==========================================
        Rectangle {
            width: parent.width
            height: genCol.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1

            Column {
                id: genCol
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                StyledText {
                    text: "📅 日历常规设置"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                }

                DankSpinBox {
                    width: parent.width
                    label: "刷新间隔 (秒)"
                    description: "后台轮询日历与待办变更的周期 (默认 30 秒)"
                    value: mainSettingsCol.loadValue("refreshInterval", 30)
                    minimumValue: 5
                    maximumValue: 300
                    onValueChanged: mainSettingsCol.saveValue("refreshInterval", value)
                }

                DankSpinBox {
                    width: parent.width
                    label: "顶栏胶囊最大宽度 (px)"
                    description: "顶栏显示事件标题的最大宽度 (默认 160px)"
                    value: mainSettingsCol.loadValue("pillMaxWidth", 160)
                    minimumValue: 80
                    maximumValue: 400
                    onValueChanged: mainSettingsCol.saveValue("pillMaxWidth", value)
                }

                DankSwitch {
                    width: parent.width
                    text: "动态宽度适应"
                    description: "短标题自动收缩胶囊宽度，避免占用过多顶栏空间"
                    checked: mainSettingsCol.loadValue("dynamicWidth", false)
                    onCheckedChanged: mainSettingsCol.saveValue("dynamicWidth", checked)
                }

                DankSwitch {
                    width: parent.width
                    text: "长标题滚动动画"
                    description: "当事件标题超出宽度时，在顶栏自动横向来回平滑滚动"
                    checked: mainSettingsCol.loadValue("scrollTitle", true)
                    onCheckedChanged: mainSettingsCol.saveValue("scrollTitle", checked)
                }
            }
        }
    }

    // Shared Provider Configuration Modal Dialog
    ProviderConfigModal {
        visible: root.showProviderModal
        providerStore: providerStore
        providerId: root.selectedProviderData ? root.selectedProviderData.id : ""
        providerName: root.selectedProviderData ? root.selectedProviderData.name : ""
        providerBaseUrl: root.selectedProviderData ? root.selectedProviderData.baseUrl : "https://"
        providerApiKey: root.selectedProviderData ? root.selectedProviderData.apiKey : ""
        isEditing: root.selectedProviderData ? !!root.selectedProviderData.id : false
        onClosed: root.showProviderModal = false
        onSaved: (prov) => {
            providerStore.reloadProviders();
        }
    }
}
