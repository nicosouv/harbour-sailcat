import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: aboutPage

    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: qsTr("About")
            }

            Item {
                width: parent.width
                height: Theme.itemSizeHuge

                Icon {
                    anchors.centerIn: parent
                    source: "image://theme/icon-l-chat"
                    width: Theme.iconSizeExtraLarge
                    height: Theme.iconSizeExtraLarge
                    color: Theme.highlightColor
                }
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "SailCat"
                font.pixelSize: Theme.fontSizeExtraLarge
                color: Theme.highlightColor
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Version %1").arg("1.2.1")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
            }

            SectionHeader {
                text: qsTr("Description")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("SailCat is an elegant client for Mistral AI Chat, " +
                      "specifically designed for Sailfish OS. Enjoy intelligent " +
                      "conversations with Mistral's most advanced AI models, " +
                      "directly from your Sailfish device.")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primaryColor
            }

            SectionHeader {
                text: qsTr("Features")
            }

            Column {
                width: parent.width
                spacing: Theme.paddingSmall

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: qsTr("• Mistral AI free tier support")
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: qsTr("• Real-time streaming responses")
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: qsTr("• Native Sailfish interface with Silica")
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: qsTr("• Conversation history")
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: qsTr("• Choice between multiple Mistral models")
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }
            }

            SectionHeader {
                text: qsTr("Development")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Developed with ❤️ for Sailfish OS")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primaryColor
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Source code on GitHub")
                onClicked: Qt.openUrlExternally("https://github.com/nicosouv/harbour-sailcat")
            }

            SectionHeader {
                text: qsTr("Credits")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Powered by Mistral AI API\nInterface: Sailfish Silica\nFramework: Qt 5.6")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
            }

            SectionHeader {
                text: qsTr("License")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("MIT License\n\nThis application is free software. You are free to use, " +
                      "modify, and distribute it under the terms of the MIT license.")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }
        }

        VerticalScrollDecorator {}
    }
}
