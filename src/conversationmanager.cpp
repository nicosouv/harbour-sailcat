#include "conversationmanager.h"
#include <QDateTime>
#include <QUuid>
#include <QJsonDocument>
#include <QDebug>

ConversationManager::ConversationManager(QObject *parent)
    : QObject(parent)
    , m_currentConversation(new ConversationModel(this))
    , m_settings("harbour-sailcat", "conversations")
{
    loadAllConversations();

    // Si aucune conversation n'existe, en créer une nouvelle
    if (m_conversations.isEmpty()) {
        createNewConversation();
    } else {
        // Charger la dernière conversation utilisée
        QString lastId = m_settings.value("lastConversationId").toString();
        if (!lastId.isEmpty()) {
            loadConversation(lastId);
        } else {
            loadConversation(m_conversations.first().id);
        }
    }
}

void ConversationManager::createNewConversation()
{
    // Sauvegarder la conversation courante si elle existe
    if (!m_currentConversationId.isEmpty()) {
        saveCurrentConversation();
    }

    // Créer une nouvelle conversation
    Conversation newConv;
    newConv.id = generateConversationId();
    newConv.title = ""; // Sera généré automatiquement au premier message
    newConv.createdAt = QDateTime::currentMSecsSinceEpoch();
    newConv.updatedAt = newConv.createdAt;

    m_conversations.prepend(newConv);
    m_currentConversationId = newConv.id;

    // Vider le modèle actuel
    m_currentConversation->clearConversation();

    m_settings.setValue("lastConversationId", m_currentConversationId);

    emit currentConversationChanged();
    emit conversationCountChanged();
}

void ConversationManager::loadConversation(const QString &conversationId)
{
    // Sauvegarder la conversation courante
    if (!m_currentConversationId.isEmpty()) {
        saveCurrentConversation();
    }

    Conversation *conv = findConversation(conversationId);
    if (!conv) {
        qWarning() << "Conversation not found:" << conversationId;
        return;
    }

    m_currentConversationId = conversationId;
    m_currentConversation->clearConversation();

    // Charger les messages
    for (const Message &msg : conv->messages) {
        if (msg.role == "user") {
            m_currentConversation->addUserMessage(msg.content);
        } else {
            m_currentConversation->addAssistantMessage(msg.content);
        }
    }

    m_settings.setValue("lastConversationId", m_currentConversationId);

    emit currentConversationChanged();
}

void ConversationManager::deleteConversation(const QString &conversationId)
{
    for (int i = 0; i < m_conversations.count(); ++i) {
        if (m_conversations[i].id == conversationId) {
            m_conversations.removeAt(i);

            // Si c'est la conversation courante, en créer une nouvelle
            if (conversationId == m_currentConversationId) {
                createNewConversation();
            }

            saveAllConversations();
            emit conversationCountChanged();
            return;
        }
    }
}

void ConversationManager::renameConversation(const QString &conversationId, const QString &newTitle)
{
    Conversation *conv = findConversation(conversationId);
    if (conv) {
        conv->title = newTitle;
        conv->updatedAt = QDateTime::currentMSecsSinceEpoch();
        saveAllConversations();
    }
}

void ConversationManager::updateCurrentConversationTitle(const QString &newTitle)
{
    if (m_currentConversationId.isEmpty() || newTitle.isEmpty()) {
        return;
    }

    renameConversation(m_currentConversationId, newTitle);
}

QJsonArray ConversationManager::getConversationsList() const
{
    QJsonArray list;

    for (const Conversation &conv : m_conversations) {
        QJsonObject obj;
        obj["id"] = conv.id;
        obj["title"] = conv.title.isEmpty() ? tr("New conversation") : conv.title;
        obj["createdAt"] = conv.createdAt;
        obj["updatedAt"] = conv.updatedAt;
        obj["messageCount"] = conv.messages.count();
        list.append(obj);
    }

    return list;
}

