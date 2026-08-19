import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: libraryPage
    allowedOrientations: Orientation.All

    // Set by the caller so a tapped prompt lands in the input field
    property var chatPage: null

    SilicaListView {
        id: promptList
        anchors.fill: parent
        model: settingsManager.savedPrompts

        header: Column {
            width: parent.width

            PageHeader {
                title: qsTr("Prompt library")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Tap a prompt to add it to the message you are writing.")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("New prompt")
                onClicked: pageStack.push(promptEditor, { editIndex: -1 })
            }
        }

        ViewPlaceholder {
            enabled: promptList.count === 0
            text: qsTr("No saved prompts")
            hintText: qsTr("Use the pulley menu to save one")
        }

        delegate: ListItem {
            id: promptItem
            contentHeight: promptColumn.height + Theme.paddingLarge

            onClicked: {
                if (libraryPage.chatPage) {
                    libraryPage.chatPage.insertPrompt(modelData.text)
                }
                pageStack.navigateBack()
            }

            menu: ContextMenu {
                MenuItem {
                    text: qsTr("Edit")
                    onClicked: pageStack.push(promptEditor, {
                        editIndex: index,
                        promptTitle: modelData.title,
                        promptText: modelData.text
                    })
                }
                MenuItem {
                    text: qsTr("Copy")
                    onClicked: Clipboard.text = modelData.text
                }
                MenuItem {
                    text: qsTr("Delete")
                    onClicked: promptItem.remorseAction(qsTr("Deleting"), function() {
                        settingsManager.removeSavedPrompt(index)
                    })
                }
            }

            Column {
                id: promptColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: Theme.horizontalPageMargin
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                spacing: Theme.paddingSmall / 2

                Label {
                    width: parent.width
                    text: modelData.title
                    color: promptItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                    font.pixelSize: Theme.fontSizeMedium
                    truncationMode: TruncationMode.Fade
                }

                Label {
                    width: parent.width
                    text: modelData.text
                    color: promptItem.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }
        }

        VerticalScrollDecorator {}
    }

    Component {
        id: promptEditor

        Dialog {
            id: editorDialog
            allowedOrientations: Orientation.All

            property int editIndex: -1
            property string promptTitle: ""
            property string promptText: ""

            canAccept: bodyField.text.trim().length > 0

            onAccepted: {
                if (editIndex >= 0) {
                    settingsManager.updateSavedPrompt(editIndex, titleField.text, bodyField.text)
                } else {
                    settingsManager.addSavedPrompt(titleField.text, bodyField.text)
                }
            }

            SilicaFlickable {
                anchors.fill: parent
                contentHeight: editorColumn.height

                Column {
                    id: editorColumn
                    width: parent.width
                    spacing: Theme.paddingMedium

                    DialogHeader {
                        title: editorDialog.editIndex >= 0 ? qsTr("Edit prompt")
                                                           : qsTr("New prompt")
                        acceptText: qsTr("Save")
                        cancelText: qsTr("Cancel")
                    }

                    TextField {
                        id: titleField
                        width: parent.width
                        label: qsTr("Name")
                        placeholderText: qsTr("Optional name")
                        text: editorDialog.promptTitle

                        EnterKey.iconSource: "image://theme/icon-m-enter-next"
                        EnterKey.onClicked: bodyField.focus = true
                    }

                    TextArea {
                        id: bodyField
                        width: parent.width
                        label: qsTr("Prompt")
                        placeholderText: qsTr("Enter the prompt text...")
                        text: editorDialog.promptText
                    }
                }

                VerticalScrollDecorator {}
            }
        }
    }
}
