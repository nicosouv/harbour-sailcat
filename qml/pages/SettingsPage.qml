import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: settingsPage

    allowedOrientations: Orientation.All

    property var providerList: settingsManager.availableProviders()
    property var availableModelsList: settingsManager.availableModels()
    property var chatStyleList: settingsManager.availableChatStyles()
    property bool revealKey: false

    canAccept: true

    onAccepted: {
        // The provider is already applied; the address it needs is not.
        if (settingsManager.providerId === "custom") {
            settingsManager.customBaseUrl = baseUrlField.text.trim()
        }
        settingsManager.apiKey = apiKeyField.text.trim()

        var selectedModel = modelComboBox.visible && modelComboBox.currentItem
                            ? modelComboBox.currentItem.modelValue
                            : modelNameField.text.trim()
        if (selectedModel !== "") {
            settingsManager.modelName = selectedModel
        }

        settingsManager.temperature = customTemperatureSwitch.checked ?
                                      temperatureSlider.value : -1.0
        settingsManager.maxTokens = limitTokensSwitch.checked ?
                                    Math.round(maxTokensSlider.value) : 0
        settingsManager.contextMessageLimit = limitContextSwitch.checked ?
                                              Math.round(contextSlider.value) : 0

        if (chatStyleComboBox.currentItem) {
            settingsManager.chatStyle = chatStyleComboBox.currentItem.styleValue
        }
        settingsManager.showTimestamps = timestampsSwitch.checked

        if (systemPromptComboBox.currentItem) {
            var preset = systemPromptComboBox.currentItem.promptValue
            settingsManager.systemPrompt = preset === "__custom__" ?
                                           customPromptArea.text.trim() : preset
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            DialogHeader {
                title: qsTr("Settings & About")
                acceptText: qsTr("Save")
                cancelText: qsTr("Cancel")
            }

            // App Info Section
            Item {
                width: parent.width
                height: Theme.itemSizeLarge

                Icon {
                    anchors.centerIn: parent
                    source: "image://theme/icon-l-message"
                    width: Theme.iconSizeLarge
                    height: Theme.iconSizeLarge
                    color: Theme.highlightColor
                }
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "SailCat"
                font.pixelSize: Theme.fontSizeExtraLarge
                color: Theme.highlightColor
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Version %1").arg(settingsManager.appVersion)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
            }

            // Statistics Section
            SectionHeader {
                text: qsTr("Statistics")
            }

            BackgroundItem {
                width: parent.width

                onClicked: pageStack.push(Qt.resolvedUrl("StatsPage.qml"))

                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("View statistics")
                    color: parent.highlighted ? Theme.highlightColor : Theme.primaryColor
                }

                Icon {
                    anchors {
                        right: parent.right
                        rightMargin: Theme.horizontalPageMargin
                        verticalCenter: parent.verticalCenter
                    }
                    source: "image://theme/icon-m-right"
                }
            }

            BackgroundItem {
                width: parent.width

                onClicked: pageStack.push(Qt.resolvedUrl("PromptLibraryPage.qml"))

                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Prompt library")
                    color: parent.highlighted ? Theme.highlightColor : Theme.primaryColor
                }

                Icon {
                    anchors {
                        right: parent.right
                        rightMargin: Theme.horizontalPageMargin
                        verticalCenter: parent.verticalCenter
                    }
                    source: "image://theme/icon-m-right"
                }
            }

            // API Configuration Section
            SectionHeader {
                text: qsTr("API Configuration")
            }

            ComboBox {
                id: providerComboBox
                label: qsTr("Provider")
                description: qsTr("Every backend speaks the same protocol; only the key and the model list change")
                width: parent.width

                menu: ContextMenu {
                    Repeater {
                        model: settingsPage.providerList

                        MenuItem {
                            text: modelData.freeTier
                                  ? qsTr("%1 - free tier").arg(modelData.name)
                                  : modelData.name
                            property string providerValue: modelData.id
                            // Reacting to the click rather than to currentItem:
                            // the menu is populated after the index is restored,
                            // and that must not read as a user choice.
                            onClicked: settingsPage.applyProvider(providerValue)
                        }
                    }
                }

                Component.onCompleted: {
                    for (var i = 0; i < settingsPage.providerList.length; i++) {
                        if (settingsPage.providerList[i].id === settingsManager.providerId) {
                            currentIndex = i
                            return
                        }
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Hosted in %1").arg(settingsManager.providerRegion)
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }

            TextField {
                id: baseUrlField
                width: parent.width
                visible: settingsManager.providerId === "custom"
                label: qsTr("Endpoint base URL")
                placeholderText: qsTr("https://host/v1")
                text: settingsManager.customBaseUrl
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | Qt.ImhUrlCharactersOnly

                EnterKey.enabled: text.length > 0
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: focus = false
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: settingsManager.providerId === "custom"
                text: qsTr("Anything OpenAI-compatible, up to a llama.cpp or Ollama server on your own network.")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: settingsManager.providerKeyUrl !== ""
                text: qsTr("To get an API key, visit %1").arg(settingsManager.providerKeyUrl)
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }

            TextField {
                id: apiKeyField
                width: parent.width
                label: settingsManager.providerKeyRequired
                       ? qsTr("%1 API key").arg(settingsManager.providerName)
                       : qsTr("%1 API key (optional)").arg(settingsManager.providerName)
                placeholderText: settingsManager.providerKeyRequired
                                 ? qsTr("Enter your API key")
                                 : qsTr("Leave empty to stay anonymous")
                text: settingsManager.apiKey
                echoMode: settingsPage.revealKey ? TextInput.Normal : TextInput.Password
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | Qt.ImhSensitiveData

                EnterKey.enabled: text.length > 0
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: focus = false
            }

            TextSwitch {
                id: revealKeySwitch
                text: qsTr("Show API key")
                checked: settingsPage.revealKey
                onCheckedChanged: settingsPage.revealKey = checked
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("The key is stored scrambled in an owner-only file on this device and is only ever sent to %1. Each provider keeps its own key.").arg(settingsManager.providerBaseUrl)
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Clear API key")
                visible: settingsManager.hasApiKey
                onClicked: {
                    remorse.execute(qsTr("Clearing API key"), function() {
                        apiKeyField.text = ""
                        settingsManager.clearApiKey()
                    })
                }
            }

            // Language Selection Section
            SectionHeader {
                text: qsTr("Language")
            }

            ComboBox {
                id: languageComboBox
                label: qsTr("Application Language")
                description: qsTr("Select the language for the interface")
                width: parent.width

                // Order must match settingsManager.availableLanguages()
                menu: ContextMenu {
                    Repeater {
                        model: [
                            { name: "English", value: "en" },
                            { name: "Français", value: "fr" },
                            { name: "Deutsch", value: "de" },
                            { name: "Español", value: "es" },
                            { name: "Suomi", value: "fi" },
                            { name: "Italiano", value: "it" },
                            { name: "Norsk bokmål", value: "nb_NO" }
                        ]

                        MenuItem {
                            text: modelData.name
                            property string langValue: modelData.value
                        }
                    }
                }

                Component.onCompleted: {
                    var languages = settingsManager.availableLanguages()
                    var index = languages.indexOf(settingsManager.language)
                    currentIndex = index >= 0 ? index : 0
                }

                onCurrentItemChanged: {
                    if (currentItem) {
                        settingsManager.language = currentItem.langValue
                    }
                }
            }

            // Appearance Section
            SectionHeader {
                text: qsTr("Appearance")
            }

            ComboBox {
                id: chatStyleComboBox
                label: qsTr("Conversation style")
                description: qsTr("How messages are laid out in the chat")
                width: parent.width

                menu: ContextMenu {
                    Repeater {
                        model: settingsPage.chatStyleList

                        MenuItem {
                            text: settingsPage.chatStyleLabel(modelData)
                            property string styleValue: modelData
                        }
                    }
                }

                Component.onCompleted: {
                    var index = settingsPage.chatStyleList.indexOf(settingsManager.chatStyle)
                    currentIndex = index >= 0 ? index : 0
                }

                // Applied live so the effect is visible before saving
                onCurrentItemChanged: {
                    if (currentItem) {
                        settingsManager.chatStyle = currentItem.styleValue
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: chatStyleComboBox.currentItem
                      ? settingsPage.chatStyleDescription(chatStyleComboBox.currentItem.styleValue)
                      : ""
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }

            TextSwitch {
                id: timestampsSwitch
                text: qsTr("Show timestamps")
                description: qsTr("Display the time under each message")
                checked: settingsManager.showTimestamps
            }

            // Model Selection Section
            SectionHeader {
                text: qsTr("Model")
            }

            ComboBox {
                id: modelComboBox
                label: qsTr("Model")
                description: qsTr("Select the model to use")
                width: parent.width
                visible: settingsPage.availableModelsList.length > 0

                menu: ContextMenu {
                    Repeater {
                        model: settingsPage.availableModelsList

                        MenuItem {
                            text: prettyModelName(modelData)
                            property string modelValue: modelData
                        }
                    }
                }

                function selectCurrentModel() {
                    var index = settingsPage.availableModelsList.indexOf(settingsManager.modelName)
                    currentIndex = index >= 0 ? index : 0
                }

                Component.onCompleted: selectCurrentModel()
            }

            // A custom endpoint has no catalogue to offer until it has been
            // queried once, so the model id is typed in.
            TextField {
                id: modelNameField
                width: parent.width
                visible: settingsPage.availableModelsList.length === 0
                label: qsTr("Model")
                placeholderText: qsTr("Model identifier")
                text: settingsManager.modelName
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase

                EnterKey.enabled: text.length > 0
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: focus = false
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: modelComboBox.currentItem &&
                      settingsManager.isVisionModel(modelComboBox.currentItem.modelValue)
                      ? qsTr("This model can analyze images") : ""
                visible: text !== ""
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }

            // Generation Parameters Section
            SectionHeader {
                text: qsTr("Generation")
            }

            TextSwitch {
                id: customTemperatureSwitch
                text: qsTr("Custom temperature")
                description: qsTr("Lower is more focused, higher is more creative")
                checked: settingsManager.temperature >= 0.0
            }

            Slider {
                id: temperatureSlider
                width: parent.width
                visible: customTemperatureSwitch.checked
                minimumValue: 0.0
                maximumValue: 1.5
                stepSize: 0.1
                value: settingsManager.temperature >= 0.0 ? settingsManager.temperature : 0.7
                valueText: value.toFixed(1)
                label: qsTr("Temperature")
            }

            TextSwitch {
                id: limitTokensSwitch
                text: qsTr("Limit response length")
                description: qsTr("Maximum number of tokens per response")
                checked: settingsManager.maxTokens > 0
            }

            Slider {
                id: maxTokensSlider
                width: parent.width
                visible: limitTokensSwitch.checked
                minimumValue: 256
                maximumValue: 8192
                stepSize: 256
                value: settingsManager.maxTokens > 0 ? settingsManager.maxTokens : 1024
                valueText: Math.round(value)
                label: qsTr("Max tokens")
            }

            TextSwitch {
                id: limitContextSwitch
                text: qsTr("Limit conversation context")
                description: qsTr("Send only the most recent messages. Keeps long conversations cheap and avoids hitting the model context limit.")
                checked: settingsManager.contextMessageLimit > 0
            }

            Slider {
                id: contextSlider
                width: parent.width
                visible: limitContextSwitch.checked
                minimumValue: 4
                maximumValue: 60
                stepSize: 2
                value: settingsManager.contextMessageLimit > 0 ? settingsManager.contextMessageLimit : 20
                valueText: qsTr("%n message(s)", "", Math.round(value))
                label: qsTr("Messages kept")
            }

            // System Prompt Section
            SectionHeader {
                text: qsTr("System prompt")
            }

            ComboBox {
                id: systemPromptComboBox
                label: qsTr("Persona")
                description: qsTr("Instruction sent before every conversation")
                width: parent.width

                // Preset prompts are sent to the API: keep them in English, untranslated
                property var presets: [
                    { name: qsTr("None"), value: "" },
                    { name: qsTr("Concise"), value: "Be concise. Answer directly without filler or repetition." },
                    { name: qsTr("Translator"), value: "You are a translator. Translate the user's message to English if it is in another language, otherwise to French. Output only the translation." },
                    { name: qsTr("Code assistant"), value: "You are a programming assistant. Prefer short code examples. Assume the user is an experienced developer." },
                    { name: qsTr("Custom"), value: "__custom__" }
                ]

                menu: ContextMenu {
                    Repeater {
                        model: systemPromptComboBox.presets

                        MenuItem {
                            text: modelData.name
                            property string promptValue: modelData.value
                        }
                    }
                }

                Component.onCompleted: {
                    var current = settingsManager.systemPrompt
                    if (current === "") {
                        currentIndex = 0
                        return
                    }
                    for (var i = 1; i < presets.length - 1; i++) {
                        if (presets[i].value === current) {
                            currentIndex = i
                            return
                        }
                    }
                    currentIndex = presets.length - 1  // Custom
                }
            }

            TextArea {
                id: customPromptArea
                width: parent.width
                visible: systemPromptComboBox.currentItem &&
                         systemPromptComboBox.currentItem.promptValue === "__custom__"
                label: qsTr("Custom system prompt")
                placeholderText: qsTr("Enter a custom system prompt...")

                Component.onCompleted: {
                    var current = settingsManager.systemPrompt
                    if (current === "") return
                    var presets = systemPromptComboBox.presets
                    for (var i = 1; i < presets.length - 1; i++) {
                        if (presets[i].value === current) return
                    }
                    text = current
                }
            }

            // About Section
            SectionHeader {
                text: qsTr("About")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("SailCat is an elegant chat client for Mistral AI and other " +
                      "OpenAI-compatible providers, designed for Sailfish OS.")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primaryColor
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("• Conversations stored locally\n• No sync with any web interface\n• Uses your own account with the provider")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Source code on GitHub")
                onClicked: Qt.openUrlExternally("https://github.com/nicosouv/harbour-sailcat")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Powered by %1 • MIT License").arg(settingsManager.providerName)
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                horizontalAlignment: Text.AlignHCenter
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Made with <3 for Sailfish OS")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                horizontalAlignment: Text.AlignHCenter
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }
        }

        VerticalScrollDecorator {}
    }

    RemorsePopup {
        id: remorse
    }

    Connections {
        target: mistralApi

        onModelsFetched: {
            settingsManager.updateModelCache(models)
            settingsPage.availableModelsList = settingsManager.availableModels()
            modelComboBox.selectCurrentModel()
            modelNameField.text = settingsManager.modelName
        }
    }

    Component.onCompleted: fetchModelsIfNeeded()

    // Applied straight away rather than on Save: the key field and the model
    // list below it both belong to the selected provider.
    function applyProvider(providerValue) {
        if (providerValue === settingsManager.providerId) {
            return
        }
        // Whatever was typed belongs to the provider being left, and the field
        // is about to be overwritten: keep it there.
        settingsManager.apiKey = apiKeyField.text.trim()
        settingsManager.providerId = providerValue
        apiKeyField.text = settingsManager.apiKey
        availableModelsList = settingsManager.availableModels()
        modelComboBox.selectCurrentModel()
        modelNameField.text = settingsManager.modelName
        fetchModelsIfNeeded()
    }

    function fetchModelsIfNeeded() {
        // The cache is per provider, so a switch to one never queried before
        // fetches even though the previous provider had a fresh list.
        if (settingsManager.hasApiKey && settingsManager.modelCacheStale()) {
            mistralApi.fetchModels(settingsManager.apiKey)
        }
    }

    function prettyModelName(id) {
        var parts = id.replace(/-latest$/, "").split("-")
        for (var i = 0; i < parts.length; i++) {
            parts[i] = parts[i].charAt(0).toUpperCase() + parts[i].slice(1)
        }
        return parts.join(" ")
    }

    function chatStyleLabel(style) {
        switch (style) {
        case "bubbles": return qsTr("Bubbles")
        case "compact": return qsTr("Compact")
        case "cards": return qsTr("Cards")
        default: return qsTr("Flat")
        }
    }

    function chatStyleDescription(style) {
        switch (style) {
        case "bubbles": return qsTr("Rounded bubbles aligned left and right, like a messaging app.")
        case "compact": return qsTr("Dense rows with a short speaker prefix. Fits the most text on screen.")
        case "cards": return qsTr("Each message in its own panel with a header.")
        default: return qsTr("Full width rows with a tinted background on your messages.")
        }
    }
}
