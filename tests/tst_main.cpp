#include <QtTest>
#include <QCoreApplication>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QDir>
#include <QFile>
#include <QStandardPaths>
#include <QJsonArray>
#include <QJsonObject>

#include "categories.h"
#include "conversationmodel.h"
#include "conversationmanager.h"
#include "mistralapi.h"
#include "providers.h"
#include "securestore.h"
#include "settingsmanager.h"

class TestConversationModel : public QObject
{
    Q_OBJECT

private slots:
    void addMessages()
    {
        ConversationModel model;
        QCOMPARE(model.rowCount(), 0);

        model.addUserMessage("hello");
        model.addAssistantMessage("hi there");
        QCOMPARE(model.rowCount(), 2);

        QJsonArray json = model.toJsonArray();
        QCOMPARE(json.at(0).toObject()["role"].toString(), QString("user"));
        QCOMPARE(json.at(0).toObject()["content"].toString(), QString("hello"));
        QCOMPARE(json.at(0).toObject()["pinned"].toBool(), false);
        QCOMPARE(json.at(1).toObject()["role"].toString(), QString("assistant"));
    }

    void updateLastAssistant()
    {
        ConversationModel model;
        model.addUserMessage("question");
        // No assistant message yet: update creates one
        model.updateLastAssistantMessage("partial");
        QCOMPARE(model.rowCount(), 2);
        model.updateLastAssistantMessage("partial answer");
        QCOMPARE(model.rowCount(), 2);
        QCOMPARE(model.getLastAssistantMessage(), QString("partial answer"));
    }

    void removeLastMessageIfEmpty()
    {
        ConversationModel model;
        model.addUserMessage("question");
        model.addAssistantMessage("");
        QCOMPARE(model.rowCount(), 2);
        model.removeLastMessageIfEmpty();
        QCOMPARE(model.rowCount(), 1);
        // Non-empty assistant message is kept
        model.addAssistantMessage("answer");
        model.removeLastMessageIfEmpty();
        QCOMPARE(model.rowCount(), 2);
    }

    void removeLastAssistantMessage()
    {
        ConversationModel model;
        model.addUserMessage("question");
        model.addAssistantMessage("answer");
        model.removeLastAssistantMessage();
        QCOMPARE(model.rowCount(), 1);
        // No-op when the last message is from the user
        model.removeLastAssistantMessage();
        QCOMPARE(model.rowCount(), 1);
    }

    void truncateFrom()
    {
        ConversationModel model;
        model.addUserMessage("one");
        model.addAssistantMessage("two");
        model.addUserMessage("three");
        model.addAssistantMessage("four");

        model.truncateFrom(10);  // out of range: no-op
        QCOMPARE(model.rowCount(), 4);
        model.truncateFrom(-1);
        QCOMPARE(model.rowCount(), 4);

        model.truncateFrom(2);
        QCOMPARE(model.rowCount(), 2);
        QCOMPARE(model.getLastAssistantMessage(), QString("two"));
    }

    void togglePinned()
    {
        ConversationModel model;
        model.addUserMessage("pin me");
        model.togglePinned(0);
        QCOMPARE(model.toJsonArray().at(0).toObject()["pinned"].toBool(), true);
        model.togglePinned(0);
        QCOMPARE(model.toJsonArray().at(0).toObject()["pinned"].toBool(), false);
        model.togglePinned(42);  // out of range: no crash
    }

    void imagePathRoundTrip()
    {
        ConversationModel model;
        model.addUserMessage("look at this", "/tmp/photo.jpg");
        QCOMPARE(model.toJsonArray().at(0).toObject()["imagePath"].toString(),
                 QString("/tmp/photo.jpg"));
        QCOMPARE(model.getLastUserImagePath(), QString("/tmp/photo.jpg"));
    }

    void lastUserMessage()
    {
        ConversationModel model;
        QCOMPARE(model.getLastUserMessage(), QString());
        model.addUserMessage("first");
        model.addAssistantMessage("answer");
        model.addUserMessage("second");
        QCOMPARE(model.getLastUserMessage(), QString("second"));
    }

    void lastAssistantSkipsEmpty()
    {
        ConversationModel model;
        model.addUserMessage("q1");
        model.addAssistantMessage("first answer");
        model.addUserMessage("q2");
        model.addAssistantMessage("");
        QCOMPARE(model.getLastAssistantMessage(), QString("first answer"));
    }
};

class TestMistralAPI : public QObject
{
    Q_OBJECT

private slots:
    void streamingDelta()
    {
        MistralAPI api;
        QSignalSpy spy(&api, SIGNAL(streamingResponse(QString)));

        api.processStreamData("data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}\n");
        QCOMPARE(spy.count(), 1);
        QCOMPARE(spy.at(0).at(0).toString(), QString("Hello"));
    }

    void utf8SplitAcrossChunks()
    {
        MistralAPI api;
        QSignalSpy spy(&api, SIGNAL(streamingResponse(QString)));

        QByteArray line = QString::fromUtf8("data: {\"choices\":[{\"delta\":{\"content\":\"caf\xC3\xA9\"}}]}\n").toUtf8();
        // Split in the middle of the two-byte e-acute sequence
        int cut = line.indexOf("\xC3") + 1;
        api.processStreamData(line.left(cut));
        QCOMPARE(spy.count(), 0);  // incomplete line buffered
        api.processStreamData(line.mid(cut));
        QCOMPARE(spy.count(), 1);
        QCOMPARE(spy.at(0).at(0).toString(), QString::fromUtf8("caf\xC3\xA9"));
    }

    void doneMarkerIgnored()
    {
        MistralAPI api;
        QSignalSpy spy(&api, SIGNAL(streamingResponse(QString)));
        api.processStreamData("data: [DONE]\n");
        QCOMPARE(spy.count(), 0);
    }

