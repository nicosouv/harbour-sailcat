import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
    id: cover

    Column {
        anchors.centerIn: parent
        spacing: Theme.paddingMedium
        width: parent.width - 2 * Theme.horizontalPageMargin

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "image://theme/icon-l-message"
            width: Theme.iconSizeLarge
            height: Theme.iconSizeLarge
            color: Theme.primaryColor
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "SailCat"
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.primaryColor
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: conversationModel.count > 0 ?
                  conversationModel.count + " message" + (conversationModel.count > 1 ? "s" : "") :
                  "Aucune conversation"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.secondaryColor
        }
    }

    CoverActionList {
        id: coverAction

        CoverAction {
            iconSource: "image://theme/icon-cover-new"
            onTriggered: {
                conversationModel.clearConversation()
            }
        }
    }
}
