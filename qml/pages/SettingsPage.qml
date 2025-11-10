import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: settingsPage

    allowedOrientations: Orientation.All

    canAccept: apiKeyField.text.trim().length > 0 || !useCustomKeySwitch.checked

    onAccepted: {
        if (useCustomKeySwitch.checked) {
            settingsManager.apiKey = apiKeyField.text.trim()
            settingsManager.useCustomKey = true
        } else {
            settingsManager.useCustomKey = false
            // Note: Dans une vraie app, vous mettriez ici votre clé API free tier
            // Pour le moment, l'utilisateur doit entrer sa propre clé
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
                title: qsTr("Settings")
                acceptText: qsTr("Save")
                cancelText: qsTr("Cancel")
            }

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
                visible: settingsManager.hasApiKey() && useCustomKeySwitch.checked
                onClicked: {
                    remorse.execute(qsTr("Clearing API key"), function() {
                        apiKeyField.text = ""
                        settingsManager.clearApiKey()
                    })
                }
            }

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

            SectionHeader {
                text: qsTr("Updates")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Current version: %1").arg(updateChecker.currentVersion)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
            }

            BackgroundItem {
                width: parent.width
                height: updateLabel.height + 2 * Theme.paddingMedium
                visible: updateChecker.updateAvailable

                onClicked: Qt.openUrlExternally(updateChecker.releaseUrl)

                Label {
                    id: updateLabel
                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: qsTr("Update available: v%1").arg(updateChecker.latestVersion)
                    color: parent.highlighted ? Theme.highlightColor : Theme.primaryColor
                    font.pixelSize: Theme.fontSizeMedium
                }

                Image {
                    anchors {
                        right: parent.right
                        rightMargin: Theme.horizontalPageMargin
                        verticalCenter: parent.verticalCenter
                    }
                    source: "image://theme/icon-m-link"
                    opacity: 0.6
                }
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: updateChecker.checking ? qsTr("Checking...") : qsTr("Check for updates")
                enabled: !updateChecker.checking
                onClicked: updateChecker.checkForUpdates()
            }

            SectionHeader {
                text: qsTr("Information")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("SailCat uses Mistral AI API to provide intelligent conversations. " +
                      "Mistral's free tier offers free access with request limits suitable " +
                      "for experimentation and development.")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
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