    void usageChunk()
    {
        MistralAPI api;
        QSignalSpy contentSpy(&api, SIGNAL(streamingResponse(QString)));
        QSignalSpy usageSpy(&api, SIGNAL(usageReceived(int,int)));

        api.processStreamData("data: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}],"
                              "\"usage\":{\"prompt_tokens\":25,\"completion_tokens\":89,\"total_tokens\":114}}\n");
        QCOMPARE(contentSpy.count(), 0);
        QCOMPARE(usageSpy.count(), 1);
        QCOMPARE(usageSpy.at(0).at(0).toInt(), 25);
        QCOMPARE(usageSpy.at(0).at(1).toInt(), 89);
    }

    void malformedLinesIgnored()
    {
        MistralAPI api;
        QSignalSpy spy(&api, SIGNAL(streamingResponse(QString)));
        api.processStreamData("garbage\n");
        api.processStreamData("data: {broken json\n");
        api.processStreamData(": comment\n");
        api.processStreamData("\n\n");
        QCOMPARE(spy.count(), 0);
    }

    void multipleLinesOneChunk()
    {
        MistralAPI api;
        QSignalSpy spy(&api, SIGNAL(streamingResponse(QString)));
        api.processStreamData("data: {\"choices\":[{\"delta\":{\"content\":\"a\"}}]}\n"
                              "data: {\"choices\":[{\"delta\":{\"content\":\"b\"}}]}\n"
                              "data: [DONE]\n");
        QCOMPARE(spy.count(), 2);
        QCOMPARE(spy.at(0).at(0).toString(), QString("a"));
        QCOMPARE(spy.at(1).at(0).toString(), QString("b"));
    }
};

class TestConversationManager : public QObject
{
    Q_OBJECT

private slots:
    void saveAndReloadConversation()
    {
        ConversationManager manager;
        manager.purgeAllConversations();

        QString id = manager.currentConversationId();
        QVERIFY(!id.isEmpty());

        ConversationModel *model = manager.currentConversation();
        model->addUserMessage("hello", "/tmp/img.jpg");
        model->addAssistantMessage("hi");
        model->togglePinned(1);
        manager.saveCurrentConversation();
        manager.updateCurrentConversationTitle("My chat");
        manager.updateCurrentConversationCategory("code");

        // Switch away and back: content must survive the round trip
        manager.createNewConversation();
        manager.loadConversation(id);

        QCOMPARE(manager.currentConversation()->rowCount(), 2);
        QJsonArray json = manager.currentConversation()->toJsonArray();
        QCOMPARE(json.at(0).toObject()["imagePath"].toString(), QString("/tmp/img.jpg"));
        QCOMPARE(json.at(1).toObject()["pinned"].toBool(), true);

        QVariantMap details = manager.getConversationDetails(id).toMap();
        QCOMPARE(details["title"].toString(), QString("My chat"));

        QVariantMap stats = manager.getConversationStatistics(id);
        QCOMPARE(stats["category"].toString(), QString("code"));
        QCOMPARE(stats["messageCount"].toInt(), 2);
    }

    void conversationIsPinnedToItsProvider()
    {
        ConversationManager manager;
        manager.purgeAllConversations();
        manager.setDefaultProvider("groq");

        // The conversation that exists already has no messages, so it follows
        manager.createNewConversation();
        const QString groqId = manager.currentConversationId();
        QCOMPARE(manager.currentProviderId(), QString("groq"));

        manager.currentConversation()->addUserMessage("hello");
        manager.saveCurrentConversation();

        // Changing the default is for new conversations only
        manager.setDefaultProvider("mistral");
        manager.loadConversation(groqId);
        QCOMPARE(manager.currentProviderId(), QString("groq"));

        manager.createNewConversation();
        QCOMPARE(manager.currentProviderId(), QString("mistral"));

        // And the pin survives a restart
        manager.saveCurrentConversation();
        ConversationManager reopened;
        QCOMPARE(reopened.conversationProvider(groqId), QString("groq"));
    }

    void movingAConversationDropsItsModelOverride()
    {
        ConversationManager manager;
        manager.purgeAllConversations();
        manager.setDefaultProvider("mistral");
        manager.createNewConversation();

        const QString id = manager.currentConversationId();
        manager.setConversationOverrides(id, "mistral-large-latest", "Be brief");

        manager.setConversationProvider(id, "groq");
        QCOMPARE(manager.conversationProvider(id), QString("groq"));

        const QVariantMap overrides = manager.getConversationOverrides(id);
        // The model belonged to the provider we left; the prompt did not
        QCOMPARE(overrides["model"].toString(), QString());
        QCOMPARE(overrides["systemPrompt"].toString(), QString("Be brief"));
    }

    void answersRecordWhoProducedThem()
    {
        ConversationManager manager;
        manager.purgeAllConversations();
        manager.setDefaultProvider("groq");
        manager.createNewConversation();

        const QString id = manager.currentConversationId();
        manager.currentConversation()->addUserMessage("hello");
        manager.currentConversation()->addAssistantMessage(
                    "hi", "llama-3.3-70b-versatile", "groq");
        manager.saveCurrentConversation();

        manager.createNewConversation();
        manager.loadConversation(id);

        const QJsonArray json = manager.currentConversation()->toJsonArray();
        // The user turn stays as it was, the answer carries its origin
        QVERIFY(!json.at(0).toObject().contains("provider"));
        QCOMPARE(json.at(1).toObject()["provider"].toString(), QString("groq"));
        QCOMPARE(json.at(1).toObject()["model"].toString(),
                 QString("llama-3.3-70b-versatile"));
    }

