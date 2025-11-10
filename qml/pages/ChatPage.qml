import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: chatPage
    allowedOrientations: Orientation.All

    property bool firstUse: !settingsManager.hasApiKey()
    property string streamingContent: ""

    Item {
        anchors.fill: parent

        SilicaListView {
            id: messageListView
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                bottom: inputArea.top
            }

            PullDownMenu {
                MenuItem {
                    text: qsTr("About")
                    onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
                }
                MenuItem {
                    text: qsTr("Settings")
                    onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
                }
                MenuItem {
                    text: qsTr("Conversations")
                    onClicked: {
                        conversationManager.saveCurrentConversation()
                        pageStack.push(Qt.resolvedUrl("ConversationListPage.qml"))
                    }
                }
                MenuItem {
                    text: qsTr("New conversation")
                    enabled: conversationModel.count > 0
                    onClicked: {
                        remorse.execute(qsTr("New conversation"), function() {
                            conversationManager.createNewConversation()
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
                    text: qsTr("Welcome to SailCat")
                    hintText: qsTr("Configure your Mistral API key to get started")
                }

                Item {
                    width: parent.width
                    height: firstUse && conversationModel.count === 0 ? Theme.itemSizeExtraLarge : 0
                    visible: height > 0

                    Button {
                        anchors.centerIn: parent
                        text: qsTr("Configure")
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

            delegate: Item {
                id: messageItem
                width: parent.width
                height: messageBubble.height + Theme.paddingMedium

                Rectangle {
                    id: messageBubble
                    width: Math.min(messageLabel.implicitWidth + Theme.paddingLarge * 2, parent.width * 0.8)
                    height: messageLabel.height + Theme.paddingMedium * 2
                    radius: Theme.paddingMedium
                    color: model.role === "user" ? Theme.rgba(Theme.highlightBackgroundColor, 0.2) : Theme.rgba(Theme.secondaryHighlightColor, 0.15)

                    anchors {
                        right: model.role === "user" ? parent.right : undefined
                        left: model.role === "assistant" ? parent.left : undefined
                        rightMargin: model.role === "user" ? Theme.horizontalPageMargin : 0
                        leftMargin: model.role === "assistant" ? Theme.horizontalPageMargin : 0
                    }

                    Label {
                        id: messageLabel
                        anchors {
                            fill: parent
                            margins: Theme.paddingMedium
                        }
                        text: model.content
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.primaryColor
                    }
                }
            }

            VerticalScrollDecorator {}
        }

        // Zone de saisie en bas de l'écran
        Column {
            id: inputArea
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
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
                        placeholderText: qsTr("Your message...")
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

        // Sauvegarder la conversation après chaque envoi
        conversationManager.saveCurrentConversation()
    }
}
