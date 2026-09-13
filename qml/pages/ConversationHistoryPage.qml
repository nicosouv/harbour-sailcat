import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Notifications 1.0
import "../components"

Page {
    id: historyPage
    allowedOrientations: Orientation.All

    property string storageSize: conversationManager.getStorageSizeFormatted()
    property string searchQuery: ""
    property var dayCounts: []
    property int maxDayCount: 0

    SilicaListView {
        id: conversationsList
        anchors.fill: parent

        header: Column {
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("Conversation History")
            }

            SearchField {
                id: searchField
                width: parent.width
                placeholderText: qsTr("Search in conversations...")

                onTextChanged: {
                    searchQuery = text
                    searchTimer.restart()
                }

                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }

            Timer {
                id: searchTimer
                interval: 300
                onTriggered: performSearch()
            }

            // Count and storage on one line: two labels for six words was a
            // paragraph where a caption does.
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("%n conversation(s)", "", conversationManager.conversationCount)
                      + "  ·  " + storageSize
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                truncationMode: TruncationMode.Fade
            }

            // 14-day activity chart with staggered grow-in
            Column {
                width: parent.width
                spacing: Theme.paddingSmall
                visible: historyPage.maxDayCount > 0

                Row {
                    id: historyChart
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    height: Theme.itemSizeSmall
                    spacing: Theme.paddingSmall / 2

                    Repeater {
                        model: historyPage.dayCounts

                        Item {
                            width: (historyChart.width - historyChart.spacing * 13) / 14
                            height: historyChart.height

                            Rectangle {
                                id: historyBar
                                anchors.bottom: parent.bottom
                                width: parent.width
                                radius: 2
                                height: 4
                                color: modelData > 0
                                       ? Theme.rgba(Theme.highlightColor,
                                                    0.4 + 0.6 * modelData / historyPage.maxDayCount)
                                       : Theme.rgba(Theme.secondaryColor, 0.2)

                                property real targetHeight: historyPage.maxDayCount > 0 && modelData > 0
                                        ? Math.max(6, parent.height * modelData / historyPage.maxDayCount)
                                        : 4

                                SequentialAnimation {
                                    running: true
                                    PauseAnimation { duration: index * 40 }
                                    NumberAnimation {
                                        target: historyBar
                                        property: "height"
                                        to: historyBar.targetHeight
                                        duration: 350
                                        easing.type: Easing.OutBack
                                    }
                                }
                            }
                        }
                    }
                }

                Label {
                    x: Theme.horizontalPageMargin
                    text: qsTr("Activity - last 14 days")
                    font.pixelSize: Theme.fontSizeTiny
                    color: Theme.secondaryColor
                }
            }

            Separator {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                color: Theme.rgba(Theme.highlightColor, 0.4)
            }

            // Keeps the first row off the separator. Column has no padding in
            // the Qt version Sailfish ships.
            Item {
                width: 1
                height: Theme.paddingSmall
            }
        }

        model: ListModel {
            id: conversationsListModel
        }

        delegate: ListItem {
            id: conversationItem
            // Grows with its content instead of squeezing four lines into a
            // fixed height: these rows carry a lot more than they used to.
            contentHeight: rowContent.height + 2 * Theme.paddingLarge

            onClicked: {
                conversationManager.loadConversation(model.id)
                historyPage.openChat()
            }

            menu: ContextMenu {
                MenuItem {
                    text: qsTr("View details")
                    onClicked: {
                        pageStack.push(Qt.resolvedUrl("ConversationDetailPage.qml"), {
                            conversationId: model.id
                        })
                    }
                }
                MenuItem {
                    text: qsTr("Conversation settings")
                    onClicked: {
                        pageStack.push(Qt.resolvedUrl("ConversationSettingsPage.qml"), {
                            conversationId: model.id
                        })
                    }
                }
                MenuItem {
                    text: qsTr("Copy as text")
                    onClicked: {
                        Clipboard.text = conversationManager.conversationToMarkdown(model.id)
                    }
                }
                MenuItem {
                    text: qsTr("Delete")
                    onClicked: {
                        conversationItem.remorseAction(qsTr("Deleting"), function() {
                            conversationManager.deleteConversation(model.id)
                            refreshList()
                        })
                    }
                }
            }

            Row {
                id: rowContent
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: Theme.horizontalPageMargin
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                spacing: Theme.paddingMedium

                // Carries the provider, the streaming pulse and the unread
                // light at once, which frees the title line.
                ProviderBadge {
                    id: providerBadge
                    anchors.verticalCenter: parent.verticalCenter
                    provider: model.provider || ""
                    streaming: model.id === conversationManager.streamingConversationId
                    unread: model.unread ? true : false
                }

                Column {
                    width: parent.width - providerBadge.width - parent.spacing
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: model.title || qsTr("Empty conversation")
                        color: conversationItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: providerBadge.streaming || providerBadge.unread
                        truncationMode: TruncationMode.Fade
                    }

                    // Show match preview when searching
                    Loader {
                        width: parent.width
                        active: searchQuery.length > 0 && (model.matchPreview ? true : false)
                        sourceComponent: Label {
                            width: parent.width
                            text: model.matchPreview || ""
                            color: conversationItem.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium

                        CategoryChip {
                            id: categoryChip
                            category: model.category || ""
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Date and size in one label rather than three items
                        // separated by bullets of their own.
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - (categoryChip.visible
                                                   ? categoryChip.width + parent.spacing : 0)
                                   - (matchLabel.visible
                                      ? matchLabel.width + parent.spacing : 0)
                            text: historyPage.formatWhen(model.updatedAt) + "  ·  "
                                  + qsTr("%n message(s)", "", model.messageCount)
                            color: conversationItem.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                            truncationMode: TruncationMode.Fade
                        }

                        Label {
                            id: matchLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("%n match(es)", "", model.matchCount || 0)
                            visible: searchQuery.length > 0 && model.matchCount > 0
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }

                    // Who answers here. The badge already says which provider,
                    // so this line is mostly about the model.
                    Label {
                        width: parent.width
                        text: {
                            var provider = model.provider || ""
                            if (provider === "") {
                                return ""
                            }
                            var name = settingsManager.providerNameFor(provider)
                            var used = model.lastModel || ""
                            return used === "" ? name : name + " · " + used
                        }
                        visible: text !== ""
                        color: conversationItem.highlighted ? Theme.secondaryHighlightColor
                                                            : Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeTiny
                        opacity: 0.8
                        truncationMode: TruncationMode.Fade
                    }
                }
            }
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Purge all conversations")
                onClicked: {
                    remorse.execute(qsTr("Purging all conversations"), function() {
                        conversationManager.purgeAllConversations()
                        refreshList()
                    })
                }
            }
            MenuItem {
                text: qsTr("Auto-label conversations")
                onClicked: {
                    var count = conversationManager.recategorizeConversations()
                    exportNotification.previewSummary = count > 0
                        ? qsTr("%n conversation(s) relabelled", "", count)
                        : qsTr("Nothing to relabel")
                    exportNotification.previewBody = ""
                    exportNotification.publish()
                    refreshList()
                }
            }
            // This page is the root: without an entry here the settings are
            // only reachable from inside a conversation.
            MenuItem {
                text: qsTr("Settings & About")
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: qsTr("New conversation")
                onClicked: {
                    conversationManager.createNewConversation()
                    historyPage.openChat()
                }
            }
        }

        ViewPlaceholder {
            enabled: conversationsListModel.count === 0
            text: searchQuery.length > 0 ? qsTr("No results") : qsTr("No conversations")
            hintText: searchQuery.length > 0 ? qsTr("Try different search terms") : qsTr("Start chatting to create conversations")
        }

        VerticalScrollDecorator {}
    }

    RemorsePopup {
        id: remorse
    }

    Notification {
        id: exportNotification
        appName: "SailCat"
    }

    Connections {
        target: conversationManager

        // An answer that finished while the user was sitting here changes the
        // message count and lights the unread dot.
        onResponseFinished: {
            if (historyPage.searchQuery.length === 0) {
                historyPage.refreshList()
            }
        }
    }

    Component.onCompleted: {
        refreshList()
    }

    // This page is the root of the stack; the chat lives on top of it and is
    // popped whenever the user swipes back here, so it has to be pushed again.
    function openChat() {
        pageStack.push(Qt.resolvedUrl("ChatPage.qml"))
    }

    // Refresh when returning to the page (it stays alive as an attached page)
    onStatusChanged: {
        if (status === PageStatus.Activating) {
            refreshList()
        }
    }

    function refreshList() {
        conversationsListModel.clear()
        var conversations = conversationManager.getConversationsList()
        for (var i = 0; i < conversations.length; i++) {
            conversationsListModel.append(conversations[i])
        }
        storageSize = conversationManager.getStorageSizeFormatted()

        var stats = conversationManager.getStatistics()
        dayCounts = stats.messagesPerDay || []
        var max = 0
        for (var j = 0; j < dayCounts.length; j++) {
            if (dayCounts[j] > max) max = dayCounts[j]
        }
        maxDayCount = max
    }

    // Short and relative: on this page the exact minute of a month-old
    // conversation is noise, "12/08" is not.
    function formatWhen(timestamp) {
        var date = new Date(timestamp)
        var now = new Date()

        if (date.toDateString() === now.toDateString()) {
            return Qt.formatDateTime(date, "hh:mm")
        }
        var yesterday = new Date(now.getTime() - 24 * 3600 * 1000)
        if (date.toDateString() === yesterday.toDateString()) {
            return qsTr("Yesterday")
        }
        if (date.getFullYear() === now.getFullYear()) {
            return Qt.formatDateTime(date, "dd/MM")
        }
        return Qt.formatDateTime(date, "dd/MM/yyyy")
    }

    function performSearch() {
        conversationsListModel.clear()

        if (searchQuery.trim().length === 0) {
            // No search query, show all conversations
            refreshList()
            return
        }

        // Perform search
        var results = conversationManager.searchConversations(searchQuery)
        for (var i = 0; i < results.length; i++) {
            conversationsListModel.append(results[i])
        }
    }
}
