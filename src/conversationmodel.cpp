#include "conversationmodel.h"
#include <QDateTime>

ConversationModel::ConversationModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int ConversationModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    return m_messages.count();
}

QVariant ConversationModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_messages.count())
        return QVariant();

    const Message &message = m_messages.at(index.row());

    switch (role) {
    case RoleRole:
        return message.role;
    case ContentRole:
        return message.content;
    case TimestampRole:
        return message.timestamp;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> ConversationModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[RoleRole] = "role";
    roles[ContentRole] = "content";
    roles[TimestampRole] = "timestamp";
    return roles;
}

void ConversationModel::addUserMessage(const QString &content)
{
    Message msg;
    msg.role = "user";
    msg.content = content;
    msg.timestamp = QDateTime::currentMSecsSinceEpoch();

    beginInsertRows(QModelIndex(), m_messages.count(), m_messages.count());
    m_messages.append(msg);
    endInsertRows();

    emit countChanged();
}

void ConversationModel::addAssistantMessage(const QString &content)
{
    Message msg;
    msg.role = "assistant";
    msg.content = content;
    msg.timestamp = QDateTime::currentMSecsSinceEpoch();

    beginInsertRows(QModelIndex(), m_messages.count(), m_messages.count());
    m_messages.append(msg);
    endInsertRows();

    emit countChanged();
}

void ConversationModel::updateLastAssistantMessage(const QString &content)
{
    if (m_messages.isEmpty())
        return;

    int lastIndex = m_messages.count() - 1;

    // Si le dernier message n'est pas de l'assistant, en créer un nouveau
    if (m_messages.at(lastIndex).role != "assistant") {
        addAssistantMessage(content);
        return;
    }

    // Mettre à jour le contenu du dernier message
    m_messages[lastIndex].content = content;
    QModelIndex index = createIndex(lastIndex, 0);
    emit dataChanged(index, index, {ContentRole});
}

void ConversationModel::clearConversation()
{
    beginResetModel();
    m_messages.clear();
    endResetModel();

    emit countChanged();
}

QVariant ConversationModel::getMessagesForApi() const
{
    QVariantList messagesList;

    for (const Message &msg : m_messages) {
        QVariantMap msgMap;
        msgMap["role"] = msg.role;
        msgMap["content"] = msg.content;
        messagesList.append(msgMap);
    }

    return messagesList;
}

QJsonArray ConversationModel::toJsonArray() const
{
    QJsonArray messages;

    for (const Message &msg : m_messages) {
        QJsonObject msgObj;
        msgObj["role"] = msg.role;
        msgObj["content"] = msg.content;
        messages.append(msgObj);
    }

    return messages;
}