void ConversationManager::saveCurrentConversation()
{
    if (m_currentConversationId.isEmpty())
        return;

    Conversation *conv = findConversation(m_currentConversationId);
    if (!conv)
        return;

    // Récupérer les messages du modèle
    conv->messages.clear();
    QJsonArray messagesJson = m_currentConversation->toJsonArray();

    for (int i = 0; i < messagesJson.count(); ++i) {
        QJsonObject msgObj = messagesJson[i].toObject();
        Message msg;
        msg.role = msgObj["role"].toString();
        msg.content = msgObj["content"].toString();
        msg.timestamp = QDateTime::currentMSecsSinceEpoch();
        conv->messages.append(msg);
    }

    // Générer un titre si nécessaire
    if (conv->title.isEmpty() && !conv->messages.isEmpty()) {
        conv->title = generateConversationTitle(conv->messages);
    }

    conv->updatedAt = QDateTime::currentMSecsSinceEpoch();

    saveAllConversations();
}

void ConversationManager::loadAllConversations()
{
    m_conversations.clear();

    QJsonDocument doc = QJsonDocument::fromJson(m_settings.value("conversations").toByteArray());
    if (!doc.isArray())
        return;

    QJsonArray array = doc.array();
    for (int i = 0; i < array.count(); ++i) {
        QJsonObject obj = array[i].toObject();

        Conversation conv;
        conv.id = obj["id"].toString();
        conv.title = obj["title"].toString();
        conv.createdAt = obj["createdAt"].toVariant().toLongLong();
        conv.updatedAt = obj["updatedAt"].toVariant().toLongLong();

        QJsonArray messagesArray = obj["messages"].toArray();
        for (int j = 0; j < messagesArray.count(); ++j) {
            QJsonObject msgObj = messagesArray[j].toObject();
            Message msg;
            msg.role = msgObj["role"].toString();
            msg.content = msgObj["content"].toString();
            msg.timestamp = msgObj["timestamp"].toVariant().toLongLong();
            conv.messages.append(msg);
        }

        m_conversations.append(conv);
    }
}

void ConversationManager::saveAllConversations()
{
    QJsonArray array;

    for (const Conversation &conv : m_conversations) {
        QJsonObject obj;
        obj["id"] = conv.id;
        obj["title"] = conv.title;
        obj["createdAt"] = conv.createdAt;
        obj["updatedAt"] = conv.updatedAt;

        QJsonArray messagesArray;
        for (const Message &msg : conv.messages) {
            QJsonObject msgObj;
            msgObj["role"] = msg.role;
            msgObj["content"] = msg.content;
            msgObj["timestamp"] = msg.timestamp;
            messagesArray.append(msgObj);
        }
        obj["messages"] = messagesArray;

        array.append(obj);
    }

    QJsonDocument doc(array);
    m_settings.setValue("conversations", doc.toJson(QJsonDocument::Compact));
}

QString ConversationManager::generateConversationId() const
{
    // Qt 5.6 doesn't have QUuid::WithoutBraces, so we manually remove braces
    QString uuid = QUuid::createUuid().toString();
    return uuid.mid(1, uuid.length() - 2);  // Remove { and }
}

QString ConversationManager::generateConversationTitle(const QList<Message> &messages) const
{
    // Prendre le premier message utilisateur et le tronquer
    for (const Message &msg : messages) {
        if (msg.role == "user") {
            QString title = msg.content.trimmed();
            if (title.length() > 50) {
                title = title.left(47) + "...";
            }
            return title;
        }
    }
    return tr("New conversation");
}

Conversation* ConversationManager::findConversation(const QString &id)
{
    for (int i = 0; i < m_conversations.count(); ++i) {
        if (m_conversations[i].id == id) {
            return &m_conversations[i];
        }
    }
    return nullptr;
}

QVariant ConversationManager::getConversationDetails(const QString &conversationId) const
{
    QVariantMap details;

    for (const Conversation &conv : m_conversations) {
        if (conv.id == conversationId) {
            details["id"] = conv.id;
            details["title"] = conv.title;
            details["createdAt"] = conv.createdAt;
            details["updatedAt"] = conv.updatedAt;

            QVariantList messagesList;
            for (const Message &msg : conv.messages) {
                QVariantMap msgMap;
                msgMap["role"] = msg.role;
                msgMap["content"] = msg.content;
                msgMap["timestamp"] = msg.timestamp;
                messagesList.append(msgMap);
            }
            details["messages"] = messagesList;
            details["messageCount"] = conv.messages.count();

            break;
        }
    }

    return details;
}

qint64 ConversationManager::getStorageSize() const
{
    QByteArray data = m_settings.value("conversations").toByteArray();
    return data.size();
}

