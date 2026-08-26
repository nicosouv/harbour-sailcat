import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"
import "../components/Categories.js" as Categories

// Per-conversation overrides: title, category, model and system prompt.
// Anything left empty falls back to the global setting.
//
// This is a Page, not a Dialog: it is attached to the chat (one swipe forward)
// and follows the current conversation. Changes are written when leaving it,
// the way Silica settings pages behave.
Page {
    id: conversationSettings
    allowedOrientations: Orientation.All

    // Empty means "whatever conversation is currently open". The history
    // pushes this page with an explicit id instead.
    property string conversationId: ""

    // Conversation the fields were last loaded from, and the one changes are
    // written back to. Keeping it separate matters: the current conversation
    // can change while this page is alive.
    property string loadedId: ""
    property bool suggestingTitle: false

    // Values as loaded, so leaving the page without touching anything does not
    // rewrite the conversation file and bump its position in the history.
    property string loadedTitle: ""
    property string loadedPrompt: ""
    property string loadedCategory: ""
    property string loadedModel: ""

    // Provider of this conversation, and the models it serves. Both are read
    // fresh on reload(): the page is reused for whatever conversation is open.
    property string loadedProvider: ""
    property var providerOptions: settingsManager.availableProviders()
    property var modelOptions: [""]
    property var categoryOptions: Categories.all()

    onStatusChanged: {
        if (status === PageStatus.Activating) {
            reload()
        } else if (status === PageStatus.Deactivating) {
            apply()
        }
    }

    Component.onCompleted: reload()
    Component.onDestruction: apply()

    Connections {
        target: conversationManager
        onCurrentConversationChanged: {
            if (conversationSettings.conversationId !== "") {
                return
            }
            // Write to the conversation the fields belong to before adopting
            // the new one.
            conversationSettings.apply()
            conversationSettings.loadedId = ""
            conversationSettings.reload()
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("Conversation settings")
            }

            TextField {
                id: titleField
                width: parent.width
                label: qsTr("Title")
                placeholderText: qsTr("Conversation title")

                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: conversationSettings.suggestingTitle
                      ? qsTr("Asking the model...")
                      : qsTr("Suggest a title")
                enabled: !conversationSettings.suggestingTitle && settingsManager.hasApiKey
                onClicked: conversationSettings.suggestTitle()
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Reads the conversation and proposes a title and a category.")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
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
            }

            SectionHeader {
                text: qsTr("Provider and model")
            }

            ComboBox {
                id: providerCombo
                width: parent.width
                label: qsTr("Answers come from")
                description: qsTr("This conversation only. New conversations use the provider set in Settings.")

                menu: ContextMenu {
                    Repeater {
                        model: conversationSettings.providerOptions

                        MenuItem {
                            text: modelData.name
                            property string providerValue: modelData.id
                            onClicked: conversationSettings.changeProvider(providerValue)
                        }
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: conversationSettings.loadedProvider !== settingsManager.providerId
                text: qsTr("The rest of this conversation goes to %1, using its own API key. The answers already received do not change.")
                      .arg(settingsManager.providerNameFor(conversationSettings.loadedProvider))
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: !settingsManager.hasApiKeyFor(conversationSettings.loadedProvider)
                text: qsTr("No API key for this provider yet - add it in Settings before sending.")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.errorColor
                wrapMode: Text.WordWrap
            }

            ComboBox {
                id: modelCombo
                width: parent.width
                label: qsTr("Model for this conversation")
                description: qsTr("Overrides the default model of that provider")

                menu: ContextMenu {
                    Repeater {
                        model: conversationSettings.modelOptions

                        MenuItem {
                            text: modelData === ""
                                  ? qsTr("Use default (%1)").arg(
                                        settingsManager.modelNameFor(
                                            conversationSettings.loadedProvider))
                                  : modelData
                            property string modelValue: modelData
                        }
                    }
                }
            }

            SectionHeader {
                text: qsTr("System prompt")
            }

            TextSwitch {
                id: usePromptSwitch
                text: qsTr("Custom system prompt")
                description: qsTr("Replaces the global system prompt for this conversation only")
            }

            TextArea {
                id: promptArea
                width: parent.width
                visible: usePromptSwitch.checked
                label: qsTr("Instruction")
                placeholderText: qsTr("Enter a system prompt...")
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }
        }

        VerticalScrollDecorator {}
    }

    Connections {
        target: mistralApi

        onTitleGenerated: {
            if (targetId !== conversationSettings.loadedId) {
                return
            }
            conversationSettings.suggestingTitle = false
            titleField.text = title

            var index = conversationSettings.categoryOptions.indexOf(category)
            if (index >= 0) {
                categoryCombo.currentIndex = index
            }
        }

        onTitleGenerationFailed: {
            if (targetId === conversationSettings.loadedId) {
                conversationSettings.suggestingTitle = false
            }
        }
    }

    function reload() {
        var id = conversationId !== "" ? conversationId
                                       : conversationManager.currentConversationId()
        if (id === "" || id === loadedId) {
            return
        }
        loadedId = id

        var overrides = conversationManager.getConversationOverrides(id)

        loadedTitle = overrides.title || ""
        loadedPrompt = overrides.systemPrompt || ""
        loadedCategory = overrides.category || "other"
        loadedModel = overrides.model || ""
        loadedProvider = overrides.provider || settingsManager.providerId
        refreshModelOptions()

        titleField.text = loadedTitle
        usePromptSwitch.checked = loadedPrompt !== ""
        promptArea.text = loadedPrompt

        var categoryIndex = categoryOptions.indexOf(loadedCategory)
        categoryCombo.currentIndex = categoryIndex >= 0 ? categoryIndex
                                                        : categoryOptions.length - 1

        var providerIndex = 0
        for (var p = 0; p < providerOptions.length; p++) {
            if (providerOptions[p].id === loadedProvider) {
                providerIndex = p
                break
            }
        }
        providerCombo.currentIndex = providerIndex

        var modelIndex = modelOptions.indexOf(loadedModel)
        modelCombo.currentIndex = modelIndex >= 0 ? modelIndex : 0
    }

    function refreshModelOptions() {
        modelOptions = [""].concat(settingsManager.availableModelsFor(loadedProvider))
    }

    // Applied immediately rather than on leaving the page: the model list right
    // below belongs to the provider, and the warning has to appear at once.
    function changeProvider(providerValue) {
        if (loadedId === "" || providerValue === loadedProvider) {
            return
        }

        conversationManager.setConversationProvider(loadedId, providerValue)
        loadedProvider = providerValue
        // Dropped in C++ with the provider: the previous model does not exist
        // here, and the combo has to agree with what was stored.
        loadedModel = ""
        refreshModelOptions()
        modelCombo.currentIndex = 0
    }

    function apply() {
        if (loadedId === "") {
            return
        }

        var title = titleField.text.trim()
        var prompt = usePromptSwitch.checked ? promptArea.text.trim() : ""
        var modelValue = modelCombo.currentItem ? modelCombo.currentItem.modelValue : ""
        var category = categoryCombo.currentItem ? categoryCombo.currentItem.categoryValue : ""

        if (title !== loadedTitle) {
            conversationManager.renameConversation(loadedId, title)
            loadedTitle = title
        }

        if (prompt !== loadedPrompt || modelValue !== loadedModel) {
            conversationManager.setConversationOverrides(loadedId, modelValue, prompt)
            loadedPrompt = prompt
            loadedModel = modelValue
        }

        if (category !== "" && category !== loadedCategory) {
            conversationManager.setConversationCategory(loadedId, category)
            loadedCategory = category
        }
    }

    function suggestTitle() {
        var digest = conversationManager.conversationDigest(loadedId)
        if (digest === "") {
            return
        }

        suggestingTitle = true
        // Never name a local "model" in QML: it shadows too much. Use the
        // model this conversation would use for a normal message.
        var modelId = modelCombo.currentItem && modelCombo.currentItem.modelValue !== ""
                ? modelCombo.currentItem.modelValue
                : settingsManager.modelNameFor(loadedProvider)
        mistralApi.generateTitle(
                    settingsManager.apiKeyFor(loadedProvider),
                    settingsManager.resolveModelFor(loadedProvider, modelId),
                    digest, loadedId)
    }
}
