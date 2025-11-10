#ifndef CONVERSATIONMANAGER_H
#define CONVERSATIONMANAGER_H

#include <QObject>
#include <QSettings>
#include <QJsonArray>
#include <QJsonObject>
#include "conversationmodel.h"

struct Conversation {
    QString id;
    QString title;
    qint64 createdAt;
    qint64 updatedAt;
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
    Q_INVOKABLE QJsonArray getConversationsList() const;
    Q_INVOKABLE QJsonObject getConversationDetails(const QString &conversationId) const;
    Q_INVOKABLE qint64 getStorageSize() const;
    Q_INVOKABLE QString getStorageSizeFormatted() const;
    Q_INVOKABLE void purgeAllConversations();

    void saveCurrentConversation();
    void loadAllConversations();

signals:
    void currentConversationChanged();
    void conversationCountChanged();

private:
    ConversationModel *m_currentConversation;
    QString m_currentConversationId;
    QList<Conversation> m_conversations;
    QSettings m_settings;

    QString generateConversationId() const;
    QString generateConversationTitle(const QList<Message> &messages) const;
    void saveAllConversations();
    Conversation* findConversation(const QString &id);
};

#endif // CONVERSATIONMANAGER_H
