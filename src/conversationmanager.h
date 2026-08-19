#ifndef CONVERSATIONMANAGER_H
#define CONVERSATIONMANAGER_H

#include <QObject>
#include <QSet>
#include <QSettings>
#include <QJsonArray>
#include <QJsonObject>
#include <QVariant>
#include "conversationmodel.h"

struct Conversation {
    QString id;
    QString title;
    QString category;
    QString model;          // per-conversation model override, empty = global
    QString systemPrompt;   // per-conversation system prompt, empty = global
    qint64 createdAt;
    qint64 updatedAt;
    qint64 totalTokens = 0;
    QList<Message> messages;
};

class ConversationManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(ConversationModel* currentConversation READ currentConversation NOTIFY currentConversationChanged)
    Q_PROPERTY(int conversationCount READ conversationCount NOTIFY conversationCountChanged)

public:
    explicit ConversationManager(QObject *parent = nullptr);

    ConversationModel* currentConversation() const { return m_currentConversation; }
    int conversationCount() const { return m_conversations.count(); }

    Q_INVOKABLE void createNewConversation();
    Q_INVOKABLE void loadConversation(const QString &conversationId);
    Q_INVOKABLE void deleteConversation(const QString &conversationId);
    Q_INVOKABLE void renameConversation(const QString &conversationId, const QString &newTitle);
    Q_INVOKABLE void updateCurrentConversationTitle(const QString &newTitle);
    Q_INVOKABLE void updateCurrentConversationCategory(const QString &category);
    Q_INVOKABLE void setConversationCategory(const QString &conversationId, const QString &category);
    Q_INVOKABLE void saveCurrentConversation();
    Q_INVOKABLE QJsonArray getConversationsList() const;
    Q_INVOKABLE QVariant getConversationDetails(const QString &conversationId) const;
    Q_INVOKABLE qint64 getStorageSize() const;
    Q_INVOKABLE QString getStorageSizeFormatted() const;
    Q_INVOKABLE void purgeAllConversations();
    Q_INVOKABLE QVariantMap getStatistics() const;
    Q_INVOKABLE QVariantMap getConversationStatistics(const QString &conversationId) const;
    Q_INVOKABLE QVariantMap getFunStats() const;
    Q_INVOKABLE QVariantList searchConversations(const QString &query) const;
    Q_INVOKABLE void addTokenUsage(int promptTokens, int completionTokens,
                                   const QString &model = QString());
    Q_INVOKABLE QString currentConversationId() const;
    Q_INVOKABLE QVariantList getPinnedMessages() const;
    Q_INVOKABLE QString conversationToMarkdown(const QString &conversationId) const;
    // Condensed transcript handed to the model when asking for a title.
    Q_INVOKABLE QString conversationDigest(const QString &conversationId) const;
    Q_INVOKABLE QString exportConversation(const QString &conversationId) const;
    Q_INVOKABLE QString imageToDataUrl(const QString &filePath) const;

    // Per-conversation overrides. An empty value means "use the global setting".
    Q_INVOKABLE QVariantMap getConversationOverrides(const QString &conversationId) const;
    Q_INVOKABLE void setConversationOverrides(const QString &conversationId,
                                              const QString &model,
                                              const QString &systemPrompt);

    // Full request payload for the current conversation: history trimmed to
    // contextLimit messages, attached images expanded into multimodal parts,
    // system prompt prepended. contextLimit <= 0 keeps everything.
    Q_INVOKABLE QVariantList buildApiMessages(int contextLimit,
                                              const QString &systemPrompt) const;
    // How many messages buildApiMessages would leave out.
    Q_INVOKABLE int trimmedMessageCount(int contextLimit) const;

    // Re-run the local classifier over every conversation still labelled
    // "other" or unlabelled. Returns the number of conversations relabelled.
    Q_INVOKABLE int recategorizeConversations();

    // Copy a picked image into the app data directory so the conversation keeps
    // working after the original is deleted from the gallery. Returns the new
    // path, or the input unchanged on failure.
    Q_INVOKABLE QString retainImage(const QString &filePath) const;

    void loadAllConversations();

signals:
    void currentConversationChanged();
    void conversationCountChanged();

private:
    ConversationModel *m_currentConversation;
    QString m_currentConversationId;
    QList<Conversation> m_conversations;
    QSettings m_settings;
    QSet<QString> m_dirtyIds;
    qint64 m_totalPromptTokens;
    qint64 m_totalCompletionTokens;

    QString generateConversationId() const;
    QString generateConversationTitle(const QList<Message> &messages) const;

    QString conversationsDir() const;
    QString conversationFilePath(const QString &id) const;
    static bool isSafeId(const QString &id);
    QJsonObject conversationToJson(const Conversation &conv) const;
    static Conversation conversationFromJson(const QJsonObject &obj);
    void migrateFromSettings();
    void writeConversation(const Conversation &conv) const;
    void saveDirtyConversations();
    void markDirty(const QString &id);
    Conversation* findConversation(const QString &id);
    const Conversation* findConversation(const QString &id) const;
};

#endif // CONVERSATIONMANAGER_H