    void preProviderConversationsAreStampedMistral()
    {
        ConversationManager manager;
        manager.purgeAllConversations();
        const QString dir = QStandardPaths::writableLocation(
                    QStandardPaths::AppDataLocation) + "/conversations";
        QVERIFY(QDir().mkpath(dir));

        // A file exactly as 2.2 wrote it: no provider anywhere
        const QString id = "11111111-2222-3333-4444-555555555555";
        QFile file(dir + "/" + id + ".json");
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write("{\"id\":\"" + id.toUtf8() + "\",\"title\":\"Old chat\","
                   "\"category\":\"code\",\"createdAt\":1000,\"updatedAt\":2000,"
                   "\"messages\":["
                   "{\"role\":\"user\",\"content\":\"q\",\"timestamp\":1000},"
                   "{\"role\":\"assistant\",\"content\":\"a\",\"timestamp\":1001}]}");
        file.close();

        ConversationManager reopened;
        // Only Mistral existed back then, so the answer's origin is known even
        // though its model is not
        QCOMPARE(reopened.conversationProvider(id), QString("mistral"));

        reopened.loadConversation(id);
        const QJsonArray json = reopened.currentConversation()->toJsonArray();
        QCOMPARE(json.count(), 2);
        QVERIFY(!json.at(0).toObject().contains("provider"));
        QCOMPARE(json.at(1).toObject()["provider"].toString(), QString("mistral"));
        QVERIFY(!json.at(1).toObject().contains("model"));
    }

    void statisticsRankProvidersAndModels()
    {
        ConversationManager manager;
        manager.purgeAllConversations();
        manager.setDefaultProvider("mistral");

        ConversationModel *model = manager.currentConversation();
        model->addUserMessage("one");
        model->addAssistantMessage("a", "mistral-small-latest", "mistral");
        model->addUserMessage("two");
        model->addAssistantMessage("b", "mistral-small-latest", "mistral");
        model->addUserMessage("three");
        model->addAssistantMessage("c", "llama-3.3-70b-versatile", "groq");
        // An answer from before 2.3: provider known, model never recorded
        model->addUserMessage("four");
        model->addAssistantMessage("d", QString(), "mistral");
        manager.saveCurrentConversation();

        const QVariantMap stats = manager.getStatistics();
        QCOMPARE(stats["topProvider"].toString(), QString("mistral"));
        QCOMPARE(stats["topProviderCount"].toInt(), 3);
        QCOMPARE(stats["topModel"].toString(), QString("mistral-small-latest"));
        QCOMPARE(stats["topModelCount"].toInt(), 2);

        const QVariantList providers = stats["providerUsage"].toList();
        QCOMPARE(providers.count(), 2);
        // Most used first, and the groq answer is not lost
        QCOMPARE(providers.at(1).toMap()["provider"].toString(), QString("groq"));
        QCOMPARE(providers.at(1).toMap()["count"].toInt(), 1);

        // The model-less answer counts for its provider but not as a model
        const QVariantList models = stats["modelAnswers"].toList();
        QCOMPARE(models.count(), 2);
        int total = 0;
        for (int i = 0; i < models.count(); ++i) {
            total += models.at(i).toMap()["count"].toInt();
        }
        QCOMPARE(total, 3);
    }

    void historyListReportsTheModelThatAnswered()
    {
        ConversationManager manager;
        manager.purgeAllConversations();
        manager.setDefaultProvider("groq");
        manager.createNewConversation();

        const QString id = manager.currentConversationId();
        manager.currentConversation()->addUserMessage("hi");
        manager.currentConversation()->addAssistantMessage(
                    "hello", "llama-3.3-70b-versatile", "groq");
        manager.saveCurrentConversation();

        const QJsonArray list = manager.getConversationsList();
        bool found = false;
        for (int i = 0; i < list.count(); ++i) {
            const QJsonObject obj = list.at(i).toObject();
            if (obj["id"].toString() != id) {
                continue;
            }
            found = true;
            QCOMPARE(obj["provider"].toString(), QString("groq"));
            QCOMPARE(obj["lastModel"].toString(), QString("llama-3.3-70b-versatile"));
            // A role called "model" would shadow the delegate's model object
            QVERIFY(!obj.contains("model"));
        }
        QVERIFY(found);
    }

    void markdownExport()
    {
        ConversationManager manager;
        manager.purgeAllConversations();

        QString id = manager.currentConversationId();
        manager.currentConversation()->addUserMessage("What is Qt?");
        manager.currentConversation()->addAssistantMessage("A C++ framework.");
        manager.saveCurrentConversation();
        manager.updateCurrentConversationTitle("Qt question");

        QString md = manager.conversationToMarkdown(id);
        QVERIFY(md.startsWith("# Qt question"));
        QVERIFY(md.contains("## User"));
        QVERIFY(md.contains("What is Qt?"));
        QVERIFY(md.contains("## Assistant"));
        QVERIFY(md.contains("A C++ framework."));

        QCOMPARE(manager.conversationToMarkdown("no-such-id"), QString());
    }

    void pinnedMessagesAcrossConversations()
    {
        ConversationManager manager;
        manager.purgeAllConversations();

        manager.currentConversation()->addUserMessage("pin this");
        manager.currentConversation()->togglePinned(0);
        manager.saveCurrentConversation();

        QVariantList pins = manager.getPinnedMessages();
        QCOMPARE(pins.count(), 1);
        QCOMPARE(pins.at(0).toMap()["content"].toString(), QString("pin this"));
        QCOMPARE(pins.at(0).toMap()["messageIndex"].toInt(), 0);
    }

    void funStatsGhostAndLongest()
    {
        ConversationManager manager;
        manager.purgeAllConversations();

        // One abandoned conversation: single user message
        manager.currentConversation()->addUserMessage("abandoned question");
        manager.saveCurrentConversation();

        manager.createNewConversation();
        manager.currentConversation()->addUserMessage(QString(500, 'x'));
        manager.currentConversation()->addAssistantMessage("short reply");
        manager.currentConversation()->addUserMessage("thanks");
        manager.currentConversation()->addAssistantMessage("welcome welcome welcome welcome");
        manager.saveCurrentConversation();

        QVariantMap fun = manager.getFunStats();
        QCOMPARE(fun["ghostCount"].toInt(), 1);
        QCOMPARE(fun["longestUserChars"].toInt(), 500);
        QVERIFY(fun["topWords"].toList().count() > 0);
        QCOMPARE(fun["topWords"].toList().at(0).toMap()["word"].toString(),
                 QString("welcome"));
    }

