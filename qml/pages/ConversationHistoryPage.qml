import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: historyPage
    allowedOrientations: Orientation.All

    property string storageSize: conversationManager.getStorageSizeFormatted()
    property string searchQuery: ""

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
                pageStack.pop()
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

                Row {
                    spacing: Theme.paddingMedium

                    Label {
                        text: Qt.formatDateTime(new Date(model.updatedAt), "dd/MM/yyyy hh:mm")
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

    Component.onCompleted: {
        refreshList()
    }

    function refreshList() {
        conversationsListModel.clear()
        var conversations = conversationManager.getConversationsList()
        for (var i = 0; i < conversations.length; i++) {
            conversationsListModel.append(conversations[i])
        }
        storageSize = conversationManager.getStorageSizeFormatted()
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
