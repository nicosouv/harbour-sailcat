import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: settingsPage

    allowedOrientations: Orientation.All

    canAccept: apiKeyField.text.trim().length > 0 || !useCustomKeySwitch.checked

    property var stats: conversationManager.getStatistics()

    onAccepted: {
        if (useCustomKeySwitch.checked) {
            settingsManager.apiKey = apiKeyField.text.trim()
            settingsManager.useCustomKey = true
        } else {
            settingsManager.useCustomKey = false
            settingsManager.apiKey = ""
        }

        var selectedModel = modelComboBox.currentItem ?
                            modelComboBox.currentItem.modelValue :
                            "mistral-small-latest"
        settingsManager.modelName = selectedModel
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
                text: qsTr("Version %1").arg(updateChecker.currentVersion)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
            }

            // Statistics Section
            SectionHeader {
                text: qsTr("Statistics")
            }

            Column {
                width: parent.width
                spacing: Theme.paddingSmall

                DetailItem {
                    label: qsTr("Total messages")
                    value: stats.totalMessages || "0"
                }

                DetailItem {
                    label: qsTr("Messages sent")
                    value: stats.totalUserMessages || "0"
                }

                DetailItem {
                    label: qsTr("Messages received")
                    value: stats.totalAssistantMessages || "0"
                }

                DetailItem {
                    label: qsTr("Conversations")
                    value: stats.totalConversations || "0"
                }

                DetailItem {
                    label: qsTr("Estimated tokens used")
                    value: (stats.estimatedTokens || 0).toLocaleString(Qt.locale(), 'f', 0)
                    visible: stats.estimatedTokens > 0
                }

                DetailItem {
                    label: qsTr("Longest conversation")
                    value: stats.longestConvTitle ? stats.longestConvTitle + " (" + stats.longestConvMessages + ")" : qsTr("None")
                    visible: stats.longestConvMessages > 0
                }

                DetailItem {
                    label: qsTr("Longest message")
                    value: qsTr("%n character(s)", "", stats.longestMessageLength || 0)
                    visible: stats.longestMessageLength > 0
                }

                DetailItem {
                    label: qsTr("First message")
                    value: stats.firstMessageDate > 0 ? Qt.formatDateTime(new Date(stats.firstMessageDate), "dd/MM/yyyy") : qsTr("Never")
                }

                DetailItem {
                    label: qsTr("Storage used")
                    value: conversationManager.getStorageSizeFormatted()
                }
            }

            // API Configuration Section
            SectionHeader {
                text: qsTr("API Configuration")
            }

            TextSwitch {
                id: useCustomKeySwitch
                text: qsTr("Use my own API key")
                description: qsTr("Enable this option to use your personal Mistral API key")
                checked: settingsManager.useCustomKey
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("To get a free API key, visit console.mistral.ai")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
                visible: useCustomKeySwitch.checked
            }

            TextField {
                id: apiKeyField
                width: parent.width
                label: qsTr("Mistral API Key")
                placeholderText: qsTr("Enter your API key")
                text: settingsManager.apiKey
                visible: useCustomKeySwitch.checked
                enabled: useCustomKeySwitch.checked
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase

                EnterKey.enabled: text.length > 0
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: settingsPage.accept()
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Clear API key")
                visible: settingsManager.hasApiKey && useCustomKeySwitch.checked
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

                menu: ContextMenu {
                    Repeater {
                        model: [
                            { name: "English", value: "en" },
                            { name: "Français", value: "fr" },
                            { name: "Deutsch", value: "de" },
                            { name: "Español", value: "es" },
                            { name: "Suomi", value: "fi" },
                            { name: "Italiano", value: "it" }
                        ]

                        MenuItem {
                            text: modelData.name
                            property string langValue: modelData.value
                        }
                    }
                }

                Component.onCompleted: {
                    var currentLang = settingsManager.language
                    var languages = ["en", "fr", "de", "es", "fi", "it"]
                    var index = languages.indexOf(currentLang)
                    if (index >= 0) {
                        currentIndex = index
                    } else {
                        currentIndex = 0
                    }
                }

                onCurrentItemChanged: {
                    if (currentItem) {
                        settingsManager.language = currentItem.langValue
                    }
                }
            }

            // Model Selection Section
            SectionHeader {
                text: qsTr("Model")
            }

            ComboBox {
                id: modelComboBox
                label: qsTr("Mistral Model")
                description: qsTr("Select the model to use")
                width: parent.width

                menu: ContextMenu {
                    Repeater {
                        model: [
                            { name: qsTr("Mistral Small (Recommended)"), value: "mistral-small-latest" },
                            { name: qsTr("Mistral Large"), value: "mistral-large-latest" },
                            { name: qsTr("Pixtral 12B (Vision)"), value: "pixtral-12b-latest" }
                        ]

                        MenuItem {
                            text: modelData.name
                            property string modelValue: modelData.value
                        }
                    }
                }

                Component.onCompleted: {
                    var currentModel = settingsManager.modelName
                    var models = ["mistral-small-latest", "mistral-large-latest", "pixtral-12b-latest"]
                    var index = models.indexOf(currentModel)
                    if (index >= 0) {
                        currentIndex = index
                    } else {
                        currentIndex = 0
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: getModelDescription()
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }

            // About Section
            SectionHeader {
                text: qsTr("About")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("SailCat is an elegant client for Mistral AI Chat, " +
                      "specifically designed for Sailfish OS.")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primaryColor
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Source code on GitHub")
                onClicked: Qt.openUrlExternally("https://github.com/nicosouv/harbour-sailcat")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Powered by Mistral AI • MIT License")
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

    function getModelDescription() {
        var index = modelComboBox.currentIndex
        switch(index) {
        case 0:
            return qsTr("Balanced model between performance and speed. Ideal for most conversations.")
        case 1:
            return qsTr("Most powerful model for complex tasks. Requires more API credits.")
        case 2:
            return qsTr("Model with image support. Can analyze and understand images.")
        default:
            return ""
        }
    }
}