    void tokenUsageAccumulates()
    {
        ConversationManager manager;
        manager.purgeAllConversations();

        QString id = manager.currentConversationId();
        qint64 before = manager.getStatistics()["totalTokens"].toLongLong();

        manager.addTokenUsage(10, 20);
        manager.addTokenUsage(5, 5);
        manager.addTokenUsage(0, 0);  // ignored

        QCOMPARE(manager.getStatistics()["totalTokens"].toLongLong(), before + 40);
        QCOMPARE(manager.getConversationStatistics(id)["totalTokens"].toLongLong(), qint64(40));

        QVariantList perDay = manager.getStatistics()["tokensPerDay"].toList();
        QCOMPARE(perDay.count(), 14);
        QVERIFY(perDay.last().toInt() >= 40);
    }

    void categoryCounting()
    {
        ConversationManager manager;
        manager.purgeAllConversations();

        manager.currentConversation()->addUserMessage("write me a poem");
        manager.saveCurrentConversation();
        manager.updateCurrentConversationCategory("writing");

        QVariantMap counts = manager.getStatistics()["categoryCounts"].toMap();
        QCOMPARE(counts["writing"].toInt(), 1);
    }

    void unknownCategoryFallsBackToClassifier()
    {
        ConversationManager manager;
        manager.purgeAllConversations();

        QString id = manager.currentConversationId();
        manager.currentConversation()->addUserMessage(
                    "my python script raises an exception, help me debug the stacktrace");
        manager.saveCurrentConversation();

        // The model answering "other" must not win over an obvious topic
        manager.updateCurrentConversationCategory("other");
        QString category = manager.getConversationStatistics(id)["category"].toString();
        QVERIFY(category != "other");

        // An unknown label is rejected the same way
        manager.updateCurrentConversationCategory("not-a-category");
        QVERIFY(manager.getConversationStatistics(id)["category"].toString() != "not-a-category");
    }

    void recategorizeOnlyTouchesUnlabelled()
    {
        ConversationManager manager;
        manager.purgeAllConversations();

        QString taggedId = manager.currentConversationId();
        manager.currentConversation()->addUserMessage("a recipe for bread with a good sauce");
        manager.saveCurrentConversation();
        manager.updateCurrentConversationCategory("cooking");

        manager.createNewConversation();
        QString untaggedId = manager.currentConversationId();
        manager.currentConversation()->addUserMessage(
                    "book a flight and a hotel for my trip, I need a visa and an itinerary");
        manager.saveCurrentConversation();

        QCOMPARE(manager.recategorizeConversations(), 1);
        QCOMPARE(manager.getConversationStatistics(taggedId)["category"].toString(),
                 QString("cooking"));
        QCOMPARE(manager.getConversationStatistics(untaggedId)["category"].toString(),
                 QString("travel"));

        // Nothing left to do on a second pass
        QCOMPARE(manager.recategorizeConversations(), 0);
    }

    void buildApiMessagesDropsPendingBubble()
    {
        ConversationManager manager;
        manager.purgeAllConversations();

        manager.currentConversation()->addUserMessage("question");
        manager.currentConversation()->addAssistantMessage("");

        QVariantList payload = manager.buildApiMessages(0, QString());
        QCOMPARE(payload.count(), 1);
        QCOMPARE(payload.at(0).toMap()["role"].toString(), QString("user"));
        QCOMPARE(payload.at(0).toMap()["content"].toString(), QString("question"));
    }

    void buildApiMessagesPrependsSystemPrompt()
    {
        ConversationManager manager;
        manager.purgeAllConversations();

        manager.currentConversation()->addUserMessage("hi");

        QVariantList payload = manager.buildApiMessages(0, "  be brief  ");
        QCOMPARE(payload.count(), 2);
        QCOMPARE(payload.at(0).toMap()["role"].toString(), QString("system"));
        QCOMPARE(payload.at(0).toMap()["content"].toString(), QString("be brief"));

        // A blank prompt adds nothing
        QCOMPARE(manager.buildApiMessages(0, "   ").count(), 1);
    }

    void buildApiMessagesTrimsToContextLimit()
    {
        ConversationManager manager;
        manager.purgeAllConversations();

        ConversationModel *model = manager.currentConversation();
        for (int i = 0; i < 5; ++i) {
            model->addUserMessage(QString("q%1").arg(i));
            model->addAssistantMessage(QString("a%1").arg(i));
        }

        QCOMPARE(manager.trimmedMessageCount(0), 0);
        QCOMPARE(manager.buildApiMessages(0, QString()).count(), 10);

        // Keep the last 4, and the window must open on a user turn
        QCOMPARE(manager.trimmedMessageCount(4), 6);
        QVariantList payload = manager.buildApiMessages(4, QString());
        QCOMPARE(payload.count(), 4);
        QCOMPARE(payload.at(0).toMap()["role"].toString(), QString("user"));
        QCOMPARE(payload.at(0).toMap()["content"].toString(), QString("q3"));

        // An odd limit would start on an assistant turn: that one is dropped
        payload = manager.buildApiMessages(5, QString());
        QCOMPARE(payload.at(0).toMap()["role"].toString(), QString("user"));
    }

    void conversationOverridesRoundTrip()
    {
        ConversationManager manager;
        manager.purgeAllConversations();

        QString id = manager.currentConversationId();
        QVariantMap empty = manager.getConversationOverrides(id);
        QCOMPARE(empty["model"].toString(), QString());
        QCOMPARE(empty["systemPrompt"].toString(), QString());

        manager.setConversationOverrides(id, "mistral-large-latest", " talk like a pirate ");
        manager.currentConversation()->addUserMessage("ahoy");
        manager.saveCurrentConversation();

        // Survives a switch away and back
        manager.createNewConversation();
        manager.loadConversation(id);

        QVariantMap overrides = manager.getConversationOverrides(id);
        QCOMPARE(overrides["model"].toString(), QString("mistral-large-latest"));
        QCOMPARE(overrides["systemPrompt"].toString(), QString("talk like a pirate"));
    }

