import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Common
import qs.Widgets
import "../../store"

Rectangle {
    id: picker

    property ProviderStore providerStore: null
    property string activeModel: ""

    signal modelSelected(string modelId, string providerId)
    signal configureProviderRequested(string providerId)

    width: parent.width - Theme.spacingS * 2
    height: Math.min(260, modelListCol.implicitHeight + Theme.spacingM * 2)
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHighest
    border.width: 1
    border.color: Theme.outlineMedium
    z: 100

    DankFlickable {
        anchors.fill: parent
        anchors.margins: Theme.spacingS
        contentHeight: modelListCol.implicitHeight
        clip: true

        Column {
            id: modelListCol
            width: parent.width
            spacing: Theme.spacingXS

            Repeater {
                model: providerStore ? providerStore.availableModelsList : []
                delegate: Rectangle {
                    id: modelRow
                    required property var modelData
                    width: modelListCol.width
                    height: 38
                    radius: Theme.cornerRadiusSmall
                    color: modelMouse.containsMouse ? Theme.surfaceContainerHigh : (picker.activeModel === modelData.id ? Theme.withAlpha(Theme.primary, 0.15) : "transparent")

                    Row {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        spacing: Theme.spacingS

                        DankIcon {
                            name: modelRow.modelData.icon || "smart_toy"
                            size: 16
                            color: modelRow.modelData.color || Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - 60
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            StyledText {
                                text: modelRow.modelData.name || modelRow.modelData.id
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: picker.activeModel === modelRow.modelData.id ? Font.Bold : Font.Normal
                                color: picker.activeModel === modelRow.modelData.id ? Theme.primary : Theme.surfaceText
                                elide: Text.ElideRight
                            }
                        }

                        DankIcon {
                            name: "check"
                            size: 14
                            color: Theme.primary
                            visible: picker.activeModel === modelRow.modelData.id
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: modelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            picker.modelSelected(modelRow.modelData.id, modelRow.modelData.providerId);
                        }
                    }
                }
            }
        }
    }
}