QString ConversationManager::getStorageSizeFormatted() const
{
    qint64 bytes = getStorageSize();

    if (bytes < 1024) {
        return QString("%1 B").arg(bytes);
    } else if (bytes < 1024 * 1024) {
        return QString("%1 KB").arg(bytes / 1024.0, 0, 'f', 2);
    } else {
        return QString("%1 MB").arg(bytes / (1024.0 * 1024.0), 0, 'f', 2);
    }
}

void ConversationManager::purgeAllConversations()
{
    m_conversations.clear();
    m_settings.remove("conversations");
    m_settings.remove("lastConversationId");

    // Create a new empty conversation
    createNewConversation();

    emit conversationCountChanged();
}

QVariantMap ConversationManager::getStatistics() const
{
    QVariantMap stats;

    int totalMessages = 0;
    int totalUserMessages = 0;
    int totalAssistantMessages = 0;
    int longestConvMessages = 0;
    int longestMessageLength = 0;
    qint64 estimatedTokens = 0;
    qint64 firstMessageDate = 0;
    QString longestConvTitle;

    for (const Conversation &conv : m_conversations) {
        int convMessageCount = conv.messages.count();
        totalMessages += convMessageCount;

        if (convMessageCount > longestConvMessages) {
            longestConvMessages = convMessageCount;
            longestConvTitle = conv.title.isEmpty() ? tr("Untitled") : conv.title;
        }

        for (const Message &msg : conv.messages) {
            if (msg.role == "user") {
                totalUserMessages++;
            } else if (msg.role == "assistant") {
                totalAssistantMessages++;
            }

            // Find longest message
            if (msg.content.length() > longestMessageLength) {
                longestMessageLength = msg.content.length();
            }

            // Estimate tokens (rough approximation: ~4 chars per token)
            estimatedTokens += msg.content.length() / 4;

            // Track first message date
            if (firstMessageDate == 0 || msg.timestamp < firstMessageDate) {
                firstMessageDate = msg.timestamp;
            }
        }
    }

    stats["totalMessages"] = totalMessages;
    stats["totalUserMessages"] = totalUserMessages;
    stats["totalAssistantMessages"] = totalAssistantMessages;
    stats["totalConversations"] = m_conversations.count();
    stats["longestConvMessages"] = longestConvMessages;
    stats["longestConvTitle"] = longestConvTitle;
    stats["longestMessageLength"] = longestMessageLength;
    stats["estimatedTokens"] = estimatedTokens;
    stats["firstMessageDate"] = firstMessageDate;

    return stats;
}

QVariantList ConversationManager::searchConversations(const QString &query) const
{
    QVariantList results;

    if (query.trimmed().isEmpty()) {
        return results;
    }

    QString searchQuery = query.trimmed().toLower();

    for (const Conversation &conv : m_conversations) {
        bool titleMatch = conv.title.toLower().contains(searchQuery);
        int matchCount = 0;
        QString matchPreview;

        // Search in messages
        for (const Message &msg : conv.messages) {
            if (msg.content.toLower().contains(searchQuery)) {
                matchCount++;

                // Get preview of first match if we don't have one yet
                if (matchPreview.isEmpty()) {
                    int pos = msg.content.toLower().indexOf(searchQuery);
                    int start = qMax(0, pos - 40);
                    int length = qMin(100, msg.content.length() - start);
                    matchPreview = msg.content.mid(start, length);

                    if (start > 0) {
                        matchPreview = "..." + matchPreview;
                    }
                    if (start + length < msg.content.length()) {
                        matchPreview = matchPreview + "...";
                    }
                }
            }
        }

        // If we have matches or title match, add to results
        if (titleMatch || matchCount > 0) {
            QVariantMap result;
            result["id"] = conv.id;
            result["title"] = conv.title.isEmpty() ? tr("Untitled") : conv.title;
            result["createdAt"] = conv.createdAt;
            result["updatedAt"] = conv.updatedAt;
            result["messageCount"] = conv.messages.count();
            result["matchCount"] = matchCount;
            result["matchPreview"] = matchPreview.isEmpty() ? tr("Match in title") : matchPreview;
            result["titleMatch"] = titleMatch;

            results.append(result);
        }
    }

    return results;
}