    void listedConversationsCarryNoReservedRole()
    {
        ConversationManager manager;
        manager.purgeAllConversations();

        manager.currentConversation()->addUserMessage("hello");
        manager.saveCurrentConversation();
        manager.setConversationOverrides(manager.currentConversationId(),
                                         "mistral-large-latest", QString());

        // These objects are appended to a QML ListModel. A role named "model"
        // shadows the delegate's own model object and turns every other lookup
        // into undefined, which is how 2.1.0 lost all its conversation titles.
        QJsonObject entry = manager.getConversationsList().at(0).toObject();
        QVERIFY(!entry.contains("model"));
        QVERIFY(entry.contains("title"));
        QVERIFY(entry.contains("id"));
    }

    void conversationDigestCoversBothSpeakers()
    {
        ConversationManager manager;
        manager.purgeAllConversations();

        QString id = manager.currentConversationId();
        QCOMPARE(manager.conversationDigest(id), QString());

        manager.currentConversation()->addUserMessage("how do I mount a btrfs volume?");
        manager.currentConversation()->addAssistantMessage("Use the mount command.");
        manager.saveCurrentConversation();

        QString digest = manager.conversationDigest(id);
        QVERIFY(digest.contains("User: how do I mount a btrfs volume?"));
        QVERIFY(digest.contains("Assistant: Use the mount command."));

        // Long conversations stay bounded
        for (int i = 0; i < 50; ++i) {
            manager.currentConversation()->addUserMessage(QString(600, 'x'));
        }
        manager.saveCurrentConversation();
        QVERIFY(manager.conversationDigest(id).length() <= 2000);

        QCOMPARE(manager.conversationDigest("no-such-id"), QString());
    }

    void renameByIdWorksForAnyConversation()
    {
        ConversationManager manager;
        manager.purgeAllConversations();

        QString first = manager.currentConversationId();
        manager.currentConversation()->addUserMessage("first");
        manager.saveCurrentConversation();

        manager.createNewConversation();
        manager.currentConversation()->addUserMessage("second");
        manager.saveCurrentConversation();

        // Renaming a conversation that is not the current one must work
        manager.renameConversation(first, "  Renamed from elsewhere  ");
        QCOMPARE(manager.getConversationOverrides(first)["title"].toString(),
                 QString("Renamed from elsewhere"));

        // And survive a reload from disk
        manager.loadConversation(first);
        QCOMPARE(manager.getConversationDetails(first).toMap()["title"].toString(),
                 QString("Renamed from elsewhere"));
    }

    void streamingLandsWithoutAnyUi()
    {
        // The chat page is popped whenever the user swipes back to the
        // history, so the whole streaming lifecycle has to work with no QML
        // attached at all.
        MistralAPI api;
        ConversationManager manager;
        manager.purgeAllConversations();
        manager.bindApi(&api);

        const QString id = manager.currentConversationId();
        manager.currentConversation()->addUserMessage("question");

        QVERIFY(QMetaObject::invokeMethod(&api, "messageSent"));
        QCOMPARE(manager.currentConversation()->rowCount(), 2);
        QCOMPARE(manager.streamingConversationId(), id);

        QVERIFY(QMetaObject::invokeMethod(&api, "streamingResponse",
                                          Q_ARG(QString, "Hel")));
        QVERIFY(QMetaObject::invokeMethod(&api, "streamingResponse",
                                          Q_ARG(QString, "lo")));
        // Deltas are coalesced, so give the throttle timer a chance to fire
        QTest::qWait(250);
        QCOMPARE(manager.currentConversation()->getLastAssistantMessage(),
                 QString("Hello"));

        QVERIFY(QMetaObject::invokeMethod(&api, "responseCompleted"));
        QCOMPARE(manager.streamingConversationId(), QString());

        QJsonObject entry = manager.getConversationsList().at(0).toObject();
        QCOMPARE(entry["id"].toString(), id);
        QCOMPARE(entry["messageCount"].toInt(), 2);
        QVERIFY(entry["unread"].toBool());

        manager.markConversationRead(id);
        QVERIFY(!manager.getConversationsList().at(0).toObject()["unread"].toBool());

        // Unknown ids are ignored rather than crashing
        manager.markConversationRead("no-such-id");
    }

    void answerNeverLeaksIntoAnotherConversation()
    {
        // ConversationModel is a single reused object. Switching conversation
        // mid-response used to make the rest of the answer land in - and be
        // saved into - whatever was opened next.
        MistralAPI api;
        ConversationManager manager;
        manager.purgeAllConversations();
        manager.bindApi(&api);

        const QString asking = manager.currentConversationId();
        manager.currentConversation()->addUserMessage("question in A");
        manager.saveCurrentConversation();

        QVERIFY(QMetaObject::invokeMethod(&api, "messageSent"));
        QVERIFY(QMetaObject::invokeMethod(&api, "streamingResponse",
                                          Q_ARG(QString, "first half ")));
        QTest::qWait(250);

        // The user walks off to an unrelated conversation
        manager.createNewConversation();
        const QString other = manager.currentConversationId();
        manager.currentConversation()->addUserMessage("unrelated question");
        manager.saveCurrentConversation();

        QVERIFY(QMetaObject::invokeMethod(&api, "streamingResponse",
                                          Q_ARG(QString, "second half")));
        QTest::qWait(250);

        // Nothing from the answer may show up here
        QCOMPARE(manager.currentConversation()->rowCount(), 1);
        QCOMPARE(manager.currentConversation()->getLastAssistantMessage(), QString());

        QVERIFY(QMetaObject::invokeMethod(&api, "responseCompleted"));

        // The other conversation is untouched
        QCOMPARE(manager.getConversationStatistics(other)["messageCount"].toInt(), 1);
        QCOMPARE(manager.currentConversation()->rowCount(), 1);

        // And the full answer landed where it was asked
        manager.loadConversation(asking);
        QCOMPARE(manager.currentConversation()->rowCount(), 2);
        QCOMPARE(manager.currentConversation()->getLastAssistantMessage(),
                 QString("first half second half"));
    }

