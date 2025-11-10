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
                title: "À propos"
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
                text: "Version 1.0.0"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
            }

            SectionHeader {
                text: "Description"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: "SailCat est un client élégant pour Le Chat de Mistral AI, " +
                      "spécialement conçu pour Sailfish OS. Profitez de conversations " +
                      "intelligentes avec les modèles d'IA les plus avancés de Mistral, " +
                      "directement depuis votre appareil Sailfish."
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primaryColor
            }

            SectionHeader {
                text: "Fonctionnalités"
            }

            Column {
                width: parent.width
                spacing: Theme.paddingSmall

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: "• Support du free tier de Mistral AI"
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: "• Streaming en temps réel des réponses"
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: "• Interface native Sailfish avec Silica"
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: "• Historique des conversations"
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: "• Choix entre plusieurs modèles Mistral"
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }
            }

            SectionHeader {
                text: "Développement"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: "Développé avec ❤️ pour Sailfish OS"
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primaryColor
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Code source sur GitHub"
                onClicked: Qt.openUrlExternally("https://github.com/nicosouv/harbour-sailcat")
            }

            SectionHeader {
                text: "Crédits"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: "Propulsé par l'API Mistral AI\n" +
                      "Interface: Sailfish Silica\n" +
                      "Framework: Qt 5.6"
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
            }

            SectionHeader {
                text: "Licence"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: "MIT License\n\n" +
                      "Cette application est un logiciel libre. Vous êtes libre de l'utiliser, " +
                      "de la modifier et de la distribuer selon les termes de la licence MIT."
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
