import QtQuick 2.0
import Sailfish.Silica 1.0
import "ProvidersUi.js" as ProvidersUi

// Who answers in this conversation, as a coloured initial. Doubles as the
// status light: it pulses while an answer is being written and stays lit
// until that answer has been read.
Rectangle {
    id: badge

    property string provider: ""
    property bool streaming: false
    property bool unread: false

    readonly property color accent: ProvidersUi.color(provider)

    width: Theme.itemSizeExtraSmall * 0.7
    height: width
    radius: Theme.paddingSmall
    color: Theme.rgba(accent, 0.18)
    border.color: Theme.rgba(accent, streaming || unread ? 0.9 : 0.45)
    border.width: 1

    Label {
        anchors.centerIn: parent
        text: ProvidersUi.initial(badge.provider)
        font.pixelSize: Theme.fontSizeSmall
        font.bold: true
        color: badge.accent
    }

    Rectangle {
        id: statusDot
        visible: badge.streaming || badge.unread
        width: Theme.paddingSmall
        height: width
        radius: width / 2
        color: Theme.highlightColor
        anchors {
            right: parent.right
            top: parent.top
            rightMargin: -width / 3
            topMargin: -width / 3
        }

        SequentialAnimation {
            running: badge.streaming && statusDot.visible
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation {
                target: statusDot; property: "opacity"
                from: 1; to: 0.25; duration: 600
            }
            NumberAnimation {
                target: statusDot; property: "opacity"
                from: 0.25; to: 1; duration: 600
            }
        }
    }
}
