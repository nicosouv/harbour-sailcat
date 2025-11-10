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
                title: "Paramètres"
                acceptText: "Enregistrer"
                cancelText: "Annuler"
            }

            SectionHeader {
                text: "Configuration de l'API"
            }

            TextSwitch {
                id: useCustomKeySwitch
                text: "Utiliser ma propre clé API"
                description: "Activez cette option pour utiliser votre clé API personnelle Mistral"
                checked: settingsManager.useCustomKey
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: "Pour obtenir une clé API gratuite, visitez console.mistral.ai"
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
                visible: useCustomKeySwitch.checked
            }

            TextField {
                id: apiKeyField
                width: parent.width
                label: "Clé API Mistral"
                placeholderText: "Entrez votre clé API"
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
                text: "Effacer la clé API"
                visible: settingsManager.hasApiKey() && useCustomKeySwitch.checked
                onClicked: {
                    remorse.execute("Effacement de la clé API", function() {
                        apiKeyField.text = ""
                        settingsManager.clearApiKey()
                    })
                }
            }

            SectionHeader {
                text: "Modèle"
            }

            ComboBox {
                id: modelComboBox
                label: "Modèle Mistral"
                description: "Sélectionnez le modèle à utiliser"
                width: parent.width

                menu: ContextMenu {
                    Repeater {
                        model: [
                            { name: "Mistral Small (Recommandé)", value: "mistral-small-latest" },
                            { name: "Mistral Large", value: "mistral-large-latest" },
                            { name: "Pixtral 12B (Vision)", value: "pixtral-12b-latest" }
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
                text: "Mises à jour"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: "Version actuelle: " + updateChecker.currentVersion
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
                    text: "Mise à jour disponible: v" + updateChecker.latestVersion
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
                text: updateChecker.checking ? "Vérification..." : "Vérifier les mises à jour"
                enabled: !updateChecker.checking
                onClicked: updateChecker.checkForUpdates()
            }

            SectionHeader {
                text: "Informations"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: "SailCat utilise l'API de Mistral AI pour fournir des conversations intelligentes. " +
                      "Le free tier de Mistral offre un accès gratuit avec des limites de requêtes adaptées " +
                      "à l'expérimentation et au développement."
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
            return "Modèle équilibré entre performance et rapidité. Idéal pour la plupart des conversations."
        case 1:
            return "Modèle le plus puissant pour les tâches complexes. Nécessite plus de crédits API."
        case 2:
            return "Modèle avec support d'images. Peut analyser et comprendre des images."
        default:
            return ""
        }
    }
}
