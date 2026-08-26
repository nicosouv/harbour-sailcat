import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: modelSelectorDialog
    allowedOrientations: Orientation.All

    property var onModelSelected: function(model) {}
    // Provider whose catalogue is listed, and the model currently in use for
    // whatever asked: both belong to a conversation, not to the app.
    property string providerId: settingsManager.providerId
    property string currentModel: settingsManager.modelName

    function prettyModelName(id) {
        var parts = id.replace(/-latest$/, "").split("-")
        for (var i = 0; i < parts.length; i++) {
            parts[i] = parts[i].charAt(0).toUpperCase() + parts[i].slice(1)
        }
        return parts.join(" ")
    }

    Component.onCompleted: {
        var models = settingsManager.availableModelsFor(providerId)
        for (var i = 0; i < models.length; i++) {
            modelListModel.append({
                name: prettyModelName(models[i]),
                value: models[i],
                desc: settingsManager.isVisionModelFor(providerId, models[i])
                      ? qsTr("Vision capable") : ""
            })
        }
    }

    ListModel {
        id: modelListModel
    }

    SilicaListView {
        anchors.fill: parent
        model: modelListModel

        // As the list header, the dialog banner keeps the items below it.
        // The provider goes in a label of its own: DialogHeader has no
        // description, unlike PageHeader.
        header: Column {
            width: modelSelectorDialog.width
            spacing: Theme.paddingSmall

            DialogHeader {
                title: qsTr("Select Model")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: settingsManager.providerNameFor(modelSelectorDialog.providerId)
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                truncationMode: TruncationMode.Fade
            }

            // Positioner padding needs QtQuick 2.6; this file imports 2.0
            Item {
                width: 1
                height: Theme.paddingMedium
            }
        }

        delegate: ListItem {
            id: modelItem
            width: parent.width
            contentHeight: itemColumn.height + Theme.paddingMedium * 2

            onClicked: {
                modelSelectorDialog.accept()
                onModelSelected(value)
            }

            Column {
                id: itemColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: Theme.horizontalPageMargin
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                spacing: Theme.paddingSmall

                Label {
                    width: parent.width
                    text: name
                    font.pixelSize: Theme.fontSizeMedium
                    color: modelItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                    truncationMode: TruncationMode.Fade

                    // Mark the active model
                    Icon {
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        source: "image://theme/icon-s-accept"
                        visible: value === modelSelectorDialog.currentModel
                    }
                }

                Label {
                    width: parent.width
                    text: desc
                    visible: desc !== ""
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    wrapMode: Text.WordWrap
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
