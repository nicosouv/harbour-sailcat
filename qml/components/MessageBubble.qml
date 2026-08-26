import QtQuick 2.0
import Sailfish.Silica 1.0

ListItem {
    id: messageItem
    width: parent.width
    contentHeight: Math.max(contentColumn.height + verticalPadding * 2,
                            busyIndicator.visible ? Theme.itemSizeExtraSmall : 0)

    property string role: "user"
    property string content: ""
    property bool isLast: false
    property bool pinned: false
    property double timestamp: 0
    property string imagePath: ""
    // Who produced this answer. Both empty on user turns; on assistant turns
    // written before 2.3 the provider is known and the model is not.
    property string messageModel: ""
    property string messageProvider: ""

    signal regenerateRequested()
    signal editRequested()
    signal pinToggled()

    // --- Presentation, driven by the chat style setting -------------------

    readonly property string chatStyle: settingsManager.chatStyle
    readonly property bool isUser: role === "user"
    readonly property bool bubbled: chatStyle === "bubbles"
    readonly property bool carded: chatStyle === "cards"
    readonly property bool compact: chatStyle === "compact"

    readonly property real hMargin: compact ? Theme.paddingMedium : Theme.horizontalPageMargin
    readonly property real innerPadding: bubbled ? Theme.paddingMedium
                                                 : (carded ? Theme.paddingMedium : 0)
    readonly property real verticalPadding: compact ? Theme.paddingSmall : Theme.paddingMedium
    readonly property int textSize: compact ? Theme.fontSizeExtraSmall : Theme.fontSizeSmall

    // Bubbles hug their text; the other styles use the full column width.
    readonly property real availableWidth: width - 2 * hMargin
                                           - (bubbled ? 2 * innerPadding : 0)
    readonly property real maxContentWidth: bubbled ? availableWidth * 0.82 : availableWidth
    readonly property real imageWidth: bubbled ? maxContentWidth : availableWidth * 0.6

    // Only the bubble style flips text to the right; elsewhere a right aligned
    // paragraph is just hard to read.
    readonly property int textAlignment: (bubbled || chatStyle === "flat") && isUser
                                         ? Text.AlignRight : Text.AlignLeft

    readonly property color accentColor: isUser ? Theme.highlightBackgroundColor
                                                : Theme.secondaryHighlightColor

    menu: ContextMenu {
        MenuItem {
            text: qsTr("Copy")
            onClicked: {
                Clipboard.text = messageItem.content
            }
        }
        MenuItem {
            text: messageItem.pinned ? qsTr("Unpin") : qsTr("Pin")
            onClicked: messageItem.pinToggled()
        }
        MenuItem {
            text: qsTr("Copy code")
            visible: messageItem.content.indexOf("```") !== -1
            onClicked: {
                Clipboard.text = extractCodeBlocks(messageItem.content)
            }
        }
        MenuItem {
            text: qsTr("Edit")
            visible: messageItem.isUser && !mistralApi.isBusy
            onClicked: messageItem.editRequested()
        }
        MenuItem {
            text: qsTr("Regenerate")
            visible: messageItem.role === "assistant" && messageItem.isLast && !mistralApi.isBusy
            onClicked: messageItem.regenerateRequested()
        }
    }

    // Full-width background: flat tints the user rows, cards draws a panel
    Rectangle {
        anchors.fill: parent
        visible: !messageItem.bubbled && !messageItem.compact
        color: messageItem.carded
            ? Theme.rgba(messageItem.isUser ? Theme.highlightBackgroundColor
                                            : Theme.secondaryHighlightColor, 0.10)
            : (messageItem.isUser ? Theme.rgba(Theme.highlightBackgroundColor, 0.15)
                                  : "transparent")
    }

    // Bubble background, sized to the content
    Rectangle {
        visible: messageItem.bubbled
        x: contentColumn.x - messageItem.innerPadding
        y: contentColumn.y - messageItem.innerPadding
        width: contentColumn.width + messageItem.innerPadding * 2
        height: contentColumn.height + messageItem.innerPadding * 2
        radius: Theme.paddingLarge
        color: Theme.rgba(messageItem.accentColor, messageItem.isUser ? 0.28 : 0.14)
    }

    // Pinned indicator: thin highlight edge + star in the corner
    Rectangle {
        visible: messageItem.pinned
        width: Theme.paddingSmall / 2
        height: parent.height
        anchors.left: parent.left
        color: Theme.highlightColor
    }

    Icon {
        visible: messageItem.pinned
        source: "image://theme/icon-s-favorite"
        color: Theme.highlightColor
        anchors {
            top: parent.top
            right: parent.right
            topMargin: Theme.paddingSmall
            rightMargin: Theme.paddingSmall
        }
    }

    Column {
        id: contentColumn
        y: messageItem.verticalPadding
        x: messageItem.bubbled && messageItem.isUser
           ? messageItem.width - width - messageItem.hMargin - messageItem.innerPadding
           : messageItem.hMargin + messageItem.innerPadding
        // A bubble hugs its content; the other styles fill the column. The
        // children never read this width back in bubble mode, so there is no
        // binding loop.
        width: messageItem.bubbled
               ? Math.max(messageLabel.visible ? messageLabel.width : 0,
                          attachedImage.visible ? attachedImage.width : 0,
                          Theme.itemSizeExtraSmall)
               : messageItem.availableWidth
        spacing: Theme.paddingSmall / 2

        // Role header, cards style only
        Label {
            width: parent.width
            visible: messageItem.carded
            text: messageItem.isUser ? qsTr("You") : qsTr("Assistant")
            font.pixelSize: Theme.fontSizeTiny
            font.bold: true
            color: messageItem.accentColor
        }

        Image {
            id: attachedImage
            visible: messageItem.imagePath !== "" && status !== Image.Error
            source: messageItem.imagePath
            width: messageItem.imageWidth
            sourceSize.width: 512
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            x: messageItem.textAlignment === Text.AlignRight ? parent.width - width : 0
        }

        Label {
            id: messageLabel
            width: messageItem.bubbled
                   ? Math.min(implicitWidth, messageItem.maxContentWidth)
                   : messageItem.availableWidth
            // The compact style has no room for a header row, so the speaker
            // is folded into the first line of the message itself.
            text: (messageItem.compact
                   ? '<font color="' + messageItem.accentColor + '"><b>'
                     + (messageItem.isUser ? qsTr("You") : "AI") + ':</b></font> '
                   : "") + formatMarkdown(content)
            textFormat: Text.RichText
            wrapMode: Text.Wrap
            font.pixelSize: messageItem.textSize
            color: Theme.primaryColor
            linkColor: Theme.highlightColor
            horizontalAlignment: messageItem.textAlignment
            visible: content !== ""

            onLinkActivated: messageItem.openLink(link)
        }

        Label {
            width: parent.width
            text: messageItem.timestamp > 0
                  ? Qt.formatTime(new Date(messageItem.timestamp), "hh:mm") : ""
            visible: settingsManager.showTimestamps && !messageItem.compact
                     && text !== "" && content !== ""
            horizontalAlignment: messageItem.textAlignment
            font.pixelSize: Theme.fontSizeTiny
            color: Theme.secondaryColor
        }

        // Origin of the answer. A conversation may have changed provider
        // halfway through, and without this the transcript would not say so.
        Label {
            width: parent.width
            text: {
                if (messageItem.messageProvider === "") {
                    return ""
                }
                var name = settingsManager.providerNameFor(messageItem.messageProvider)
                return messageItem.messageModel === ""
                        ? name : name + " \u00b7 " + messageItem.messageModel
            }
            visible: !messageItem.isUser && text !== "" && content !== ""
            horizontalAlignment: messageItem.textAlignment
            font.pixelSize: Theme.fontSizeTiny
            color: Theme.secondaryColor
            truncationMode: TruncationMode.Fade
        }
    }

    // Separator between cards
    Separator {
        visible: messageItem.carded
        width: parent.width
        anchors.bottom: parent.bottom
        color: Theme.rgba(Theme.secondaryColor, 0.2)
    }

    // Streaming placeholder shown inside the pending assistant bubble
    TypingIndicator {
        id: busyIndicator
        visible: role === "assistant" && content === "" && mistralApi.isBusy
        running: visible
        anchors {
            left: parent.left
            leftMargin: messageItem.hMargin
            verticalCenter: parent.verticalCenter
        }
    }

    // Only ever hand the browser a scheme we chose. A response is untrusted
    // input, and "javascript:" in a markdown link would otherwise get through.
    function openLink(link) {
        if (/^(https?|mailto):/i.test(link)) {
            Qt.openUrlExternally(link)
        } else {
            console.warn("Blocked link with unsupported scheme")
        }
    }

    function extractCodeBlocks(text) {
        if (!text) return ""

        var blocks = []
        var re = /```[a-zA-Z0-9+#-]*\n?([\s\S]*?)```/g
        var m
        while ((m = re.exec(text)) !== null) {
            var code = m[1]
            if (code.charAt(code.length - 1) === '\n') {
                code = code.slice(0, -1)
            }
            if (code.length > 0) {
                blocks.push(code)
            }
        }
        return blocks.join("\n\n")
    }

    function formatMarkdown(text) {
        if (!text) return ""

        // Escape HTML so raw tags in the response cannot be interpreted.
        // Quotes go too: they would otherwise let a crafted link URL break out
        // of the href attribute we build below.
        var formatted = text
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')

        // Protect code from the formatting rules below: extract it,
        // substitute placeholders, reinsert at the end
        var codeBlocks = []
        formatted = formatted.replace(/```[a-zA-Z0-9+#-]*\n?([\s\S]*?)```/g, function(match, code) {
            if (code.charAt(code.length - 1) === '\n') {
                code = code.slice(0, -1)
            }
            codeBlocks.push(code)
            return '\x01' + (codeBlocks.length - 1) + '\x01'
        })

        var inlineCodes = []
        formatted = formatted.replace(/`([^`\n]+)`/g, function(match, code) {
            inlineCodes.push(code)
            return '\x02' + (inlineCodes.length - 1) + '\x02'
        })

        // Bold (**text**)
        formatted = formatted.replace(/\*\*([^\*]+)\*\*/g, '<b>$1</b>')

        // Italic (*text*), not adjacent to word chars or other asterisks
        formatted = formatted.replace(/(^|[\s(])\*([^\*\n]+)\*($|[\s).,;:!?])/gm, '$1<i>$2</i>$3')

        // Strikethrough (~~text~~)
        formatted = formatted.replace(/~~([^~]+)~~/g, '<s>$1</s>')

        // Links [text](url), restricted to schemes we are willing to open
        formatted = formatted.replace(/\[([^\]]+)\]\(([^\)\s]+)\)/g, function(match, label, url) {
            if (!/^(https?:\/\/|mailto:)/i.test(url)) {
                return label
            }
            return '<a href="' + url + '">' + label + '</a>'
        })

        // Headers (# text)
        formatted = formatted.replace(/^### (.+)$/gm, '<h3>$1</h3>')
        formatted = formatted.replace(/^## (.+)$/gm, '<h2>$1</h2>')
        formatted = formatted.replace(/^# (.+)$/gm, '<h1>$1</h1>')

        // Bullet points (- item or * item)
        formatted = formatted.replace(/^[\-\*] (.+)$/gm, '• $1')

        // Line breaks (code is still tokenized, so <pre> newlines are preserved)
        formatted = formatted.replace(/\n/g, '<br>')

        // Reinsert code, colored from the theme so it works on any ambience
        var codeColor = "" + Theme.highlightColor
        formatted = formatted.replace(/\x02(\d+)\x02/g, function(match, i) {
            return '<tt><font color="' + codeColor + '">' + inlineCodes[parseInt(i, 10)] + '</font></tt>'
        })
        formatted = formatted.replace(/\x01(\d+)\x01/g, function(match, i) {
            return '<pre><font color="' + codeColor + '">' + codeBlocks[parseInt(i, 10)] + '</font></pre>'
        })

        return formatted
    }
}
