import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"

Page {
    id: detailPage
    allowedOrientations: Orientation.All

    property string conversationId: ""
    property var conversationDetails: ({})

    SilicaListView {
        id: messagesList
        anchors.fill: parent

        header: PageHeader {
            title: conversationDetails.title || qsTr("Conversation")
            description: Qt.formatDateTime(new Date(conversationDetails.updatedAt || 0), "dd/MM/yyyy hh:mm")
        }

        model: ListModel {
            id: messagesListModel
        }

        delegate: MessageBubble {
            width: messagesList.width
            role: model.role
            content: model.content
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Load this conversation")
                onClicked: {
                    conversationManager.loadConversation(conversationId)
                    pageStack.pop(pageStack.find(function(page) {
                        return page.objectName === "chatPage"
                    }))
                }
            }
        }

        ViewPlaceholder {
            enabled: messagesListModel.count === 0
            text: qsTr("No messages")
            hintText: qsTr("This conversation is empty")
        }

        VerticalScrollDecorator {}
    }

    Component.onCompleted: {
        loadConversation()
    }

    function loadConversation() {
        conversationDetails = conversationManager.getConversationDetails(conversationId)

        messagesListModel.clear()
        var messages = conversationDetails.messages || []
        for (var i = 0; i < messages.length; i++) {
            messagesListModel.append(messages[i])
        }
    }
}
