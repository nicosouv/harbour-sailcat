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
    property int maxMessages: 1

    SilicaListView {
        id: conversationsList
        anchors.fill: parent

        header: Column {
            width: parent.width
            spacing: 0

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

            // Storage info section
            BackgroundItem {
                width: parent.width
                height: storageInfoColumn.height + Theme.paddingLarge * 2

                Column {
                    id: storageInfoColumn
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: Theme.horizontalPageMargin
                        rightMargin: Theme.horizontalPageMargin
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Theme.paddingSmall

                    Label {
                        text: qsTr("Storage used: %1").arg(storageSize)
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.secondaryColor
                    }

                    Label {
                        text: qsTr("%n conversation(s)", "", conversationManager.conversationCount)
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                    }
                }
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
                width: parent.width
                color: Theme.highlightColor
            }
        }

        model: ListModel {
            id: conversationsListModel
        }

        delegate: ListItem {
            id: conversationItem
            contentHeight: Theme.itemSizeLarge

            onClicked: {
                conversationManager.loadConversation(model.id)
                // navigateBack works both when this page is attached (swipe) and when pushed
                pageStack.navigateBack()
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
                    text: model.title || qsTr("Empty conversation")
                    color: conversationItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                    font.pixelSize: Theme.fontSizeMedium
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

                // Conversation size relative to the biggest one
                Rectangle {
                    width: parent.width
                    height: Math.max(3, Theme.paddingSmall / 3)
                    radius: height / 2
                    color: Theme.rgba(Theme.secondaryHighlightColor, 0.3)
                    visible: (model.messageCount || 0) > 0

                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        color: Theme.highlightColor
                        width: parent.width * ((model.messageCount || 0) / Math.max(1, historyPage.maxMessages))

                        Behavior on width {
                            NumberAnimation { duration: 450; easing.type: Easing.OutQuad }
                        }
                    }
                }

                Row {
                    spacing: Theme.paddingMedium

                    CategoryChip {
                        category: model.category || ""
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Label {
                        text: Qt.formatDateTime(new Date(model.updatedAt), "dd/MM/yyyy hh:mm")
                        anchors.verticalCenter: parent.verticalCenter
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

                    Label {
                        text: "•"
                        visible: searchQuery.length > 0 && model.matchCount > 0
                        color: conversationItem.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }

                    Label {
                        text: qsTr("%n match(es)", "", model.matchCount || 0)
                        visible: searchQuery.length > 0 && model.matchCount > 0
                        color: conversationItem.highlighted ? Theme.highlightColor : Theme.highlightColor
                        font.pixelSize: Theme.fontSizeExtraSmall
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
            MenuItem {
                text: qsTr("Settings & About")
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: qsTr("Pinned messages")
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("PinnedMessagesPage.qml"), {
                        chatPage: pageStack.find(function(page) {
                            return page.objectName === "chatPage"
                        })
                    })
                }
            }
            MenuItem {
                text: qsTr("New conversation")
                onClicked: {
                    conversationManager.createNewConversation()
                    pageStack.navigateBack()
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

    Component.onCompleted: {
        refreshList()
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

        var maxMsg = 1
        for (var k = 0; k < conversations.length; k++) {
            if (conversations[k].messageCount > maxMsg) maxMsg = conversations[k].messageCount
        }
        maxMessages = maxMsg
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
