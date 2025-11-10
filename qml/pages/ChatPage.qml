import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: chatPage
    allowedOrientations: Orientation.All

    property bool firstUse: !settingsManager.hasApiKey()
    property string streamingContent: ""

    SilicaListView {
        id: messageListView
        anchors.fill: parent

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

        header: Column {
            width: parent.width
            spacing: 0

            PageHeader {
                title: "SailCat"
                description: settingsManager.modelName
            }

            ViewPlaceholder {
                enabled: firstUse && conversationModel.count === 0
                text: "Bienvenue sur SailCat"
                hintText: "Configurez votre clé API Mistral pour commencer"
            }

            Item {
                width: parent.width
                height: firstUse && conversationModel.count === 0 ? Theme.itemSizeExtraLarge : 0
                visible: height > 0

                Button {
                    anchors.centerIn: parent
                    text: "Configurer"
                    onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
                }
            }

            Item {
                width: parent.width
                height: mistralApi.error !== "" ? errorLabel.height + Theme.paddingLarge * 2 : 0
                visible: height > 0

                Label {
                    id: errorLabel
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: Theme.horizontalPageMargin
                    }
                    text: mistralApi.error
                    color: Theme.errorColor
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeSmall
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Item {
                width: parent.width
                height: mistralApi.isBusy ? Theme.itemSizeLarge : 0
                visible: height > 0

                BusyIndicator {
                    anchors.centerIn: parent
                    running: mistralApi.isBusy
                    size: BusyIndicatorSize.Medium
                }
            }
        }

        model: conversationModel
        verticalLayoutDirection: ListView.BottomToTop

        delegate: ListItem {
            id: messageItem
            width: parent.width
            contentHeight: contentColumn.height + Theme.paddingMedium

            Column {
                id: contentColumn
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors {
                    left: parent.left
                    leftMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                spacing: Theme.paddingSmall

                Label {
                    width: parent.width
                    text: model.role === "user" ? "Vous" : "Assistant"
                    color: model.role === "user" ? Theme.highlightColor : Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                }

                Label {
                    width: parent.width
                    text: model.content
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }
            }
        }

        VerticalScrollDecorator {}

        footer: Item {
            width: parent.width
            height: inputColumn.height + Theme.paddingLarge

            Column {
                id: inputColumn
                width: parent.width
                spacing: 0

                Separator {
                    width: parent.width
                    color: Theme.secondaryColor
                }

                Item {
                    width: parent.width
                    height: Theme.itemSizeMedium

                    Row {
                        anchors {
                            fill: parent
                            leftMargin: Theme.horizontalPageMargin
                            rightMargin: Theme.paddingMedium
                        }
                        spacing: Theme.paddingMedium

                        TextField {
                            id: messageInput
                            width: parent.width - sendButton.width - Theme.paddingMedium
                            anchors.verticalCenter: parent.verticalCenter
                            placeholderText: "Votre message..."
                            enabled: !mistralApi.isBusy && settingsManager.hasApiKey()
                            labelVisible: false

                            EnterKey.enabled: text.length > 0
                            EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                            EnterKey.onClicked: sendMessage()
                        }

                        IconButton {
                            id: sendButton
                            anchors.verticalCenter: parent.verticalCenter
                            icon.source: mistralApi.isBusy ?
                                             "image://theme/icon-m-clear" :
                                             "image://theme/icon-m-message"
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
    }

    RemorsePopup {
        id: remorse
    }

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
            messageListView.positionViewAtBeginning()
        }
    }

    function sendMessage() {
        if (messageInput.text.trim().length === 0) {
            return
        }

        if (!settingsManager.hasApiKey()) {
            pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            return
        }

        conversationModel.addUserMessage(messageInput.text.trim())

        var apiKey = settingsManager.apiKey
        var modelName = settingsManager.modelName
        var messages = conversationModel.toJsonArray()

        mistralApi.sendMessage(apiKey, modelName, messages)

        messageInput.text = ""

        conversationModel.addAssistantMessage("")

        messageListView.positionViewAtBeginning()
    }
}
