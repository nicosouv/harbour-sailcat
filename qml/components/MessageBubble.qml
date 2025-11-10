import QtQuick 2.0
import Sailfish.Silica 1.0

Item {
    id: bubble
    width: parent.width
    height: bubbleRect.height + Theme.paddingMedium

    property string role: "user"
    property string content: ""

    Rectangle {
        id: bubbleRect
        width: Math.min(messageLabel.contentWidth + Theme.paddingLarge * 2, bubble.width * 0.85)
        height: messageLabel.height + Theme.paddingLarge
        radius: Theme.paddingMedium
        color: role === "user"
            ? Theme.rgba(Theme.highlightBackgroundColor, 0.3)
            : Theme.rgba(Theme.secondaryColor, 0.15)

        anchors {
            right: role === "user" ? parent.right : undefined
            left: role === "assistant" ? parent.left : undefined
            rightMargin: role === "user" ? Theme.horizontalPageMargin : 0
            leftMargin: role === "assistant" ? Theme.horizontalPageMargin : 0
        }

        Label {
            id: messageLabel
            anchors {
                fill: parent
                margins: Theme.paddingMedium
                topMargin: Theme.paddingSmall
                bottomMargin: Theme.paddingSmall
            }
            text: formatMarkdown(content)
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.primaryColor
            linkColor: Theme.highlightColor

            onLinkActivated: Qt.openUrlExternally(link)
        }
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
