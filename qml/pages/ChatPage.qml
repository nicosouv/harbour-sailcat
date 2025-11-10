import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: chatPage
    allowedOrientations: Orientation.All

    property bool firstUse: !settingsManager.hasApiKey()
    property string streamingContent: ""

    // Header
    PageHeader {
        id: pageHeader
        title: "SailCat"
        description: settingsManager.modelName
    }

    // Main content area with messages
    SilicaListView {
        id: messageListView
        anchors {
            top: pageHeader.bottom
            left: parent.left
            right: parent.right
            bottom: inputArea.top
        }
        clip: true

        model: conversationModel
        verticalLayoutDirection: ListView.BottomToTop
        spacing: Theme.paddingMedium

        ViewPlaceholder {
            enabled: conversationModel.count === 0
            text: firstUse ? qsTr("Welcome to SailCat") : qsTr("Start a conversation")
            hintText: firstUse ? qsTr("Configure your Mistral API key to get started") : qsTr("Type a message below")
        }

        delegate: Item {
            id: messageDelegate
            width: messageListView.width
            height: messageBubble.height + Theme.paddingMedium

            Item {
                id: messageBubble
                width: parent.width
                height: bubbleBackground.height

                // Background bubble
                Rectangle {
                    id: bubbleBackground
                    width: Math.min(messageText.implicitWidth + Theme.paddingLarge * 2, parent.width * 0.85)
                    height: messageText.height + Theme.paddingMedium * 2
                    radius: Theme.paddingSmall
                    color: model.role === "user"
                        ? Theme.rgba(Theme.highlightBackgroundColor, 0.3)
                        : Theme.rgba(Theme.secondaryColor, 0.1)

                    anchors {
                        right: model.role === "user" ? parent.right : undefined
                        left: model.role === "assistant" ? parent.left : undefined
                        rightMargin: model.role === "user" ? Theme.horizontalPageMargin : 0
                        leftMargin: model.role === "assistant" ? Theme.horizontalPageMargin : 0
                    }

                    // Triangle pointer
                    Canvas {
                        id: pointer
                        width: Theme.paddingSmall
                        height: Theme.paddingSmall
                        anchors {
                            top: parent.top
                            topMargin: Theme.paddingMedium
                            right: model.role === "user" ? parent.right : undefined
                            rightMargin: model.role === "user" ? -width + 1 : 0
                            left: model.role === "assistant" ? parent.left : undefined
                            leftMargin: model.role === "assistant" ? -width + 1 : 0
                        }

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.fillStyle = bubbleBackground.color

                            if (model.role === "user") {
                                // Triangle pointing right
                                ctx.moveTo(0, 0)
                                ctx.lineTo(width, height / 2)
                                ctx.lineTo(0, height)
                            } else {
                                // Triangle pointing left
                                ctx.moveTo(width, 0)
                                ctx.lineTo(0, height / 2)
                                ctx.lineTo(width, height)
                            }
                            ctx.closePath()
                            ctx.fill()
                        }
                    }

                    Label {
                        id: messageText
                        anchors {
                            fill: parent
                            margins: Theme.paddingMedium
                        }
                        text: model.content
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                        color: model.role === "user" ? Theme.primaryColor : Theme.primaryColor
                    }
                }
            }
        }

        VerticalScrollDecorator {}

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
    }

    // Footer with input area
    Item {
        id: inputArea
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: inputColumn.height

        // Error banner
        Rectangle {
            id: errorBanner
            anchors {
                left: parent.left
                right: parent.right
                bottom: inputColumn.top
            }
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
                icon.source: "image://theme/icon-s-clear"
                onClicked: mistralApi.clearError()
            }
        }

        Column {
            id: inputColumn
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            spacing: 0

            Separator {
                width: parent.width
                color: Theme.highlightColor
                opacity: 0.3
            }

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
                        placeholderText: qsTr("Type a message...")
                        labelVisible: false
                        enabled: !mistralApi.isBusy && settingsManager.hasApiKey()

                        font.pixelSize: Theme.fontSizeSmall

                        // Limit height to 5 lines max
                        property int maxLines: 5
                        height: Math.min(implicitHeight, Theme.itemSizeSmall * maxLines / 2)

                        EnterKey.enabled: text.trim().length > 0 && !mistralApi.isBusy
                        EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                        EnterKey.onClicked: {
                            sendMessage()
                        }
                    }

                    IconButton {
                        id: sendButton
                        anchors.verticalCenter: parent.verticalCenter
                        icon.source: mistralApi.isBusy
                            ? "image://theme/icon-m-pause"
                            : "image://theme/icon-m-message"
                        icon.color: (!mistralApi.isBusy && messageInput.text.trim().length > 0)
                            ? Theme.highlightColor
                            : Theme.primaryColor
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

        // New conversation button at the bottom
        IconButton {
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: Theme.paddingLarge
            }
            icon.source: "image://theme/icon-m-add"
            icon.color: Theme.highlightColor
            onClicked: {
                conversationManager.createNewConversation()
                conversationPanel.hide()
                streamingContent = ""
            }
        }
    }

    // Show first use dialog
    Component.onCompleted: {
        refreshConversationsList()
        if (firstUse) {
            firstUseDialog.open()
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
                    source: "image://theme/icon-l-chat"
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
            messageListView.positionViewAtBeginning()
            conversationManager.saveCurrentConversation()
        }
    }

    function sendMessage() {
        var message = messageInput.text.trim()
        if (message.length === 0) {
            return
        }

        if (!settingsManager.hasApiKey()) {
            pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            return
        }

        // Clear input immediately
        messageInput.text = ""

        // Add user message
        conversationModel.addUserMessage(message)

        // Prepare API call
        var apiKey = settingsManager.apiKey
        var modelName = settingsManager.modelName
        var messages = conversationModel.toJsonArray()

        // Add empty assistant message
        conversationModel.addAssistantMessage("")

        // Send to API
        mistralApi.sendMessage(apiKey, modelName, messages)

        // Scroll to bottom
        messageListView.positionViewAtBeginning()
    }

    function refreshConversationsList() {
        conversationsListModel.clear()
        var conversations = conversationManager.getConversationsList()
        for (var i = 0; i < conversations.length; i++) {
            conversationsListModel.append(conversations[i])
        }
    }
}
