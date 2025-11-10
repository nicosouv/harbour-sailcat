import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: conversationListPage
    allowedOrientations: Orientation.All

    SilicaListView {
        id: listView
        anchors.fill: parent

        PullDownMenu {
            MenuItem {
                text: qsTr("New conversation")
                onClicked: {
                    conversationManager.createNewConversation()
                    pageStack.pop()
                }
            }
        }

        header: PageHeader {
            title: qsTr("Conversations")
        }

        model: ListModel {
            id: conversationsModel
        }

        delegate: ListItem {
            id: listItem
            contentHeight: Theme.itemSizeLarge

            menu: ContextMenu {
                MenuItem {
                    text: qsTr("Delete")
                    onClicked: {
                        remorseAction(qsTr("Deleting"), function() {
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
                    text: model.title
                    color: listItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                    font.pixelSize: Theme.fontSizeMedium
                    truncationMode: TruncationMode.Fade
                }

                Row {
                    width: parent.width
                    spacing: Theme.paddingMedium

                    Label {
                        text: Qt.formatDateTime(new Date(model.updatedAt), "dd/MM/yyyy hh:mm")
                        color: listItem.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }

                    Label {
                        text: "•"
                        color: listItem.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }

                    Label {
                        text: qsTr("%n message(s)", "", model.messageCount)
                        color: listItem.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }
                }
            }

            onClicked: {
                conversationManager.loadConversation(model.id)
                pageStack.pop()
            }
        }

        ViewPlaceholder {
            enabled: listView.count === 0
            text: qsTr("No conversations")
            hintText: qsTr("Create a new conversation using the menu")
        }

        VerticalScrollDecorator {}
    }

    Component.onCompleted: {
        refreshList()
    }

    function refreshList() {
        conversationsModel.clear()
        var conversations = conversationManager.getConversationsList()
        for (var i = 0; i < conversations.length; i++) {
            conversationsModel.append(conversations[i])
        }
    }
}