    void returningMidStreamShowsTheLatestText()
    {
        MistralAPI api;
        ConversationManager manager;
        manager.purgeAllConversations();
        manager.bindApi(&api);

        const QString asking = manager.currentConversationId();
        manager.currentConversation()->addUserMessage("question");
        manager.saveCurrentConversation();

        QVERIFY(QMetaObject::invokeMethod(&api, "messageSent"));
        QVERIFY(QMetaObject::invokeMethod(&api, "streamingResponse",
                                          Q_ARG(QString, "partial")));
        QTest::qWait(250);

        manager.createNewConversation();
        QVERIFY(QMetaObject::invokeMethod(&api, "streamingResponse",
                                          Q_ARG(QString, " and more")));
        QTest::qWait(250);

        // Coming back must show everything buffered so far, not the snapshot
        // taken when leaving
        manager.loadConversation(asking);
        QCOMPARE(manager.currentConversation()->getLastAssistantMessage(),
                 QString("partial and more"));

        QVERIFY(QMetaObject::invokeMethod(&api, "responseCompleted"));
    }

    void cancelledRequestLeavesNoEmptyBubble()
    {
        MistralAPI api;
        ConversationManager manager;
        manager.purgeAllConversations();
        manager.bindApi(&api);

        manager.currentConversation()->addUserMessage("question");
        QVERIFY(QMetaObject::invokeMethod(&api, "messageSent"));
        QCOMPARE(manager.currentConversation()->rowCount(), 2);

        // No content ever arrives: the placeholder must go, and nothing is
        // reported as unread
        QVERIFY(QMetaObject::invokeMethod(&api, "responseCompleted"));
        QCOMPARE(manager.currentConversation()->rowCount(), 1);

        QJsonObject entry = manager.getConversationsList().at(0).toObject();
        QVERIFY(entry["unread"].toBool());   // the question itself is still there
        QCOMPARE(entry["messageCount"].toInt(), 1);
    }

    void unreadFlagSurvivesReload()
    {
        MistralAPI api;
        {
            ConversationManager manager;
            manager.purgeAllConversations();
            manager.bindApi(&api);
            manager.currentConversation()->addUserMessage("question");
            QVERIFY(QMetaObject::invokeMethod(&api, "messageSent"));
            QVERIFY(QMetaObject::invokeMethod(&api, "streamingResponse",
                                              Q_ARG(QString, "answer")));
            QTest::qWait(250);
            QVERIFY(QMetaObject::invokeMethod(&api, "responseCompleted"));
        }

        ConversationManager reopened;
        QVERIFY(reopened.getConversationsList().at(0).toObject()["unread"].toBool());
    }

    void deletedConversationLeavesNoFile()
    {
        ConversationManager manager;
        manager.purgeAllConversations();

        manager.currentConversation()->addUserMessage("throwaway");
        manager.saveCurrentConversation();
        QVERIFY(manager.getStorageSize() > 0);

        manager.createNewConversation();
        int before = manager.conversationCount();
        manager.deleteConversation(manager.getConversationsList()
                                   .at(before - 1).toObject()["id"].toString());
        QCOMPARE(manager.conversationCount(), before - 1);
    }
};

class TestCategories : public QObject
{
    Q_OBJECT

private slots:
    void identifiersAreValidated()
    {
        QVERIFY(Categories::isValid("code"));
        QVERIFY(Categories::isValid("other"));
        QVERIFY(!Categories::isValid("nonsense"));
        QVERIFY(!Categories::isValid(""));

        // "other" is offered but must be the last resort
        QVERIFY(Categories::all().count() > 20);
        QCOMPARE(Categories::all().last(), QString("other"));
    }

    void classifiesObviousTopics()
    {
        QCOMPARE(Categories::classify(
                     "write a python function to loop over an array"), QString("code"));
        QCOMPARE(Categories::classify(
                     "quelle recette de sauce pour des pates au four"), QString("cooking"));
        QCOMPARE(Categories::classify(
                     "translate this sentence into English, traduction"), QString("translation"));
    }

    void classifierIgnoresAccentsAndCase()
    {
        // Same sentence with and without accents must land on the same label
        QCOMPARE(Categories::classify(QString::fromUtf8("Ma dépense, mon budget et mes impôts")),
                 Categories::classify("Ma depense, mon budget et mes impots"));
    }

    void refusesToGuessOnThinInput()
    {
        QCOMPARE(Categories::classify(""), QString());
        QCOMPARE(Categories::classify("   "), QString());
        QCOMPARE(Categories::classify("ok merci"), QString());
    }
};

class TestSecureStore : public QObject
{
    Q_OBJECT

private slots:
    void roundTrip()
    {
        const QString secret = QString::fromUtf8("sk-ünïcode-key-1234567890");
        const QString encoded = SecureStore::obfuscate(secret);

        QVERIFY(!encoded.isEmpty());
        QVERIFY(!encoded.contains(secret));
        QCOMPARE(SecureStore::deobfuscate(encoded), secret);
    }

    void emptyInputStaysEmpty()
    {
        QCOMPARE(SecureStore::obfuscate(QString()), QString());
        QCOMPARE(SecureStore::deobfuscate(QString()), QString());
    }

    void plainTextPassesThrough()
    {
        // How a key written before this scheme existed is migrated
        QCOMPARE(SecureStore::deobfuscate("plain-api-key"), QString("plain-api-key"));
    }

    void corruptPayloadIsRejected()
    {
        QString encoded = SecureStore::obfuscate("secret");
        // Flip a payload character, past the 4-byte marker: the checksum must
        // catch it rather than hand back a mangled key
        const int pos = 5;
        QVERIFY(encoded.length() > pos);
        QChar original = encoded.at(pos);
        encoded.replace(pos, 1, original == QChar('A') ? QChar('B') : QChar('A'));
        QCOMPARE(SecureStore::deobfuscate(encoded), QString());
    }
};

