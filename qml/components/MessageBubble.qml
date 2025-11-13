import QtQuick 2.0
import Sailfish.Silica 1.0

ListItem {
    id: messageItem
    width: parent.width
    contentHeight: messageLabel.height + Theme.paddingLarge

    property string role: "user"
    property string content: ""

    menu: ContextMenu {
        MenuItem {
            text: qsTr("Copy")
            onClicked: {
                Clipboard.text = messageItem.content
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: role === "user"
            ? Theme.rgba(Theme.highlightBackgroundColor, 0.15)
            : "transparent"
    }

    Label {
        id: messageLabel
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: role === "user" ? Theme.horizontalPageMargin * 2 : Theme.horizontalPageMargin
            rightMargin: role === "assistant" ? Theme.horizontalPageMargin * 2 : Theme.horizontalPageMargin
        }
        text: formatMarkdown(content)
        textFormat: Text.StyledText
        wrapMode: Text.Wrap
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.primaryColor
        linkColor: Theme.highlightColor
        horizontalAlignment: role === "user" ? Text.AlignRight : Text.AlignLeft

        onLinkActivated: Qt.openUrlExternally(link)
    }

    function formatMarkdown(text) {
        if (!text) return ""

        var formatted = text

        // Code blocks (```)
        formatted = formatted.replace(/```([^`]+)```/g, '<pre style="background-color: rgba(255,255,255,0.1); padding: 8px; border-radius: 4px;">$1</pre>')

        // Inline code (`)
        formatted = formatted.replace(/`([^`]+)`/g, '<code style="background-color: rgba(255,255,255,0.1); padding: 2px 4px; border-radius: 2px;">$1</code>')

        // Bold (**text**)
        formatted = formatted.replace(/\*\*([^\*]+)\*\*/g, '<b>$1</b>')

        // Italic (*text*)
        formatted = formatted.replace(/\*([^\*]+)\*/g, '<i>$1</i>')

        // Links [text](url)
        formatted = formatted.replace(/\[([^\]]+)\]\(([^\)]+)\)/g, '<a href="$2">$1</a>')

        // Headers (# text)
        formatted = formatted.replace(/^### (.+)$/gm, '<h3>$1</h3>')
        formatted = formatted.replace(/^## (.+)$/gm, '<h2>$1</h2>')
        formatted = formatted.replace(/^# (.+)$/gm, '<h1>$1</h1>')

        // Bullet points (- item or * item)
        formatted = formatted.replace(/^[\-\*] (.+)$/gm, '• $1')

        // Line breaks
        formatted = formatted.replace(/\n/g, '<br>')

        return formatted
    }
}
