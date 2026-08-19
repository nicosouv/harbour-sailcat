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
    case PinnedRole:
        return message.pinned;
    case ImagePathRole:
        return message.imagePath;
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
    roles[PinnedRole] = "pinned";
    roles[ImagePathRole] = "imagePath";
    return roles;
}

void ConversationModel::addMessage(const QString &role, const QString &content, qint64 timestamp,
                                   bool pinned, const QString &imagePath)
{
    Message msg;
    msg.role = role;
    msg.content = content;
    msg.timestamp = timestamp;
    msg.pinned = pinned;
    msg.imagePath = imagePath;

    beginInsertRows(QModelIndex(), m_messages.count(), m_messages.count());
    m_messages.append(msg);
    endInsertRows();

    emit countChanged();
}

void ConversationModel::addUserMessage(const QString &content, const QString &imagePath)
{
    addMessage("user", content, QDateTime::currentMSecsSinceEpoch(), false, imagePath);
}

void ConversationModel::addAssistantMessage(const QString &content)
{
    addMessage("assistant", content, QDateTime::currentMSecsSinceEpoch());
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

void ConversationModel::removeLastMessageIfEmpty()
{
    if (m_messages.isEmpty())
        return;

    int lastIndex = m_messages.count() - 1;
    const Message &last = m_messages.at(lastIndex);

    if (last.role == "assistant" && last.content.isEmpty()) {
        beginRemoveRows(QModelIndex(), lastIndex, lastIndex);
        m_messages.removeAt(lastIndex);
        endRemoveRows();

        emit countChanged();
    }
}

void ConversationModel::removeLastAssistantMessage()
{
    if (m_messages.isEmpty())
        return;

    int lastIndex = m_messages.count() - 1;
    if (m_messages.at(lastIndex).role != "assistant")
        return;

    beginRemoveRows(QModelIndex(), lastIndex, lastIndex);
    m_messages.removeAt(lastIndex);
    endRemoveRows();

    emit countChanged();
}

void ConversationModel::truncateFrom(int index)
{
    if (index < 0 || index >= m_messages.count())
        return;

    beginRemoveRows(QModelIndex(), index, m_messages.count() - 1);
    while (m_messages.count() > index) {
        m_messages.removeLast();
    }
    endRemoveRows();

    emit countChanged();
}

void ConversationModel::togglePinned(int index)
{
    if (index < 0 || index >= m_messages.count())
        return;

    m_messages[index].pinned = !m_messages[index].pinned;
    QModelIndex modelIndex = createIndex(index, 0);
    emit dataChanged(modelIndex, modelIndex, {PinnedRole});
}

void ConversationModel::clearConversation()
{
    beginResetModel();
    m_messages.clear();
    endResetModel();

    emit countChanged();
}

QString ConversationModel::getLastUserMessage() const
{
    for (int i = m_messages.count() - 1; i >= 0; --i) {
        if (m_messages.at(i).role == "user") {
            return m_messages.at(i).content;
        }
    }
    return QString();
}

QString ConversationModel::getLastUserImagePath() const
{
    for (int i = m_messages.count() - 1; i >= 0; --i) {
        if (m_messages.at(i).role == "user") {
            return m_messages.at(i).imagePath;
        }
    }
    return QString();
}

QString ConversationModel::getFirstUserMessage() const
{
    for (const Message &msg : m_messages) {
        if (msg.role == "user") {
            return msg.content;
        }
    }
    return QString();
}

QString ConversationModel::getLastAssistantMessage() const
{
    for (int i = m_messages.count() - 1; i >= 0; --i) {
        if (m_messages.at(i).role == "assistant" && !m_messages.at(i).content.isEmpty()) {
            return m_messages.at(i).content;
        }
    }
    return QString();
}

QJsonArray ConversationModel::toJsonArray() const
{
    QJsonArray messages;

    for (const Message &msg : m_messages) {
        QJsonObject msgObj;
        msgObj["role"] = msg.role;
        msgObj["content"] = msg.content;
        msgObj["timestamp"] = msg.timestamp;
        msgObj["pinned"] = msg.pinned;
        msgObj["imagePath"] = msg.imagePath;
        messages.append(msgObj);
    }

    return messages;
}
