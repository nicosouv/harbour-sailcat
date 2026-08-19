import QtQuick 2.0
import Sailfish.Silica 1.0
import "pages"

ApplicationWindow {
    id: appWindow

    // The history is the root page and the chat sits on top of it, so the chat
    // has a destination on both sides: back to the history, forward to the
    // settings of the current conversation. The chat is pushed immediately so
    // the app still opens on the conversation.
    initialPage: Component { ConversationHistoryPage { } }
    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: defaultAllowedOrientations

    Component.onCompleted: {
        pageStack.push(Qt.resolvedUrl("pages/ChatPage.qml"), {},
                       PageStackAction.Immediate)
    }

    // The app can be killed while in the background without further warning,
    // so flush the conversation as soon as it stops being the active window.
    Connections {
        target: Qt.application
        onStateChanged: {
            if (Qt.application.state !== Qt.ApplicationActive) {
                conversationManager.saveCurrentConversation()
            }
        }
    }
}