class TestSettingsManager : public QObject
{
    Q_OBJECT

private slots:
    void apiKeyIsNotStoredInClearText()
    {
        {
            SettingsManager settings;
            settings.setApiKey("sk-test-secret-value");
            QCOMPARE(settings.apiKey(), QString("sk-test-secret-value"));
        }

        // Reread from disk: the key comes back, the file does not contain it
        SettingsManager reopened;
        QCOMPARE(reopened.apiKey(), QString("sk-test-secret-value"));

        QSettings raw("harbour-sailcat", "SailCat");
        QVERIFY(!raw.contains("apiKey"));
        QVERIFY(!raw.value("providers/mistral/apiKeyEnc").toString()
                .contains("sk-test-secret-value"));

        reopened.clearApiKey();
        QVERIFY(!reopened.hasApiKey());
    }

    void legacyPlainKeyIsMigrated()
    {
        {
            SettingsManager settings;
            settings.clearApiKey();
        }
        // Simulate a pre-2.1 install: no provider entry, key in clear text
        {
            QSettings raw("harbour-sailcat", "SailCat");
            raw.remove("provider");
            raw.remove("providers");
            raw.setValue("apiKey", "sk-legacy-key");
            raw.setValue("modelName", "mistral-large-latest");
            raw.sync();
        }

        SettingsManager migrated;
        QCOMPARE(migrated.apiKey(), QString("sk-legacy-key"));
        // The provider it belonged to is Mistral, and the model follows it
        QCOMPARE(migrated.providerId(), QString("mistral"));
        QCOMPARE(migrated.modelName(), QString("mistral-large-latest"));

        QSettings raw("harbour-sailcat", "SailCat");
        QVERIFY(!raw.contains("apiKey"));
        QVERIFY(!raw.contains("apiKeyEnc"));
        QVERIFY(!raw.value("providers/mistral/apiKeyEnc").toString().isEmpty());
    }

    void eachProviderKeepsItsOwnKey()
    {
        SettingsManager settings;
        settings.setProviderId("mistral");
        settings.setApiKey("sk-mistral");
        settings.setProviderId("groq");
        // Switching provider must not carry the previous key over
        QCOMPARE(settings.apiKey(), QString());
        settings.setApiKey("gsk-groq");

        settings.setProviderId("mistral");
        QCOMPARE(settings.apiKey(), QString("sk-mistral"));
        settings.setProviderId("groq");
        QCOMPARE(settings.apiKey(), QString("gsk-groq"));

        // And they survive a restart, still separately
        SettingsManager reopened;
        QCOMPARE(reopened.providerId(), QString("groq"));
        QCOMPARE(reopened.apiKey(), QString("gsk-groq"));

        reopened.clearApiKey();
        reopened.setProviderId("mistral");
        reopened.clearApiKey();
    }

    void unknownProviderFallsBackToDefault()
    {
        SettingsManager settings;
        settings.setProviderId("definitely-not-a-provider");
        QCOMPARE(settings.providerId(), Providers::defaultId());
    }

    void customEndpointNeedsAnAddress()
    {
        SettingsManager settings;
        settings.setProviderId("custom");
        settings.setCustomBaseUrl("");
        // No key required, but nowhere to send the request either
        QVERIFY(!settings.hasApiKey());

        settings.setCustomBaseUrl("http://192.168.1.10:11434/v1/");
        // The trailing slash goes: callers append "/chat/completions"
        QCOMPARE(settings.providerBaseUrl(), QString("http://192.168.1.10:11434/v1"));
        QVERIFY(settings.hasApiKey());

        settings.setProviderId("mistral");
    }

    void modelOverrideDoesNotFollowToAnotherProvider()
    {
        SettingsManager settings;
        settings.setProviderId("groq");

        QVariantList catalogue;
        QVariantMap entry;
        entry["id"] = "llama-3.3-70b-versatile";
        entry["vision"] = false;
        catalogue.append(entry);
        settings.updateModelCache(catalogue);

        // The fetched catalogue replaces a model it does not serve
        QCOMPARE(settings.modelName(), QString("llama-3.3-70b-versatile"));
        // A Mistral override is not sent to Groq
        QCOMPARE(settings.resolveModel("mistral-large-latest"),
                 QString("llama-3.3-70b-versatile"));
        QCOMPARE(settings.resolveModel("llama-3.3-70b-versatile"),
                 QString("llama-3.3-70b-versatile"));

        settings.setProviderId("mistral");
    }

    void contextLimitIsRoundedToPairs()
    {
        SettingsManager settings;

        settings.setContextMessageLimit(11);
        QCOMPARE(settings.contextMessageLimit(), 12);

        settings.setContextMessageLimit(-5);
        QCOMPARE(settings.contextMessageLimit(), 0);

        settings.setContextMessageLimit(20);
        QCOMPARE(settings.contextMessageLimit(), 20);
    }

    void chatStyleRejectsUnknownValues()
    {
        SettingsManager settings;
        settings.setChatStyle("bubbles");
        QCOMPARE(settings.chatStyle(), QString("bubbles"));

        settings.setChatStyle("neon-hologram");
        QCOMPARE(settings.chatStyle(), QString("bubbles"));

        settings.setChatStyle("flat");
    }

    void savedPromptsRoundTrip()
    {
        SettingsManager settings;
        while (!settings.savedPrompts().isEmpty()) {
            settings.removeSavedPrompt(0);
        }

        settings.addSavedPrompt("", "  Summarise this in three bullets  ");
        QCOMPARE(settings.savedPrompts().count(), 1);

        QVariantMap entry = settings.savedPrompts().at(0).toMap();
        QCOMPARE(entry["text"].toString(), QString("Summarise this in three bullets"));
        // A missing name falls back to the start of the prompt
        QVERIFY(!entry["title"].toString().isEmpty());

        settings.addSavedPrompt("Blank", "   ");   // ignored
        QCOMPARE(settings.savedPrompts().count(), 1);

        settings.updateSavedPrompt(0, "Summary", "Do it shorter");
        QCOMPARE(settings.savedPrompts().at(0).toMap()["title"].toString(), QString("Summary"));

        settings.removeSavedPrompt(5);   // out of range: no crash
        settings.removeSavedPrompt(0);
        QCOMPARE(settings.savedPrompts().count(), 0);
    }

