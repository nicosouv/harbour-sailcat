import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import Nemo.Notifications 1.0
import "../components"

Page {
    id: chatPage
    objectName: "chatPage"
    allowedOrientations: Orientation.All

    property bool firstUse: false
    property string streamingContent: ""
    property bool streamPending: false
    property bool autoScroll: true
    property int lastPromptTokens: 0
    property int lastCompletionTokens: 0
    property int conversationTokens: 0
    property int pendingScrollIndex: -1
    property string attachedImagePath: ""
    property bool titleRequested: false
    property string lastUsedModel: ""
    property int trimmedMessages: 0

    // Mirrors of the per-conversation overrides. Kept as properties rather
    // than read on demand so bindings actually re-evaluate when they change.
    property string conversationModelOverride: ""
    property string conversationPromptOverride: ""

    // A one-shot model chosen for the next message wins over the
    // per-conversation override, which wins over the global setting.
    readonly property string activeModel:
        settingsManager.nextMessageModel !== "" ? settingsManager.nextMessageModel
        : (conversationModelOverride !== "" ? conversationModelOverride
                                            : settingsManager.modelName)

    onStatusChanged: {
        if (status === PageStatus.Active) {
            // Conversation history reachable by swiping forward
            if (pageStack.nextPage(chatPage) === null) {
                pageStack.pushAttached(Qt.resolvedUrl("ConversationHistoryPage.qml"))
            }
            // Jump requested from the pinned messages page
            if (pendingScrollIndex >= 0) {
                autoScroll = false
                messageListView.positionViewAtIndex(pendingScrollIndex, ListView.Center)
                pendingScrollIndex = -1
            }
            chatPage.refreshOverrides()
            chatPage.refreshTrimIndicator()
        }
    }

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
        spacing: settingsManager.chatStyle === "compact" ? Theme.paddingSmall
                                                         : Theme.paddingMedium

        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 300; easing.type: Easing.OutQuad }
                NumberAnimation { property: "scale"; from: 0.92; to: 1; duration: 300; easing.type: Easing.OutBack }
            }
        }

        // Stop following the stream when the user scrolls away,
        // resume when they come back to the bottom
        onMovementStarted: chatPage.autoScroll = false
        onMovementEnded: chatPage.autoScroll = messageListView.atYEnd

        header: PageHeader {
            title: "SailCat"
            // A trailing asterisk marks a model pinned to this conversation
            description: chatPage.conversationModelOverride !== ""
                         ? chatPage.activeModel + " *" : chatPage.activeModel
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Conversation History")
                onClicked: chatPage.openHistory()
            }
            MenuItem {
                text: qsTr("Pinned messages")
                onClicked: chatPage.openPinned()
            }
            MenuItem {
                text: qsTr("Prompt library")
                onClicked: chatPage.openPromptLibrary()
            }
            MenuItem {
                text: qsTr("Conversation settings")
                onClicked: chatPage.openConversationSettings()
            }
            MenuItem {
                text: qsTr("Settings & About")
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: qsTr("Export conversation")
                enabled: conversationModel.count > 0
                onClicked: chatPage.exportCurrentConversation()
            }
            MenuItem {
                text: qsTr("New conversation")
                enabled: conversationModel.count > 0
                onClicked: chatPage.startNewConversation()
            }
        }

        // Same actions as the top pulley, reachable from the bottom of the conversation
        PushUpMenu {
            MenuItem {
                text: qsTr("Conversation History")
                onClicked: chatPage.openHistory()
            }
            MenuItem {
                text: qsTr("Pinned messages")
                onClicked: chatPage.openPinned()
            }
            MenuItem {
                text: qsTr("Prompt library")
                onClicked: chatPage.openPromptLibrary()
            }
            MenuItem {
                text: qsTr("Conversation settings")
                onClicked: chatPage.openConversationSettings()
            }
            MenuItem {
                text: qsTr("Settings & About")
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: qsTr("Export conversation")
                enabled: conversationModel.count > 0
                onClicked: chatPage.exportCurrentConversation()
            }
            MenuItem {
                text: qsTr("New conversation")
                enabled: conversationModel.count > 0
                onClicked: chatPage.startNewConversation()
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
            isLast: index === messageListView.count - 1
            pinned: model.pinned
            timestamp: model.timestamp
            imagePath: model.imagePath

            onRegenerateRequested: chatPage.regenerateLastResponse()
            onEditRequested: chatPage.editMessage(index, model.content)
            onPinToggled: {
                conversationModel.togglePinned(index)
                conversationManager.saveCurrentConversation()
            }
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

        // Attached image preview
        Item {
            width: parent.width
            height: chatPage.attachedImagePath !== "" ? Theme.itemSizeMedium + Theme.paddingMedium : 0
            visible: height > 0
            clip: true

            Behavior on height { NumberAnimation { duration: 200 } }

            Image {
                id: attachPreview
                source: chatPage.attachedImagePath
                height: Theme.itemSizeMedium
                width: Theme.itemSizeMedium * 1.5
                anchors {
                    left: parent.left
                    leftMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 256
            }

            IconButton {
                anchors {
                    left: attachPreview.right
                    leftMargin: Theme.paddingMedium
                    verticalCenter: parent.verticalCenter
                }
                icon.source: "image://theme/icon-m-clear"
                onClicked: chatPage.attachedImagePath = ""
            }
        }

        // Trimmed context notice
        Item {
            width: parent.width
            height: visible ? trimLabel.height + Theme.paddingSmall : 0
            visible: chatPage.trimmedMessages > 0

            Label {
                id: trimLabel
                anchors.centerIn: parent
                text: qsTr("Context limited: %n older message(s) not sent", "",
                           chatPage.trimmedMessages)
                font.pixelSize: Theme.fontSizeTiny
                color: Theme.secondaryColor
            }
        }

        // Token usage banner
        Item {
            width: parent.width
            height: visible ? tokenLabel.height + Theme.paddingSmall : 0
            visible: chatPage.conversationTokens > 0

            Label {
                id: tokenLabel
                anchors.centerIn: parent
                text: chatPage.lastCompletionTokens > 0
                      ? qsTr("Tokens: %1 total - last: %2 in / %3 out")
                            .arg(chatPage.conversationTokens)
                            .arg(chatPage.lastPromptTokens)
                            .arg(chatPage.lastCompletionTokens)
                      : qsTr("Tokens: %1 total").arg(chatPage.conversationTokens)
                font.pixelSize: Theme.fontSizeTiny
                color: Theme.secondaryColor
            }
        }

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
                    right: retryErrorButton.left
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
                id: retryErrorButton
                anchors {
                    right: closeErrorButton.left
                    verticalCenter: parent.verticalCenter
                }
                icon.source: "image://theme/icon-m-refresh"
                enabled: !mistralApi.isBusy && conversationModel.count > 0
                onClicked: chatPage.retryLastRequest()
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

        // Separator with a scanning light while a response is streaming
        Item {
            id: separatorArea
            width: parent.width
            height: Theme.paddingSmall

            Separator {
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.highlightColor
                opacity: 0.3
            }

            Rectangle {
                id: scanGlow
                visible: mistralApi.isBusy
                width: separatorArea.width / 3
                height: Theme.paddingSmall / 2
                radius: height / 2
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.highlightColor
                opacity: 0.25
                x: scanLine.x - (width - scanLine.width) / 2
            }

            Rectangle {
                id: scanLine
                visible: mistralApi.isBusy
                width: separatorArea.width / 5
                height: 2
                radius: 1
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.highlightColor

                SequentialAnimation on x {
                    running: mistralApi.isBusy
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: -scanLine.width
                        to: separatorArea.width
                        duration: 1100
                        easing.type: Easing.InOutQuad
                    }
                }
            }
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

                // Quick model switcher
                IconButton {
                    id: modelButton
                    anchors.verticalCenter: parent.verticalCenter
                    icon.source: "image://theme/icon-m-levels"
                    onClicked: pageStack.push(modelSelector)
                }

                // Image attachment (vision models only)
                IconButton {
                    id: attachButton
                    anchors.verticalCenter: parent.verticalCenter
                    visible: settingsManager.isVisionModel(chatPage.activeModel)
                    icon.source: "image://theme/icon-m-attach"
                    icon.highlighted: chatPage.attachedImagePath !== ""
                    onClicked: {
                        if (chatPage.attachedImagePath !== "") {
                            chatPage.attachedImagePath = ""
                        } else {
                            pageStack.push(imagePickerComponent)
                        }
                    }
                }

                TextArea {
                    id: messageInput
                    width: parent.width - modelButton.width - sendButton.width - parent.spacing * 2
                           - (attachButton.visible ? attachButton.width + parent.spacing : 0)
                    height: Math.min(implicitHeight, Theme.itemSizeSmall * 2.5)
                    placeholderText: qsTr("Type a message...")
                    labelVisible: false
                    enabled: !mistralApi.isBusy && settingsManager.hasApiKey
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
                    enabled: (!mistralApi.isBusy && messageInput.text.trim().length > 0 && settingsManager.hasApiKey) || mistralApi.isBusy

                    // Pulsing halo while a request is in flight
                    Rectangle {
                        id: busyHalo
                        anchors.centerIn: parent
                        width: parent.width
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.color: Theme.highlightColor
                        border.width: 2
                        visible: mistralApi.isBusy
                        z: -1

                        ParallelAnimation {
                            running: mistralApi.isBusy
                            loops: Animation.Infinite

                            NumberAnimation {
                                target: busyHalo
                                property: "scale"
                                from: 0.6
                                to: 1.25
                                duration: 900
                                easing.type: Easing.OutQuad
                            }
                            NumberAnimation {
                                target: busyHalo
                                property: "opacity"
                                from: 0.7
                                to: 0
                                duration: 900
                            }
                        }
                    }

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

    // Repainting the whole message on every SSE delta is what makes long
    // answers stutter: coalesce the deltas and update at a fixed cadence.
    Timer {
        id: streamFlushTimer
        interval: 90
        repeat: true
        running: mistralApi.isBusy
        onTriggered: chatPage.flushStream()
    }

    // First launch dialog
    Dialog {
        id: firstLaunchDialog
        allowedOrientations: Orientation.All
        canAccept: true
        onAccepted: settingsManager.setFirstLaunchComplete()

        SilicaFlickable {
            anchors.fill: parent
            contentHeight: column.height

            Column {
                id: column
                width: parent.width
                spacing: Theme.paddingLarge

                DialogHeader {
                    title: qsTr("Welcome to SailCat")
                    acceptText: qsTr("Get Started")
                }

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: "image://theme/icon-l-message"
                    width: Theme.iconSizeExtraLarge
                    height: Theme.iconSizeExtraLarge
                    color: Theme.highlightColor
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "SailCat"
                    font.pixelSize: Theme.fontSizeHuge
                    color: Theme.highlightColor
                }

                SectionHeader {
                    text: qsTr("What is Mistral AI?")
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: qsTr("Mistral AI is a European AI company providing state-of-the-art language models. SailCat uses their API to bring intelligent conversations to Sailfish OS.")
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                SectionHeader {
                    text: qsTr("Privacy & Storage")
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: qsTr("• Your conversations are stored locally on your device\n• No sync with Mistral's web interface\n• You need your own API key to use the app\n• Your data stays on your phone")
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                SectionHeader {
                    text: qsTr("Getting Started")
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: qsTr("1. Get a free API key from console.mistral.ai\n2. Configure it in Settings\n3. Start chatting!")
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                Item {
                    width: parent.width
                    height: Theme.paddingLarge
                }
            }
        }
    }

    Notification {
        id: exportNotification
        appName: "SailCat"
    }

    Component {
        id: imagePickerComponent

        ImagePickerPage {
            onSelectedContentPropertiesChanged: {
                // Keep our own downscaled copy: the gallery original can be
                // deleted, and the conversation still needs the picture.
                chatPage.attachedImagePath =
                    conversationManager.retainImage(selectedContentProperties.filePath)
            }
        }
    }

    // Connections to API
    Connections {
        target: mistralApi

        onStreamingResponse: {
            chatPage.streamingContent += content
            chatPage.streamPending = true
        }

        onMessageSent: {
            chatPage.streamingContent = ""
            chatPage.streamPending = false
            // Added only once the request is actually in flight, so a rejected
            // send never leaves an empty assistant bubble behind.
            conversationModel.addAssistantMessage("")
            messageListView.positionViewAtEnd()
        }

        onUsageReceived: {
            conversationManager.addTokenUsage(promptTokens, completionTokens,
                                              chatPage.lastUsedModel)
            chatPage.lastPromptTokens = promptTokens
            chatPage.lastCompletionTokens = completionTokens
            chatPage.conversationTokens += promptTokens + completionTokens
        }

        onSideRequestUsage: {
            // Title generation is billed too, but it is not part of what the
            // conversation banner reports.
            conversationManager.addTokenUsage(promptTokens, completionTokens,
                                              chatPage.lastUsedModel)
        }

        onResponseCompleted: {
            chatPage.flushStream()
            chatPage.streamingContent = ""

            // Drop the empty assistant bubble left behind by an error or cancel
            conversationModel.removeLastMessageIfEmpty()

            if (chatPage.autoScroll) {
                messageListView.positionViewAtEnd()
            }
            conversationManager.saveCurrentConversation()
            chatPage.refreshTrimIndicator()

            // Generate title after the first exchange, once per conversation
            if (!chatPage.titleRequested && conversationModel.count === 2) {
                var firstMessage = conversationModel.getFirstUserMessage()
                if (firstMessage) {
                    chatPage.titleRequested = true
                    mistralApi.generateTitle(settingsManager.apiKey,
                                             chatPage.activeModel, firstMessage)
                }
            }
        }

        onTitleGenerated: {
            conversationManager.updateCurrentConversationTitle(title)
            conversationManager.updateCurrentConversationCategory(category)
        }
    }

    Connections {
        target: settingsManager

        onApiKeyChanged: {
            firstUse = !settingsManager.hasApiKey
        }

        onContextMessageLimitChanged: chatPage.refreshTrimIndicator()
    }

    Connections {
        target: conversationManager

        onCurrentConversationChanged: {
            chatPage.lastPromptTokens = 0
            chatPage.lastCompletionTokens = 0
            chatPage.titleRequested = false
            // Restore the running total instead of showing 0 for a
            // conversation that already cost something.
            var stats = conversationManager.getConversationStatistics(
                            conversationManager.currentConversationId())
            chatPage.conversationTokens = stats.totalTokens || 0
            chatPage.refreshOverrides()
            chatPage.refreshTrimIndicator()
        }
    }

    Component.onCompleted: {
        firstUse = !settingsManager.hasApiKey

        var stats = conversationManager.getConversationStatistics(
                        conversationManager.currentConversationId())
        conversationTokens = stats.totalTokens || 0
        refreshOverrides()
        refreshTrimIndicator()

        // Show first launch dialog after a short delay to let PageStack settle
        if (settingsManager.isFirstLaunch()) {
            firstLaunchTimer.start()
        }
    }

    Timer {
        id: firstLaunchTimer
        interval: 500
        repeat: false
        onTriggered: firstLaunchDialog.open()
    }

    function flushStream() {
        if (!streamPending) return
        streamPending = false
        conversationModel.updateLastAssistantMessage(streamingContent)
        if (autoScroll) {
            messageListView.positionViewAtEnd()
        }
    }

    function refreshOverrides() {
        var overrides = conversationManager.getConversationOverrides(
                            conversationManager.currentConversationId())
        conversationModelOverride = overrides.model || ""
        conversationPromptOverride = overrides.systemPrompt || ""
    }

    function effectiveSystemPrompt() {
        return conversationPromptOverride !== "" ? conversationPromptOverride
                                                 : settingsManager.systemPrompt
    }

    function refreshTrimIndicator() {
        trimmedMessages = conversationManager.trimmedMessageCount(
                    settingsManager.contextMessageLimit)
    }

    function dispatchRequest() {
        var messages = conversationManager.buildApiMessages(
                    settingsManager.contextMessageLimit, effectiveSystemPrompt())
        if (messages.length === 0) {
            return
        }

        lastUsedModel = activeModel
        autoScroll = true

        mistralApi.sendMessage(settingsManager.apiKey, lastUsedModel, messages,
                               settingsManager.temperature, settingsManager.maxTokens)

        // Reset next message model after sending
        settingsManager.resetNextMessageModel()
        refreshTrimIndicator()
    }

    function sendMessage() {
        var message = messageInput.text.trim()
        if (message.length === 0) return

        if (!settingsManager.hasApiKey) {
            pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            return
        }

        var imagePath = attachedImagePath
        attachedImagePath = ""

        messageInput.text = ""
        messageInput.focus = false
        conversationModel.addUserMessage(message, imagePath)

        // Persist before the round trip: losing the question because the app
        // was closed mid-answer is worse than losing the answer.
        conversationManager.saveCurrentConversation()

        dispatchRequest()
    }

    function retryLastRequest() {
        if (mistralApi.isBusy) return

        mistralApi.clearError()
        conversationModel.removeLastMessageIfEmpty()
        dispatchRequest()
    }

    function editMessage(index, content) {
        if (mistralApi.isBusy) return

        conversationModel.truncateFrom(index)
        // Save immediately so a close before resending does not restore the removed tail
        conversationManager.saveCurrentConversation()
        messageInput.text = content
        messageInput.focus = true
        refreshTrimIndicator()
    }

    function insertPrompt(text) {
        if (!text) return
        messageInput.text = messageInput.text.length > 0
                ? messageInput.text + "\n" + text
                : text
        messageInput.focus = true
    }

    function startNewConversation() {
        conversationManager.createNewConversation()
        streamingContent = ""
        streamPending = false
    }

    function openHistory() {
        if (pageStack.nextPage(chatPage) !== null) {
            pageStack.navigateForward()
        } else {
            pageStack.push(Qt.resolvedUrl("ConversationHistoryPage.qml"))
        }
    }

    function openPinned() {
        conversationManager.saveCurrentConversation()
        pageStack.push(Qt.resolvedUrl("PinnedMessagesPage.qml"), { chatPage: chatPage })
    }

    function openPromptLibrary() {
        pageStack.push(Qt.resolvedUrl("PromptLibraryPage.qml"), { chatPage: chatPage })
    }

    function openConversationSettings() {
        conversationManager.saveCurrentConversation()
        pageStack.push(Qt.resolvedUrl("ConversationSettingsPage.qml"), {
            conversationId: conversationManager.currentConversationId()
        })
    }

    function exportCurrentConversation() {
        var path = conversationManager.exportConversation(conversationManager.currentConversationId())
        if (path !== "") {
            exportNotification.previewSummary = qsTr("Conversation exported")
            exportNotification.previewBody = path
        } else {
            exportNotification.previewSummary = qsTr("Export failed")
            exportNotification.previewBody = ""
        }
        exportNotification.publish()
    }

    function regenerateLastResponse() {
        if (mistralApi.isBusy) return

        conversationModel.removeLastAssistantMessage()
        dispatchRequest()
    }

    ModelSelector {
        id: modelSelector

        onModelSelected: function(selectedModel) {
            settingsManager.modelName = selectedModel
            exportNotification.previewSummary = qsTr("Model changed to %1").arg(selectedModel)
            exportNotification.previewBody = ""
            exportNotification.publish()
        }
    }
}
