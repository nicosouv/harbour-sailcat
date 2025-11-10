import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"

Page {
    id: chatPage
    objectName: "chatPage"
    allowedOrientations: Orientation.All

    property bool firstUse: !settingsManager.hasApiKey()
    property string streamingContent: ""

    SilicaListView {
        id: messageListView
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: inputArea.top
        }
        clip: true

        model: conversationModel
        spacing: Theme.paddingMedium

        header: PageHeader {
            title: "SailCat"
            description: settingsManager.modelName
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("About")
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }
            MenuItem {
                text: qsTr("Conversation History")
                onClicked: pageStack.push(Qt.resolvedUrl("ConversationHistoryPage.qml"))
            }
            MenuItem {
                text: qsTr("Settings")
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
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

        ViewPlaceholder {
            enabled: conversationModel.count === 0
            text: firstUse ? qsTr("Welcome to SailCat") : qsTr("Start a conversation")
            hintText: firstUse ? qsTr("Configure your Mistral API key to get started") : qsTr("Type a message below")
        }

        delegate: MessageBubble {
            width: messageListView.width
            role: model.role
            content: model.content
        }

        VerticalScrollDecorator {}
    }

    // Footer with input area
    Column {
        id: inputArea
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        spacing: 0

        // Error banner
        Rectangle {
            width: parent.width
            height: mistralApi.error !== "" ? errorLabel.height + Theme.paddingMedium * 2 : 0
            color: Theme.rgba(Theme.errorColor, 0.2)
            visible: height > 0

            Behavior on height { NumberAnimation { duration: 200 } }

            Label {
                id: errorLabel
                anchors {
                    left: parent.left
                    right: closeErrorButton.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: Theme.horizontalPageMargin
                    rightMargin: Theme.paddingMedium
                }
                text: mistralApi.error
                color: Theme.errorColor
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
            }

            IconButton {
                id: closeErrorButton
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    rightMargin: Theme.paddingMedium
                }
                icon.source: "image://theme/icon-m-clear"
                onClicked: mistralApi.clearError()
            }
        }

        Separator {
            width: parent.width
            color: Theme.highlightColor
            opacity: 0.3
        }

        // Input row
        Item {
            width: parent.width
            height: Math.max(messageInput.height, Theme.itemSizeSmall) + Theme.paddingMedium * 2

            Row {
                anchors {
                    fill: parent
                    margins: Theme.paddingMedium
                }
                spacing: Theme.paddingMedium

                TextArea {
                    id: messageInput
                    width: parent.width - sendButton.width - parent.spacing
                    height: Math.min(implicitHeight, Theme.itemSizeSmall * 2.5)
                    placeholderText: qsTr("Type a message...")
                    labelVisible: false
                    enabled: !mistralApi.isBusy && settingsManager.hasApiKey()
                    font.pixelSize: Theme.fontSizeSmall

                    EnterKey.enabled: text.trim().length > 0 && !mistralApi.isBusy
                    EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                    EnterKey.onClicked: sendMessage()
                }

                IconButton {
                    id: sendButton
                    anchors.verticalCenter: parent.verticalCenter
                    icon.source: mistralApi.isBusy
                        ? "image://theme/icon-m-pause"
                        : "image://theme/icon-m-message"
                    enabled: (!mistralApi.isBusy && messageInput.text.trim().length > 0 && settingsManager.hasApiKey()) || mistralApi.isBusy

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

        // Busy indicator
        Item {
            width: parent.width
            height: mistralApi.isBusy ? Theme.itemSizeExtraSmall : 0
            visible: height > 0

            BusyIndicator {
                anchors.centerIn: parent
                running: mistralApi.isBusy
                size: BusyIndicatorSize.Small
            }
        }
    }

    // Docked panel for conversation history (swipe right)
    DockedPanel {
        id: conversationPanel
        width: parent.width
        height: parent.height
        dock: Dock.Left
        open: false

        SilicaListView {
            anchors.fill: parent

            header: PageHeader {
                title: qsTr("Conversations")
            }

            model: ListModel {
                id: conversationsListModel
            }

            delegate: ListItem {
                id: conversationItem
                contentHeight: Theme.itemSizeMedium

                onClicked: {
                    conversationManager.loadConversation(model.id)
                    conversationPanel.hide()
                    streamingContent = ""
                }

                menu: ContextMenu {
                    MenuItem {
                        text: qsTr("Delete")
                        onClicked: {
                            conversationItem.remorseAction(qsTr("Deleting"), function() {
                                conversationManager.deleteConversation(model.id)
                                refreshConversationsList()
                            })
                        }
                    }
                }

                Column {
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: Theme.horizontalPageMargin
                        rightMargin: Theme.horizontalPageMargin
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: model.title
                        color: conversationItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                        font.pixelSize: Theme.fontSizeMedium
                        truncationMode: TruncationMode.Fade
                    }

                    Row {
                        spacing: Theme.paddingMedium

                        Label {
                            text: Qt.formatDateTime(new Date(model.updatedAt), "dd/MM/yyyy")
                            color: conversationItem.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }

                        Label {
                            text: "•"
                            color: conversationItem.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }

                        Label {
                            text: qsTr("%n message(s)", "", model.messageCount)
                            color: conversationItem.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }
                }
            }

            ViewPlaceholder {
                enabled: conversationsListModel.count === 0
                text: qsTr("No conversations")
                hintText: qsTr("Start chatting to create conversations")
            }

            VerticalScrollDecorator {}
        }

        IconButton {
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: Theme.paddingLarge
            }
            icon.source: "image://theme/icon-m-add"
            onClicked: {
                conversationManager.createNewConversation()
                conversationPanel.hide()
                streamingContent = ""
            }
        }
    }

    // First use dialog
    Dialog {
        id: firstUseDialog
        allowedOrientations: Orientation.All
        canAccept: false

        SilicaFlickable {
            anchors.fill: parent
            contentHeight: column.height

            Column {
                id: column
                width: parent.width
                spacing: Theme.paddingLarge

                DialogHeader {
                    title: qsTr("Welcome")
                    acceptText: ""
                }

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: "image://theme/icon-l-message"
                    color: Theme.highlightColor
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "SailCat"
                    font.pixelSize: Theme.fontSizeExtraLarge
                    color: Theme.highlightColor
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: qsTr("Welcome to SailCat! To get started, you need to configure your Mistral AI API key in Settings.")
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Open Settings")
                    onClicked: {
                        firstUseDialog.close()
                        pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
                    }
                }

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Skip for now")
                    onClicked: firstUseDialog.close()
                }
            }
        }
    }

    RemorsePopup {
        id: remorse
    }

    // Connections to API
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
            messageListView.positionViewAtEnd()
            conversationManager.saveCurrentConversation()

            // Generate title after first exchange (2 messages: user + assistant)
            if (conversationModel.count === 2) {
                var firstMessage = conversationModel.getFirstUserMessage()
                if (firstMessage) {
                    mistralApi.generateTitle(settingsManager.apiKey, settingsManager.modelName, firstMessage)
                }
            }
        }

        onTitleGenerated: {
            conversationManager.updateCurrentConversationTitle(title)
        }
    }

    Component.onCompleted: {
        refreshConversationsList()
        if (firstUse) {
            firstUseDialog.open()
        }
    }

    function sendMessage() {
        var message = messageInput.text.trim()
        if (message.length === 0) return

        if (!settingsManager.hasApiKey()) {
            pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            return
        }

        messageInput.text = ""
        conversationModel.addUserMessage(message)

        var apiKey = settingsManager.apiKey
        var modelName = settingsManager.modelName
        var messages = conversationModel.getMessagesForApi()

        conversationModel.addAssistantMessage("")
        mistralApi.sendMessage(apiKey, modelName, messages)
        messageListView.positionViewAtEnd()
    }

    function refreshConversationsList() {
        conversationsListModel.clear()
        var conversations = conversationManager.getConversationsList()
        for (var i = 0; i < conversations.length; i++) {
            conversationsListModel.append(conversations[i])
        }
    }
}
