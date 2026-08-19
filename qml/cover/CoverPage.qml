import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
    id: cover

    property string lastMessage: conversationModel.getLastAssistantMessage()
    property var coverStats: conversationManager.getStatistics()

    function refresh() {
        lastMessage = conversationModel.getLastAssistantMessage()
        coverStats = conversationManager.getStatistics()
    }

    function formatCount(n) {
        if (n >= 1000000) return (n / 1000000).toFixed(1) + "M"
        if (n >= 1000) return (n / 1000).toFixed(1) + "K"
        return "" + n
    }

    Connections {
        target: mistralApi
        onResponseCompleted: cover.refresh()
    }

    Connections {
        target: conversationManager
        onCurrentConversationChanged: cover.refresh()
    }

    // Follow the answer as it arrives. Polling beats reacting to every delta:
    // the cover is small and a redraw per token would be wasted work.
    Timer {
        interval: 500
        repeat: true
        running: mistralApi.isBusy
        onTriggered: cover.lastMessage = conversationModel.getLastAssistantMessage()
    }

    Column {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: Theme.paddingLarge
            leftMargin: Theme.paddingLarge
            rightMargin: Theme.paddingLarge
        }
        spacing: Theme.paddingMedium

        Row {
            spacing: Theme.paddingMedium

            Icon {
                source: "image://theme/icon-m-message"
                color: Theme.primaryColor
                anchors.verticalCenter: parent.verticalCenter
            }

            Label {
                text: "SailCat"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.primaryColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Tail of the latest answer, or the message count as fallback
        Label {
            width: parent.width
            text: cover.lastMessage
            visible: cover.lastMessage !== ""
            wrapMode: Text.Wrap
            maximumLineCount: 6
            truncationMode: TruncationMode.Fade
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
        }

        Label {
            width: parent.width
            text: conversationModel.count > 0
                  ? qsTr("%n message(s)", "", conversationModel.count)
                  : qsTr("No conversation")
            visible: cover.lastMessage === ""
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.secondaryColor
        }
    }

    // Mini stats anchored at the bottom
    Column {
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            bottomMargin: Theme.itemSizeSmall
            leftMargin: Theme.paddingLarge
            rightMargin: Theme.paddingLarge
        }
        spacing: Theme.paddingSmall / 2

        Separator {
            width: parent.width
            color: Theme.rgba(Theme.highlightColor, 0.4)
        }

        Label {
            text: qsTr("%n conversation(s)", "", coverStats.totalConversations || 0)
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
        }

        Label {
            text: (coverStats.totalTokens || 0) > 0
                  ? qsTr("Tokens: %1").arg(formatCount(coverStats.totalTokens))
                  : qsTr("Tokens this month: %1").arg(formatCount(coverStats.tokensThisMonth || 0))
            visible: (coverStats.totalTokens || 0) > 0 || (coverStats.tokensThisMonth || 0) > 0
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
        }
    }

    CoverActionList {
        id: coverAction

        CoverAction {
            iconSource: "image://theme/icon-cover-new"
            onTriggered: {
                conversationManager.createNewConversation()
            }
        }
    }
}
