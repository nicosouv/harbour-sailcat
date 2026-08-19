import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"
import "../components/Categories.js" as Categories

// Per-conversation overrides: title, category, model and system prompt.
// Anything left empty falls back to the global setting.
Dialog {
    id: conversationSettings
    allowedOrientations: Orientation.All

    property string conversationId: ""

    property var overrides: conversationManager.getConversationOverrides(conversationId)
    property var modelOptions: [""].concat(settingsManager.availableModels())
    property var categoryOptions: Categories.all()

    canAccept: true

    onAccepted: {
        conversationManager.renameConversation(conversationId, titleField.text)

        var selectedModel = modelCombo.currentItem ? modelCombo.currentItem.modelValue : ""
        var prompt = usePromptSwitch.checked ? promptArea.text : ""
        conversationManager.setConversationOverrides(conversationId, selectedModel, prompt)

        if (categoryCombo.currentItem) {
            conversationManager.setConversationCategory(conversationId,
                                                        categoryCombo.currentItem.categoryValue)
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            DialogHeader {
                title: qsTr("Conversation settings")
                acceptText: qsTr("Save")
                cancelText: qsTr("Cancel")
            }

            TextField {
                id: titleField
                width: parent.width
                label: qsTr("Title")
                placeholderText: qsTr("Conversation title")
                text: conversationSettings.overrides.title || ""

                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }

            SectionHeader {
                text: qsTr("Category")
            }

            ComboBox {
                id: categoryCombo
                width: parent.width
                label: qsTr("Topic")
                description: qsTr("Used by the statistics page")

                menu: ContextMenu {
                    Repeater {
                        model: conversationSettings.categoryOptions

                        MenuItem {
                            text: Categories.label(modelData)
                            property string categoryValue: modelData
                        }
                    }
                }

                Component.onCompleted: {
                    var current = conversationSettings.overrides.category || "other"
                    var index = conversationSettings.categoryOptions.indexOf(current)
                    currentIndex = index >= 0 ? index
                                              : conversationSettings.categoryOptions.length - 1
                }
            }

            SectionHeader {
                text: qsTr("Model")
            }

            ComboBox {
                id: modelCombo
                width: parent.width
                label: qsTr("Model for this conversation")
                description: qsTr("Overrides the model chosen in settings")

                menu: ContextMenu {
                    Repeater {
                        model: conversationSettings.modelOptions

                        MenuItem {
                            text: modelData === "" ? qsTr("Use default (%1)").arg(settingsManager.modelName)
                                                   : modelData
                            property string modelValue: modelData
                        }
                    }
                }

                Component.onCompleted: {
                    var current = conversationSettings.overrides.model || ""
                    var index = conversationSettings.modelOptions.indexOf(current)
                    currentIndex = index >= 0 ? index : 0
                }
            }

            SectionHeader {
                text: qsTr("System prompt")
            }

            TextSwitch {
                id: usePromptSwitch
                text: qsTr("Custom system prompt")
                description: qsTr("Replaces the global system prompt for this conversation only")
                checked: (conversationSettings.overrides.systemPrompt || "") !== ""
            }

            TextArea {
                id: promptArea
                width: parent.width
                visible: usePromptSwitch.checked
                label: qsTr("Instruction")
                placeholderText: qsTr("Enter a system prompt...")
                text: conversationSettings.overrides.systemPrompt || ""
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }
        }

        VerticalScrollDecorator {}
    }
}
