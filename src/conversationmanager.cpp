#include "conversationmanager.h"
#include <QDateTime>
#include <QUuid>
#include <QJsonDocument>

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
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
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
