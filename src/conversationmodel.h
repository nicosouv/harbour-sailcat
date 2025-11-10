#ifndef CONVERSATIONMODEL_H
#define CONVERSATIONMODEL_H

#include <QAbstractListModel>
#include <QJsonArray>
#include <QJsonObject>
#include <QList>

struct Message {
    QString role;      // "user" or "assistant"
    QString content;
    qint64 timestamp;
};

class ConversationModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum MessageRoles {
        RoleRole = Qt::UserRole + 1,
        ContentRole,
        TimestampRole
    };

    explicit ConversationModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void addUserMessage(const QString &content);
    Q_INVOKABLE void addAssistantMessage(const QString &content);
    Q_INVOKABLE void updateLastAssistantMessage(const QString &content);
    Q_INVOKABLE void clearConversation();
    Q_INVOKABLE QJsonArray toJsonArray() const;

signals:
    void countChanged();

private:
    QList<Message> m_messages;
};

#endif // CONVERSATIONMODEL_H
