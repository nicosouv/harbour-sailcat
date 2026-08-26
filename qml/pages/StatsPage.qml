import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components/Categories.js" as CategoryData

Page {
    id: statsPage
    allowedOrientations: Orientation.All

    property var stats: conversationManager.getStatistics()
    property var messagesPerDay: stats.messagesPerDay || []
    property var messagesPerHour: stats.messagesPerHour || []
    property int maxPerDay: maxOf(messagesPerDay)
    property int maxPerHour: maxOf(messagesPerHour)
    property real writeRatio: ((stats.totalUserChars || 0) + (stats.totalAssistantChars || 0)) > 0
                              ? stats.totalUserChars / (stats.totalUserChars + stats.totalAssistantChars) : 0
    property var tokensPerDay: stats.tokensPerDay || []
    property int maxTokensDay: maxOf(tokensPerDay)
    property var categoryList: buildCategoryList()
    property int maxCategoryCount: categoryList.length > 0 ? categoryList[0].count : 1
    // Both already sorted most-used first in C++, so [0] is the maximum.
    property var providerUsage: stats.providerUsage || []
    property var modelAnswers: (stats.modelAnswers || []).slice(0, 6)
    property int maxProviderCount: providerUsage.length > 0 ? providerUsage[0].count : 1
    property int maxModelCount: modelAnswers.length > 0 ? modelAnswers[0].count : 1
    property var funStats: conversationManager.getFunStats()
    property var topWords: funStats.topWords || []
    property var badges: buildBadges()
    property var costList: buildCostList()
    property real chartProgress: 0

    function buildBadges() {
        var list = []

        var switches = settingsManager.modelSwitches()
        list.push({
            name: qsTr("Model Hopper"),
            tier: switches < 5 ? qsTr("Loyal") : switches <= 20 ? qsTr("Explorer") : qsTr("Chaotic"),
            level: switches < 5 ? 0 : switches <= 20 ? 1 : 2,
            detail: qsTr("%1 model switches").arg(switches)
        })

        var longest = funStats.longestUserChars || 0
        list.push({
            name: qsTr("Longest Message"),
            tier: longest < 280 ? qsTr("Concise") : longest <= 2000 ? qsTr("Novelist") : "TL;DR",
            level: longest < 280 ? 0 : longest <= 2000 ? 1 : 2,
            detail: qsTr("%1 chars").arg(longest)
        })

        var hour = funStats.avgSendHour
        if (hour >= 0) {
            list.push({
                name: qsTr("Night Owl"),
                tier: hour < 6 ? qsTr("Night Owl") : hour < 12 ? qsTr("Early Bird") : qsTr("Normal"),
                level: hour < 6 ? 2 : hour < 12 ? 0 : 1,
                detail: qsTr("Average hour: %1h").arg(hour)
            })
        }

        var gap = funStats.avgGapSecs
        if (gap >= 0) {
            list.push({
                name: qsTr("Speed Typist"),
                tier: gap < 10 ? qsTr("Speedy") : gap > 300 ? qsTr("Snail") : qsTr("Normal"),
                level: gap < 10 ? 2 : gap > 300 ? 0 : 1,
                detail: gap < 60 ? qsTr("Avg: %1s").arg(gap) : qsTr("Avg: %1min").arg(Math.round(gap / 60))
            })
        }

        var ghosts = funStats.ghostCount || 0
        list.push({
            name: qsTr("Conversation Ghost"),
            tier: ghosts === 0 ? qsTr("Finisher") : ghosts <= 5 ? qsTr("Wanderer") : qsTr("Ghost"),
            level: ghosts === 0 ? 0 : ghosts <= 5 ? 1 : 2,
            detail: qsTr("%1 abandoned").arg(ghosts)
        })

        return list
    }

    function badgeColor(level) {
        switch (level) {
        case 0: return "#aed581"
        case 1: return "#ffb74d"
        default: return "#f06292"
        }
    }

    function buildCategoryList() {
        var counts = stats.categoryCounts || {}
        var list = []
        for (var key in counts) {
            list.push({ cat: key, count: counts[key] })
        }
        list.sort(function(a, b) { return b.count - a.count })
        return list
    }

    function categoryColor(cat) {
        return CategoryData.color(cat)
    }

    function categoryLabel(cat) {
        return CategoryData.label(cat)
    }

    // Cost is an estimate from a hand-maintained price list, and only covers
    // usage recorded since per-model tracking was added.
    function buildCostList() {
        var usage = stats.modelUsage || []
        var list = []
        for (var i = 0; i < usage.length; i++) {
            var entry = usage[i]
            var cost = settingsManager.estimatedCost(entry.model,
                                                     entry.promptTokens,
                                                     entry.completionTokens)
            list.push({
                model: entry.model,
                tokens: entry.promptTokens + entry.completionTokens,
                cost: cost
            })
        }
        list.sort(function(a, b) { return b.tokens - a.tokens })
        return list
    }

    function totalCost() {
        var total = 0
        var known = false
        for (var i = 0; i < costList.length; i++) {
            if (costList[i].cost >= 0) {
                total += costList[i].cost
                known = true
            }
        }
        return known ? total : -1
    }

    function formatCost(value) {
        if (value < 0) return qsTr("n/a")
        // A provider that bills nothing within its rate limits, not a rounding
        // artefact: zero is the real answer there.
        if (value === 0) return qsTr("free")
        if (value < 0.01) return "< $0.01"
        return "$" + value.toFixed(2)
    }

    NumberAnimation on chartProgress {
        from: 0
        to: 1
        duration: 800
        easing.type: Easing.OutCubic
    }

    function maxOf(list) {
        var m = 0
        for (var i = 0; i < list.length; i++) {
            if (list[i] > m) m = list[i]
        }
        return m
    }

    function formatTokens(n) {
        if (n >= 1000000) return "~" + (n / 1000000).toFixed(1) + "M"
        if (n >= 1000) return "~" + (n / 1000).toFixed(1) + "K"
        return "~" + n
    }

    function formatExactTokens(n) {
        if (n >= 1000000) return (n / 1000000).toFixed(1) + "M"
        if (n >= 1000) return (n / 1000).toFixed(1) + "K"
        return "" + n
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: qsTr("Statistics")
            }

            // Summary cards
            Grid {
                id: cardsGrid
                columns: 2
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                columnSpacing: Theme.paddingMedium
                rowSpacing: Theme.paddingMedium

                Repeater {
                    model: [
                        { value: "" + (stats.totalConversations || 0), label: qsTr("Conversations") },
                        { value: "" + (stats.totalMessages || 0), label: qsTr("Messages") },
                        { value: (stats.totalTokens || 0) > 0
                                 ? formatExactTokens(stats.totalTokens)
                                 : formatTokens(stats.estimatedTokens || 0),
                          label: qsTr("Tokens used") },
                        { value: conversationManager.getStorageSizeFormatted(), label: qsTr("Storage") }
                    ]

                    Rectangle {
                        width: (cardsGrid.width - cardsGrid.columnSpacing) / 2
                        height: Theme.itemSizeLarge
                        radius: Theme.paddingSmall
                        color: Theme.rgba(Theme.highlightColor, 0.1)

                        Column {
                            anchors.centerIn: parent

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.value
                                color: Theme.highlightColor
                                font.pixelSize: Theme.fontSizeLarge
                            }

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeExtraSmall
                            }
                        }
                    }
                }
            }

            // Who writes more (characters, not the meaningless 1:1 message ratio)
            SectionHeader {
                text: qsTr("Who writes more?")
                visible: statsPage.writeRatio > 0
            }

            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingSmall
                visible: statsPage.writeRatio > 0

                Rectangle {
                    width: parent.width
                    height: Theme.paddingMedium
                    radius: height / 2
                    color: Theme.rgba(Theme.secondaryHighlightColor, 0.4)

                    Rectangle {
                        width: Math.max(parent.height, parent.width * statsPage.writeRatio * statsPage.chartProgress)
                        height: parent.height
                        radius: parent.radius
                        color: Theme.highlightColor
                    }
                }

                Item {
                    width: parent.width
                    height: sentLabel.height

                    Label {
                        id: sentLabel
                        anchors.left: parent.left
                        text: qsTr("You: %1 chars").arg(formatExactTokens(stats.totalUserChars || 0))
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }

                    Label {
                        anchors.right: parent.right
                        text: qsTr("AI: %1 chars").arg(formatExactTokens(stats.totalAssistantChars || 0))
                        color: Theme.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }
                }
            }

            // Question categories
            SectionHeader {
                text: qsTr("Question categories")
                visible: statsPage.categoryList.length > 0
            }

            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingSmall
                visible: statsPage.categoryList.length > 0

                Repeater {
                    model: statsPage.categoryList

                    Item {
                        width: parent.width
                        height: Theme.fontSizeSmall + Theme.paddingMedium

                        Label {
                            id: catNameLabel
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * 0.3
                            text: categoryLabel(modelData.cat)
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.primaryColor
                            truncationMode: TruncationMode.Fade
                        }

                        Rectangle {
                            anchors {
                                left: catNameLabel.right
                                leftMargin: Theme.paddingMedium
                                verticalCenter: parent.verticalCenter
                            }
                            height: Theme.paddingMedium
                            radius: height / 2
                            color: categoryColor(modelData.cat)
                            width: (parent.width * 0.5) * statsPage.chartProgress
                                   * modelData.count / Math.max(1, statsPage.maxCategoryCount)
                        }

                        Label {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.count
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                        }
                    }
                }
            }

            // Who does the answering
            SectionHeader {
                text: qsTr("Providers and models")
                visible: statsPage.providerUsage.length > 0
            }

            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingSmall
                visible: statsPage.providerUsage.length > 0

                Item {
                    width: parent.width
                    height: topProviderCaption.height

                    Label {
                        id: topProviderCaption
                        anchors.left: parent.left
                        text: qsTr("Most used provider")
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                    }

                    Label {
                        anchors.right: parent.right
                        text: settingsManager.providerNameFor(statsPage.stats.topProvider || "")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.highlightColor
                    }
                }

                Item {
                    width: parent.width
                    height: topModelCaption.height
                    visible: (statsPage.stats.topModel || "") !== ""

                    Label {
                        id: topModelCaption
                        anchors.left: parent.left
                        text: qsTr("Most used model")
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                    }

                    Label {
                        anchors.left: topModelCaption.right
                        anchors.leftMargin: Theme.paddingMedium
                        anchors.right: parent.right
                        horizontalAlignment: Text.AlignRight
                        text: statsPage.stats.topModel || ""
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.highlightColor
                        truncationMode: TruncationMode.Fade
                    }
                }

                Label {
                    width: parent.width
                    text: qsTr("Answers per provider")
                    font.pixelSize: Theme.fontSizeTiny
                    color: Theme.secondaryColor
                }

                Repeater {
                    model: statsPage.providerUsage

                    Item {
                        width: parent.width
                        height: Theme.fontSizeSmall + Theme.paddingMedium

                        Label {
                            id: rowName
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * 0.35
                            text: settingsManager.providerNameFor(modelData.provider)
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.primaryColor
                            truncationMode: TruncationMode.Fade
                        }

                        Rectangle {
                            anchors {
                                left: rowName.right
                                leftMargin: Theme.paddingMedium
                                verticalCenter: parent.verticalCenter
                            }
                            height: Theme.paddingMedium
                            radius: height / 2
                            color: Theme.highlightColor
                            width: (parent.width * 0.45) * statsPage.chartProgress
                                   * modelData.count / Math.max(1, statsPage.maxProviderCount)
                        }

                        Label {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.count
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                        }
                    }
                }

                Label {
                    width: parent.width
                    visible: statsPage.modelAnswers.length > 0
                    text: qsTr("Answers per model")
                    font.pixelSize: Theme.fontSizeTiny
                    color: Theme.secondaryColor
                }

                Repeater {
                    model: statsPage.modelAnswers

                    Item {
                        width: parent.width
                        height: Theme.fontSizeSmall + Theme.paddingMedium

                        Label {
                            id: rowName
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * 0.45
                            text: modelData.model
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.primaryColor
                            truncationMode: TruncationMode.Fade
                        }

                        Rectangle {
                            anchors {
                                left: rowName.right
                                leftMargin: Theme.paddingMedium
                                verticalCenter: parent.verticalCenter
                            }
                            height: Theme.paddingMedium
                            radius: height / 2
                            color: Theme.secondaryHighlightColor
                            width: (parent.width * 0.35) * statsPage.chartProgress
                                   * modelData.count / Math.max(1, statsPage.maxModelCount)
                        }

                        Label {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.count
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                        }
                    }
                }

                // Counted from the answers, not from the token ledger, which
                // has no provider. Pre-2.3 answers carry a provider, no model.
                Label {
                    width: parent.width
                    text: qsTr("Counted from the answers themselves. Answers received before this app recorded models appear under their provider only.")
                    font.pixelSize: Theme.fontSizeTiny
                    color: Theme.secondaryColor
                    wrapMode: Text.WordWrap
                }
            }

            // Daily activity chart
            SectionHeader {
                text: qsTr("Last 14 days")
            }

            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingSmall

                Row {
                    id: dayBarsRow
                    width: parent.width
                    height: Theme.itemSizeLarge
                    spacing: Theme.paddingSmall / 2

                    Repeater {
                        model: statsPage.messagesPerDay

                        Item {
                            width: (dayBarsRow.width - dayBarsRow.spacing * 13) / 14
                            height: dayBarsRow.height

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                radius: 2
                                height: statsPage.maxPerDay > 0 && modelData > 0
                                        ? Math.max(6, parent.height * statsPage.chartProgress * modelData / statsPage.maxPerDay)
                                        : 6
                                color: modelData > 0
                                       ? Theme.rgba(Theme.highlightColor,
                                                    0.4 + 0.6 * modelData / statsPage.maxPerDay)
                                       : Theme.rgba(Theme.secondaryColor, 0.2)
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: dayStartLabel.height

                    Label {
                        id: dayStartLabel
                        anchors.left: parent.left
                        text: Qt.formatDate(new Date(Date.now() - 13 * 86400000), "dd/MM")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: statsPage.maxPerDay > 0
                              ? qsTr("Peak: %1 messages/day").arg(statsPage.maxPerDay)
                              : qsTr("No recent activity")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }

                    Label {
                        anchors.right: parent.right
                        text: qsTr("Today")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }
                }
            }

            // Token usage chart
            SectionHeader {
                text: qsTr("Tokens - last 14 days")
                visible: statsPage.maxTokensDay > 0
            }

            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingSmall
                visible: statsPage.maxTokensDay > 0

                Row {
                    id: tokenBarsRow
                    width: parent.width
                    height: Theme.itemSizeLarge
                    spacing: Theme.paddingSmall / 2

                    Repeater {
                        model: statsPage.tokensPerDay

                        Item {
                            width: (tokenBarsRow.width - tokenBarsRow.spacing * 13) / 14
                            height: tokenBarsRow.height

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                radius: 2
                                height: statsPage.maxTokensDay > 0 && modelData > 0
                                        ? Math.max(6, parent.height * statsPage.chartProgress * modelData / statsPage.maxTokensDay)
                                        : 6
                                color: modelData > 0
                                       ? Theme.rgba(Theme.highlightColor,
                                                    0.4 + 0.6 * modelData / statsPage.maxTokensDay)
                                       : Theme.rgba(Theme.secondaryColor, 0.2)
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: tokenPeakLabel.height

                    Label {
                        anchors.left: parent.left
                        text: Qt.formatDate(new Date(Date.now() - 13 * 86400000), "dd/MM")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }

                    Label {
                        id: tokenPeakLabel
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Peak: %1 tokens/day").arg(formatExactTokens(statsPage.maxTokensDay))
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }

                    Label {
                        anchors.right: parent.right
                        text: qsTr("Today")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }
                }
            }

            // Hourly activity chart
            SectionHeader {
                text: qsTr("Activity by hour")
                visible: statsPage.maxPerHour > 0
            }

            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingSmall
                visible: statsPage.maxPerHour > 0

                Row {
                    id: hourBarsRow
                    width: parent.width
                    height: Theme.itemSizeMedium
                    spacing: 2

                    Repeater {
                        model: statsPage.messagesPerHour

                        Item {
                            width: (hourBarsRow.width - hourBarsRow.spacing * 23) / 24
                            height: hourBarsRow.height

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                radius: 1
                                height: statsPage.maxPerHour > 0 && modelData > 0
                                        ? Math.max(4, parent.height * statsPage.chartProgress * modelData / statsPage.maxPerHour)
                                        : 4
                                color: modelData > 0
                                       ? Theme.rgba(Theme.highlightColor,
                                                    0.4 + 0.6 * modelData / statsPage.maxPerHour)
                                       : Theme.rgba(Theme.secondaryColor, 0.2)
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: hourStartLabel.height

                    Label {
                        id: hourStartLabel
                        anchors.left: parent.left
                        text: "0h"
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "12h"
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }

                    Label {
                        anchors.right: parent.right
                        text: "23h"
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }
                }
            }

            // Estimated spend
            SectionHeader {
                text: qsTr("Estimated cost")
                visible: statsPage.costList.length > 0
            }

            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingSmall
                visible: statsPage.costList.length > 0

                Repeater {
                    model: statsPage.costList

                    Item {
                        width: parent.width
                        height: Theme.fontSizeSmall + Theme.paddingMedium

                        Label {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * 0.55
                            text: modelData.model
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.primaryColor
                            truncationMode: TruncationMode.Fade
                        }

                        Label {
                            anchors.right: costValue.left
                            anchors.rightMargin: Theme.paddingMedium
                            anchors.verticalCenter: parent.verticalCenter
                            text: formatExactTokens(modelData.tokens)
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                        }

                        Label {
                            id: costValue
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: formatCost(modelData.cost)
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.highlightColor
                        }
                    }
                }

                Separator {
                    width: parent.width
                    color: Theme.rgba(Theme.secondaryColor, 0.3)
                }

                Item {
                    width: parent.width
                    height: totalCostLabel.height

                    Label {
                        id: totalCostLabel
                        anchors.left: parent.left
                        text: qsTr("Total")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.primaryColor
                    }

                    Label {
                        anchors.right: parent.right
                        text: formatCost(statsPage.totalCost())
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.highlightColor
                    }
                }

                Label {
                    width: parent.width
                    text: qsTr("Estimate based on public list prices, in US dollars. Only usage recorded by this app is counted - check your provider console for the real invoice.")
                    font.pixelSize: Theme.fontSizeTiny
                    color: Theme.secondaryColor
                    wrapMode: Text.WordWrap
                }
            }

            // Badges
            SectionHeader {
                text: qsTr("Badges")
                visible: (stats.totalMessages || 0) > 0
            }

            Grid {
                id: badgesGrid
                columns: 2
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                columnSpacing: Theme.paddingMedium
                rowSpacing: Theme.paddingMedium
                visible: (stats.totalMessages || 0) > 0

                Repeater {
                    model: statsPage.badges

                    Rectangle {
                        width: (badgesGrid.width - badgesGrid.columnSpacing) / 2
                        height: Theme.itemSizeLarge + Theme.paddingMedium
                        radius: Theme.paddingSmall
                        color: Theme.rgba(badgeColor(modelData.level), 0.15)
                        border.color: Theme.rgba(badgeColor(modelData.level), 0.5)
                        border.width: 1

                        Column {
                            anchors.centerIn: parent
                            width: parent.width - Theme.paddingMedium * 2

                            Label {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.tier
                                color: badgeColor(modelData.level)
                                font.pixelSize: Theme.fontSizeMedium
                                font.bold: true
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.name
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeExtraSmall
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.detail
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeTiny
                                truncationMode: TruncationMode.Fade
                            }
                        }
                    }
                }
            }

            // Most frequent words in assistant replies
            SectionHeader {
                text: qsTr("Top words in AI replies")
                visible: statsPage.topWords.length > 0
            }

            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingSmall
                visible: statsPage.topWords.length > 0

                Repeater {
                    model: statsPage.topWords

                    Item {
                        width: parent.width
                        height: Theme.fontSizeSmall + Theme.paddingMedium

                        Label {
                            id: wordLabel
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * 0.3
                            text: modelData.word
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.primaryColor
                            truncationMode: TruncationMode.Fade
                        }

                        Rectangle {
                            anchors {
                                left: wordLabel.right
                                leftMargin: Theme.paddingMedium
                                verticalCenter: parent.verticalCenter
                            }
                            height: Theme.paddingMedium
                            radius: height / 2
                            color: Theme.highlightColor
                            width: (parent.width * 0.5) * statsPage.chartProgress
                                   * modelData.count / Math.max(1, statsPage.topWords[0].count)
                        }

                        Label {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.count
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                        }
                    }
                }
            }

            // Records
            SectionHeader {
                text: qsTr("Records")
            }

            Column {
                width: parent.width

                DetailItem {
                    label: qsTr("Longest conversation")
                    value: stats.longestConvTitle
                           ? stats.longestConvTitle + " (" + stats.longestConvMessages + ")"
                           : qsTr("None")
                }

                DetailItem {
                    label: qsTr("Longest message")
                    value: qsTr("%n character(s)", "", stats.longestMessageLength || 0)
                }

                DetailItem {
                    label: qsTr("First message")
                    value: stats.firstMessageDate > 0
                           ? Qt.formatDateTime(new Date(stats.firstMessageDate), "dd/MM/yyyy")
                           : qsTr("Never")
                }

                DetailItem {
                    label: qsTr("Tokens this month")
                    value: formatExactTokens(stats.tokensThisMonth || 0)
                    visible: (stats.tokensThisMonth || 0) > 0
                }

                DetailItem {
                    label: qsTr("Prompt tokens")
                    value: "" + (stats.totalPromptTokens || 0)
                    visible: (stats.totalTokens || 0) > 0
                }

                DetailItem {
                    label: qsTr("Completion tokens")
                    value: "" + (stats.totalCompletionTokens || 0)
                    visible: (stats.totalTokens || 0) > 0
                }
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }
        }

        VerticalScrollDecorator {}
    }
}
