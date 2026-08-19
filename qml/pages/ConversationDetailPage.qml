import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"

Page {
    id: detailPage
    allowedOrientations: Orientation.All

    property string conversationId: ""
    property var conversationDetails: ({})
    property var convStats: ({})
    property var rhythm: []
    property int maxRhythmChars: 1
    property bool statsReady: false

    SilicaListView {
        id: messagesList
        anchors.fill: parent

        header: Column {
            width: messagesList.width

            PageHeader {
                title: conversationDetails.title || qsTr("Conversation")
                description: Qt.formatDateTime(new Date(conversationDetails.updatedAt || 0), "dd/MM/yyyy hh:mm")
            }

            // Animated stats panel
            Item {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: statsDonut.height + Theme.paddingLarge
                visible: (detailPage.convStats.messageCount || 0) > 0

                RatioDonut {
                    id: statsDonut
                    anchors.verticalCenter: parent.verticalCenter
                    ratio: (detailPage.convStats.totalChars || 0) > 0
                           ? detailPage.convStats.assistantChars / detailPage.convStats.totalChars : 0
                    go: detailPage.statsReady
                    label: qsTr("written by AI")
                }

                Column {
                    anchors {
                        left: statsDonut.right
                        leftMargin: Theme.paddingLarge
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Theme.paddingSmall

                    CountUpLabel {
                        value: detailPage.convStats.messageCount || 0
                        go: detailPage.statsReady
                        suffix: " " + qsTr("messages")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.highlightColor
                    }

                    CountUpLabel {
                        // Real token count when tracked, estimate for older conversations
                        property bool exact: (detailPage.convStats.totalTokens || 0) > 0
                        value: exact ? detailPage.convStats.totalTokens
                                     : (detailPage.convStats.estimatedTokens || 0)
                        go: detailPage.statsReady
                        prefix: exact ? "" : "~"
                        suffix: " " + qsTr("tokens")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.primaryColor
                    }

                    Label {
                        text: formatDuration(detailPage.convStats.durationMs || 0)
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                    }

                    CategoryChip {
                        category: detailPage.convStats.category || ""
                    }
                }
            }

            SectionHeader {
                text: qsTr("Conversation rhythm")
                visible: detailPage.rhythm.length > 1
            }

            // One bar per message, height by length, color by author
            Row {
                id: rhythmChart
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: Theme.itemSizeMedium
                spacing: 2
                visible: detailPage.rhythm.length > 1

                property real barWidth: detailPage.rhythm.length > 0
                                        ? Math.max(2, (width - spacing * (detailPage.rhythm.length - 1)) / detailPage.rhythm.length)
                                        : 0

                Repeater {
                    model: detailPage.rhythm

                    Item {
                        width: rhythmChart.barWidth
                        height: rhythmChart.height

                        Rectangle {
                            id: rhythmBar
                            anchors.bottom: parent.bottom
                            width: parent.width
                            radius: 2
                            height: 4
                            color: modelData.role === "user"
                                   ? Theme.rgba(Theme.secondaryHighlightColor, 0.9)
                                   : Theme.highlightColor

                            property real targetHeight: Math.max(6, parent.height
                                    * Math.sqrt(modelData.chars) / Math.sqrt(detailPage.maxRhythmChars))

                            SequentialAnimation {
                                running: detailPage.statsReady
                                PauseAnimation { duration: index * 30 }
                                NumberAnimation {
                                    target: rhythmBar
                                    property: "height"
                                    to: rhythmBar.targetHeight
                                    duration: 300
                                    easing.type: Easing.OutBack
                                }
                            }
                        }
                    }
                }
            }

            // Legend
            Row {
                x: Theme.horizontalPageMargin
                spacing: Theme.paddingLarge
                visible: detailPage.rhythm.length > 1

                Row {
                    spacing: Theme.paddingSmall
                    Rectangle {
                        width: Theme.paddingMedium
                        height: width
                        radius: 2
                        color: Theme.rgba(Theme.secondaryHighlightColor, 0.9)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        text: qsTr("You")
                        font.pixelSize: Theme.fontSizeTiny
                        color: Theme.secondaryColor
                    }
                }

                Row {
                    spacing: Theme.paddingSmall
                    Rectangle {
                        width: Theme.paddingMedium
                        height: width
                        radius: 2
                        color: Theme.highlightColor
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        text: qsTr("Assistant")
                        font.pixelSize: Theme.fontSizeTiny
                        color: Theme.secondaryColor
                    }
                }
            }

            SectionHeader {
                text: qsTr("Messages")
            }
        }

        model: ListModel {
            id: messagesListModel
        }

        delegate: MessageBubble {
            width: messagesList.width
            role: model.role
            content: model.content
            imagePath: model.imagePath || ""
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Load this conversation")
                onClicked: {
                    conversationManager.loadConversation(conversationId)
                    // This page sits on the history, which is the root: drop
                    // back onto it and open the chat fresh.
                    pageStack.pop(undefined, PageStackAction.Immediate)
                    pageStack.push(Qt.resolvedUrl("ChatPage.qml"))
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
        convStats = conversationManager.getConversationStatistics(conversationId)
        rhythm = convStats.rhythm || []

        var maxChars = 1
        for (var i = 0; i < rhythm.length; i++) {
            if (rhythm[i].chars > maxChars) maxChars = rhythm[i].chars
        }
        maxRhythmChars = maxChars

        messagesListModel.clear()
        var messages = conversationDetails.messages || []
        for (var j = 0; j < messages.length; j++) {
            messagesListModel.append(messages[j])
        }

        statsReady = true
    }

    function formatDuration(ms) {
        if (ms <= 0) return qsTr("Single exchange")
        var minutes = Math.floor(ms / 60000)
        if (minutes < 1) return qsTr("Less than a minute")
        if (minutes < 60) return qsTr("%n minute(s)", "", minutes)
        var hours = Math.floor(minutes / 60)
        if (hours < 48) return qsTr("%n hour(s)", "", hours)
        return qsTr("%n day(s)", "", Math.floor(hours / 24))
    }
}