    void costEstimation()
    {
        SettingsManager settings;

        // 1M in + 1M out on the large model, at 2.00 / 6.00 per million
        double cost = settings.estimatedCost("mistral-large-latest", 1000000, 1000000);
        QVERIFY(qAbs(cost - 8.0) < 0.0001);

        // The more specific entry wins over the "pixtral" prefix
        QCOMPARE(settings.modelPricing("pixtral-large-latest")["output"].toDouble(), 6.00);
        QCOMPARE(settings.modelPricing("pixtral-12b-latest")["output"].toDouble(), 0.15);

        // Unknown model: no invented number
        QVERIFY(!settings.modelPricing("some-future-model")["known"].toBool());
        QCOMPARE(settings.estimatedCost("some-future-model", 1000, 1000), -1.0);
    }

    void freeTierCostsNothing()
    {
        SettingsManager settings;
        settings.setProviderId("groq");

        QVariantList catalogue;
        QVariantMap entry;
        // Priced at Mistral, free here: the provider decides, not the name
        entry["id"] = "mistral-saba-24b";
        entry["vision"] = false;
        catalogue.append(entry);
        settings.updateModelCache(catalogue);

        QVERIFY(settings.modelPricing("mistral-saba-24b")["known"].toBool());
        QCOMPARE(settings.estimatedCost("mistral-saba-24b", 1000000, 1000000), 0.0);

        // A model this provider does not serve is still an unknown
        QVERIFY(!settings.modelPricing("some-future-model")["known"].toBool());

        settings.setProviderId("mistral");
        // Back on a paid provider the price list applies again
        QVERIFY(settings.estimatedCost("mistral-saba-24b", 1000000, 0) > 0.0);
    }
};

class TestProviders : public QObject
{
    Q_OBJECT

private slots:
    void registryIsConsistent()
    {
        const QList<Providers::Provider> all = Providers::all();
        QVERIFY(all.count() >= 2);
        QVERIFY(Providers::isValid(Providers::defaultId()));

        QStringList seen;
        for (int i = 0; i < all.count(); ++i) {
            const Providers::Provider &p = all.at(i);
            QVERIFY(!p.id.isEmpty());
            QVERIFY(!p.name.isEmpty());
            QVERIFY(!seen.contains(p.id));
            seen.append(p.id);

            if (p.baseUrl.isEmpty()) {
                // Only the custom entry has no address of its own, and it
                // cannot offer a catalogue either
                QCOMPARE(p.id, QString("custom"));
                QVERIFY(p.fallbackModels.isEmpty());
            } else {
                QVERIFY(p.baseUrl.startsWith("https://"));
                QVERIFY(!p.baseUrl.endsWith('/'));
                // Every preset must be usable before /v1/models is fetched
                QVERIFY(!p.fallbackModels.isEmpty());
                QVERIFY(p.fallbackModels.contains(p.defaultModel));
            }
        }
    }

    void unknownIdYieldsTheDefault()
    {
        QCOMPARE(Providers::byId("nope").id, Providers::defaultId());
        QVERIFY(!Providers::isValid("nope"));
    }

    void nonChatModelsAreFilteredOut()
    {
        // Real ids from the OVHcloud catalogue, which tags none of them
        QVERIFY(Providers::isChatModelId("Mistral-Small-3.2-24B-Instruct-2506"));
        QVERIFY(Providers::isChatModelId("gpt-oss-120b"));
        QVERIFY(!Providers::isChatModelId("Qwen3-Embedding-8B"));
        QVERIFY(!Providers::isChatModelId("bge-m3"));
        QVERIFY(!Providers::isChatModelId("whisper-large-v3"));
        QVERIFY(!Providers::isChatModelId("nvr-tts-en-us"));
        QVERIFY(!Providers::isChatModelId("stable-diffusion-xl-base-v10"));
        QVERIFY(!Providers::isChatModelId(""));
    }

    void visionIsGuessedConservatively()
    {
        QVERIFY(Providers::looksLikeVisionModel("pixtral-12b-latest"));
        QVERIFY(Providers::looksLikeVisionModel("Qwen2.5-VL-72B-Instruct"));
        QVERIFY(Providers::looksLikeVisionModel("llava-next-mistral-7b"));
        // On doubt the answer is no: the attachment button stays hidden
        QVERIFY(!Providers::looksLikeVisionModel("llama-3.3-70b-versatile"));
        QVERIFY(!Providers::looksLikeVisionModel("gpt-oss-120b"));
    }
};

int main(int argc, char *argv[])
{
    // Redirect QSettings and the conversation files away from the real
    // user configuration
    QTemporaryDir configDir;
    QTemporaryDir dataDir;
    qputenv("XDG_CONFIG_HOME", configDir.path().toUtf8());
    qputenv("XDG_DATA_HOME", dataDir.path().toUtf8());

    QCoreApplication app(argc, argv);
    app.setOrganizationName("harbour-sailcat");
    app.setApplicationName("SailCat");

    int status = 0;
    {
        TestConversationModel t;
        status |= QTest::qExec(&t, argc, argv);
    }
    {
        TestMistralAPI t;
        status |= QTest::qExec(&t, argc, argv);
    }
    {
        TestConversationManager t;
        status |= QTest::qExec(&t, argc, argv);
    }
    {
        TestCategories t;
        status |= QTest::qExec(&t, argc, argv);
    }
    {
        TestSecureStore t;
        status |= QTest::qExec(&t, argc, argv);
    }
    {
        TestSettingsManager t;
        status |= QTest::qExec(&t, argc, argv);
    }
    {
        TestProviders t;
        status |= QTest::qExec(&t, argc, argv);
    }
    return status;
}

#include "tst_main.moc"
