import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: historyPage
    allowedOrientations: Orientation.All

    property string storageSize: conversationManager.getStorageSizeFormatted()

    SilicaListView {
        id: conversationsList
        anchors.fill: parent

        header: Column {
            width: parent.width
            spacing: 0

            PageHeader {
                title: qsTr("Conversation History")
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
                pageStack.push(Qt.resolvedUrl("ConversationDetailPage.qml"), {
                    conversationId: model.id
                })
            }

            menu: ContextMenu {
                MenuItem {
                    text: qsTr("Load")
                    onClicked: {
                        conversationManager.loadConversation(model.id)
                        pageStack.pop()
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
            text: qsTr("No conversations")
            hintText: qsTr("Start chatting to create conversations")
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
}
