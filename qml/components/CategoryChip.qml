import QtQuick 2.0
import Sailfish.Silica 1.0
import "Categories.js" as Categories

// Small colored pill showing a conversation category
Rectangle {
    id: chip

    property string category: ""

    visible: category !== ""
    width: chipLabel.width + Theme.paddingMedium
    height: chipLabel.height + Theme.paddingSmall / 2
    radius: height / 2
    color: Theme.rgba(Categories.color(category), 0.2)
    border.color: Theme.rgba(Categories.color(category), 0.6)
    border.width: 1

    Label {
        id: chipLabel
        anchors.centerIn: parent
        text: Categories.label(chip.category)
        font.pixelSize: Theme.fontSizeTiny
        color: Categories.color(chip.category)
    }
}
