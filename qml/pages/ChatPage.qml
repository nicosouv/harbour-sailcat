import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: chatPage

    allowedOrientations: Orientation.All

    // État de l'UI
    property bool firstUse: !settingsManager.hasApiKey()

    // Gestion du streaming
    property string streamingContent: ""

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            MenuItem {
                text: "À propos"
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }
            MenuItem {
                text: "Paramètres"
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: "Nouvelle conversation"
                enabled: conversationModel.count > 0
                onClicked: {
                    remorse.execute("Effacement de la conversation", function() {
                        conversationModel.clearConversation()
                        streamingContent = ""
                    })
                }
            }
        }

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: "SailCat"
                description: settingsManager.modelName
            }

            // Message de premier usage
            Item {
                width: parent.width
                height: firstUse ? welcomeColumn.height : 0
                visible: firstUse && conversationModel.count === 0
                clip: true

                Behavior on height { NumberAnimation { duration: 200 } }

                Column {
                    id: welcomeColumn
                    width: parent.width
                    spacing: Theme.paddingLarge
                    padding: Theme.horizontalPageMargin

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        source: "image://theme/icon-l-chat"
                        color: Theme.highlightColor
                    }

                    Label {
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Bienvenue sur SailCat"
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.highlightColor
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Label {
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Pour commencer, configurez votre clé API Mistral dans les paramètres."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.secondaryColor
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Button {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Configurer"
                        onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
                    }
                }
            }

            // Liste des messages
            SilicaListView {
                id: messageListView
                width: parent.width
                height: Math.min(contentHeight, Screen.height - header.height - inputArea.height - Theme.paddingLarge * 2)
                clip: true

                model: conversationModel

                verticalLayoutDirection: ListView.BottomToTop

                delegate: ListItem {
                    id: messageItem
                    width: parent.width
                    contentHeight: messageContent.height + Theme.paddingMedium * 2

                    Rectangle {
                        anchors {
                            left: model.role === "user" ? parent.left : undefined
                            right: model.role === "assistant" ? parent.right : undefined
                            leftMargin: model.role === "user" ? Theme.horizontalPageMargin : parent.width * 0.2
                            rightMargin: model.role === "assistant" ? Theme.horizontalPageMargin : parent.width * 0.2
                            top: parent.top
                            topMargin: Theme.paddingMedium
                        }

                        width: parent.width * 0.8
                        height: messageContent.height + Theme.paddingMedium * 2
                        radius: Theme.paddingSmall
                        color: model.role === "user" ?
                                   Theme.rgba(Theme.highlightBackgroundColor, 0.2) :
                                   Theme.rgba(Theme.secondaryHighlightColor, 0.1)

                        Label {
                            id: messageContent
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: Theme.paddingMedium
                            }
                            text: model.content
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.fontSizeSmall
                            color: model.role === "user" ? Theme.highlightColor : Theme.primaryColor
                        }
                    }
                }

                VerticalScrollDecorator {}
            }

            // Message d'erreur
            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                visible: mistralApi.error !== ""
                text: mistralApi.error
                color: Theme.errorColor
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
                padding: Theme.paddingMedium
            }

            // Indicateur de chargement
            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: mistralApi.isBusy
                size: BusyIndicatorSize.Small
            }

            // Zone de saisie
            Item {
                id: inputArea
                width: parent.width
                height: inputRow.height + Theme.paddingLarge

                Row {
                    id: inputRow
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.paddingMedium

                    TextField {
                        id: messageInput
                        width: parent.width - sendButton.width - Theme.paddingMedium
                        placeholderText: "Votre message..."
                        label: "Message"
                        enabled: !mistralApi.isBusy && settingsManager.hasApiKey()

                        EnterKey.enabled: text.length > 0
                        EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                        EnterKey.onClicked: sendMessage()
                    }

                    IconButton {
                        id: sendButton
                        icon.source: mistralApi.isBusy ?
                                         "image://theme/icon-m-close" :
                                         "image://theme/icon-m-send"
                        anchors.verticalCenter: parent.verticalCenter
                        enabled: (!mistralApi.isBusy && messageInput.text.length > 0 && settingsManager.hasApiKey()) ||
                                 mistralApi.isBusy
                        onClicked: {
                            if (mistralApi.isBusy) {
                                mistralApi.cancelRequest()
                            } else {
                                sendMessage()
                            }
                        }
                    }
                }
            }
        }
    }

    // Remorse pour la suppression
    RemorsePopup {
        id: remorse
    }

    // Connexions aux signaux de l'API
    Connections {
        target: mistralApi

        onStreamingResponse: {
            streamingContent += content
            conversationModel.updateLastAssistantMessage(streamingContent)
        }

        onMessageSent: {
            streamingContent = ""
        }

        onResponseCompleted: {
            streamingContent = ""
        }
    }

    // Fonction pour envoyer un message
    function sendMessage() {
        if (messageInput.text.trim().length === 0) {
            return
        }

        if (!settingsManager.hasApiKey()) {
            pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            return
        }

        // Ajouter le message de l'utilisateur
        conversationModel.addUserMessage(messageInput.text.trim())

        // Préparer le message pour l'API
        var apiKey = settingsManager.apiKey
        var modelName = settingsManager.modelName
        var messages = conversationModel.toJsonArray()

        // Envoyer la requête
        mistralApi.sendMessage(apiKey, modelName, messages)

        // Vider le champ de saisie
        messageInput.text = ""

        // Ajouter un message vide de l'assistant (sera rempli par le streaming)
        conversationModel.addAssistantMessage("")
    }
}
