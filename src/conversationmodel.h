#ifndef CONVERSATIONMODEL_H
#define CONVERSATIONMODEL_H

#include <QAbstractListModel>
#include <QJsonArray>
#include <QJsonObject>
#include <QList>

struct Message {
    QString role;      // "user" or "assistant"
    QString content;
    QString imagePath; // local file attached to the message (vision models)
    qint64 timestamp;
    bool pinned = false;
};

class ConversationModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum MessageRoles {
        RoleRole = Qt::UserRole + 1,
        ContentRole,
        TimestampRole,
        PinnedRole,
        ImagePathRole
    };

    explicit ConversationModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void addUserMessage(const QString &content, const QString &imagePath = QString());
    Q_INVOKABLE void addAssistantMessage(const QString &content);
    Q_INVOKABLE void updateLastAssistantMessage(const QString &content);
    Q_INVOKABLE void removeLastMessageIfEmpty();
    Q_INVOKABLE void removeLastAssistantMessage();
    Q_INVOKABLE void truncateFrom(int index);
    Q_INVOKABLE void togglePinned(int index);
    Q_INVOKABLE void clearConversation();
    Q_INVOKABLE QString getFirstUserMessage() const;
    Q_INVOKABLE QString getLastAssistantMessage() const;
    Q_INVOKABLE QString getLastUserMessage() const;
    Q_INVOKABLE QString getLastUserImagePath() const;

    void addMessage(const QString &role, const QString &content, qint64 timestamp,
                    bool pinned = false, const QString &imagePath = QString());
    QJsonArray toJsonArray() const;

    // Read-only view used by ConversationManager to build the API payload.
    const QList<Message> &messages() const { return m_messages; }

signals:
    void countChanged();

private:
    QList<Message> m_messages;
};

#endif // CONVERSATIONMODEL_H
