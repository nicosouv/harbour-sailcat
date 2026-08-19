#include "conversationmanager.h"
#include "categories.h"
#include "securestore.h"

#include <QBuffer>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QImage>
#include <QJsonDocument>
#include <QPair>
#include <QRegExp>
#include <QSaveFile>
#include <QSet>
#include <QStandardPaths>
#include <QTextStream>
#include <QUrl>
#include <QUuid>
#include <QVector>
#include <QDebug>
#include <algorithm>

namespace {

// Keep the on-disk payload bounded: an image that never gets sent again is
// still worth ~1.4x its size in base64 inside the request body.
const int MAX_IMAGE_DIMENSION = 1024;
const int JPEG_QUALITY = 85;

}

ConversationManager::ConversationManager(QObject *parent)
    : QObject(parent)
    , m_currentConversation(new ConversationModel(this))
    , m_settings("harbour-sailcat", "conversations")
    , m_totalPromptTokens(0)
    , m_totalCompletionTokens(0)
{
    m_totalPromptTokens = m_settings.value("stats/totalPromptTokens", 0).toLongLong();
    m_totalCompletionTokens = m_settings.value("stats/totalCompletionTokens", 0).toLongLong();

    migrateFromSettings();
    loadAllConversations();

    if (m_conversations.isEmpty()) {
        createNewConversation();
    } else {
        // Copy the id: loadConversation must not hold a reference into the
        // list it is about to work on.
        const QString lastId = m_settings.value("lastConversationId").toString();
        const QString targetId = (!lastId.isEmpty() && findConversation(lastId))
                ? lastId : QString(m_conversations.first().id);
        loadConversation(targetId);
    }
}

// ---------------------------------------------------------------- storage

QString ConversationManager::conversationsDir() const
{
    QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (base.isEmpty()) {
        base = QDir::homePath() + "/.local/share/harbour-sailcat";
    }
    return base + "/conversations";
}

bool ConversationManager::isSafeId(const QString &id)
{
    // Ids are generated UUIDs, but they end up as file names: never trust one
    // that could walk out of the conversations directory.
    if (id.isEmpty() || id.length() > 64) {
        return false;
    }
    return !id.contains(QRegExp("[^a-zA-Z0-9-]"));
}

QString ConversationManager::conversationFilePath(const QString &id) const
{
    if (!isSafeId(id)) {
        return QString();
    }
    return conversationsDir() + "/" + id + ".json";
}

QJsonObject ConversationManager::conversationToJson(const Conversation &conv) const
{
    QJsonObject obj;
    obj["id"] = conv.id;
    obj["title"] = conv.title;
    obj["category"] = conv.category;
    obj["model"] = conv.model;
    obj["systemPrompt"] = conv.systemPrompt;
    obj["createdAt"] = conv.createdAt;
    obj["updatedAt"] = conv.updatedAt;
    obj["totalTokens"] = conv.totalTokens;

    QJsonArray messagesArray;
    for (const Message &msg : conv.messages) {
        QJsonObject msgObj;
        msgObj["role"] = msg.role;
        msgObj["content"] = msg.content;
        msgObj["timestamp"] = msg.timestamp;
        msgObj["pinned"] = msg.pinned;
        msgObj["imagePath"] = msg.imagePath;
        messagesArray.append(msgObj);
    }
    obj["messages"] = messagesArray;

    return obj;
}

Conversation ConversationManager::conversationFromJson(const QJsonObject &obj)
{
    Conversation conv;
    conv.id = obj["id"].toString();
    conv.title = obj["title"].toString();
    conv.category = obj["category"].toString();
    conv.model = obj["model"].toString();
    conv.systemPrompt = obj["systemPrompt"].toString();
    conv.createdAt = obj["createdAt"].toVariant().toLongLong();
    conv.updatedAt = obj["updatedAt"].toVariant().toLongLong();
    conv.totalTokens = obj["totalTokens"].toVariant().toLongLong();

    const QJsonArray messagesArray = obj["messages"].toArray();
    for (int j = 0; j < messagesArray.count(); ++j) {
        const QJsonObject msgObj = messagesArray.at(j).toObject();
        Message msg;
        msg.role = msgObj["role"].toString();
        msg.content = msgObj["content"].toString();
        msg.timestamp = msgObj["timestamp"].toVariant().toLongLong();
        msg.pinned = msgObj["pinned"].toBool();
        msg.imagePath = msgObj["imagePath"].toString();
        conv.messages.append(msg);
    }

    return conv;
}

void ConversationManager::migrateFromSettings()
{
    // Up to 2.0.4 everything lived in a single QSettings value, rewritten in
    // full on every save. Split it into one file per conversation, once.
    if (!m_settings.contains("conversations")) {
        return;
    }

    const QJsonDocument doc = QJsonDocument::fromJson(
                m_settings.value("conversations").toByteArray());
    if (doc.isArray()) {
        const QJsonArray array = doc.array();
        for (int i = 0; i < array.count(); ++i) {
            const Conversation conv = conversationFromJson(array.at(i).toObject());
            if (conv.id.isEmpty()) {
                continue;
            }
            writeConversation(conv);
        }
        qDebug() << "Migrated" << array.count() << "conversations to per-file storage";
    }

    m_settings.remove("conversations");
    m_settings.sync();
}

void ConversationManager::writeConversation(const Conversation &conv) const
{
    const QString path = conversationFilePath(conv.id);
    if (path.isEmpty()) {
        qWarning() << "Refusing to write conversation with an unsafe id";
        return;
    }

    const QString dir = conversationsDir();
    QDir().mkpath(dir);
    SecureStore::restrictDirPermissions(dir);

    // Atomic: a kill mid-write leaves the previous file intact.
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        qWarning() << "Cannot write conversation:" << file.errorString();
        return;
    }
    file.write(QJsonDocument(conversationToJson(conv)).toJson(QJsonDocument::Compact));
    if (!file.commit()) {
        qWarning() << "Cannot commit conversation:" << file.errorString();
        return;
    }

    SecureStore::restrictPermissions(path);
}

void ConversationManager::markDirty(const QString &id)
{
    if (!id.isEmpty()) {
        m_dirtyIds.insert(id);
    }
}

void ConversationManager::saveDirtyConversations()
{
    if (m_dirtyIds.isEmpty()) {
        return;
    }

    for (const QString &id : m_dirtyIds) {
        const Conversation *conv = findConversation(id);
        if (conv) {
            writeConversation(*conv);
        }
    }
    m_dirtyIds.clear();
}

void ConversationManager::loadAllConversations()
{
    m_conversations.clear();

    QDir dir(conversationsDir());
    if (!dir.exists()) {
        return;
    }

    const QStringList files = dir.entryList(QStringList() << "*.json", QDir::Files);
    for (const QString &fileName : files) {
        QFile file(dir.filePath(fileName));
        if (!file.open(QIODevice::ReadOnly)) {
            continue;
        }
        const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
        file.close();

        if (!doc.isObject()) {
            qWarning() << "Skipping unreadable conversation file" << fileName;
            continue;
        }
        const Conversation conv = conversationFromJson(doc.object());
        if (conv.id.isEmpty()) {
            continue;
        }
        m_conversations.append(conv);
    }

    // Most recently used first, as the history page expects.
    std::sort(m_conversations.begin(), m_conversations.end(),
              [](const Conversation &a, const Conversation &b) {
        return a.updatedAt > b.updatedAt;
    });
}

// ---------------------------------------------------------------- lifecycle

void ConversationManager::createNewConversation()
{
    if (!m_currentConversationId.isEmpty()) {
        saveCurrentConversation();
    }

    Conversation newConv;
    newConv.id = generateConversationId();
    newConv.title = ""; // Generated from the first exchange
    newConv.createdAt = QDateTime::currentMSecsSinceEpoch();
    newConv.updatedAt = newConv.createdAt;

    m_conversations.prepend(newConv);
    m_currentConversationId = newConv.id;

    m_currentConversation->clearConversation();

    m_settings.setValue("lastConversationId", m_currentConversationId);
    m_settings.sync();

    emit currentConversationChanged();
    emit conversationCountChanged();
}

void ConversationManager::loadConversation(const QString &conversationId)
{
    if (!m_currentConversationId.isEmpty() && m_currentConversationId != conversationId) {
        saveCurrentConversation();
    }

    Conversation *conv = findConversation(conversationId);
    if (!conv) {
        qWarning() << "Conversation not found:" << conversationId;
        return;
    }

    m_currentConversationId = conversationId;
    m_currentConversation->clearConversation();

    // Load messages preserving their original timestamps
    for (const Message &msg : conv->messages) {
        m_currentConversation->addMessage(msg.role, msg.content, msg.timestamp,
                                          msg.pinned, msg.imagePath);
    }

    m_settings.setValue("lastConversationId", m_currentConversationId);
    m_settings.sync();

    emit currentConversationChanged();
}

void ConversationManager::deleteConversation(const QString &conversationId)
{
    for (int i = 0; i < m_conversations.count(); ++i) {
        if (m_conversations[i].id != conversationId) {
            continue;
        }

        m_conversations.removeAt(i);
        m_dirtyIds.remove(conversationId);

        const QString path = conversationFilePath(conversationId);
        if (!path.isEmpty()) {
            QFile::remove(path);
        }

        if (conversationId == m_currentConversationId) {
            // Nothing left to save under the old id
            m_currentConversationId.clear();
            createNewConversation();
        }

        emit conversationCountChanged();
        return;
    }
}

void ConversationManager::renameConversation(const QString &conversationId, const QString &newTitle)
{
    Conversation *conv = findConversation(conversationId);
    if (!conv) {
        return;
    }

    conv->title = newTitle.trimmed();
    conv->updatedAt = QDateTime::currentMSecsSinceEpoch();
    markDirty(conversationId);
    saveDirtyConversations();
}

void ConversationManager::updateCurrentConversationTitle(const QString &newTitle)
{
    if (m_currentConversationId.isEmpty() || newTitle.trimmed().isEmpty()) {
        return;
    }

    renameConversation(m_currentConversationId, newTitle);
}

void ConversationManager::updateCurrentConversationCategory(const QString &category)
{
    setConversationCategory(m_currentConversationId, category);
}

void ConversationManager::setConversationCategory(const QString &conversationId,
                                                  const QString &category)
{
    Conversation *conv = findConversation(conversationId);
    if (!conv) {
        return;
    }

    QString resolved = category.trimmed().toLower();
    if (!Categories::isValid(resolved)) {
        resolved = "other";
    }

    // The model routinely falls back to "other" even when the topic is
    // obvious; give the local classifier the final say in that case.
    if (resolved == "other") {
        QString text;
        for (const Message &msg : conv->messages) {
            if (msg.role == "user") {
                text += msg.content + " ";
                if (text.length() > 2000) {
                    break;
                }
            }
        }
        const QString guessed = Categories::classify(text);
        if (!guessed.isEmpty()) {
            resolved = guessed;
        }
    }

    if (conv->category == resolved) {
        return;
    }

    conv->category = resolved;
    markDirty(conversationId);
    saveDirtyConversations();
}

int ConversationManager::recategorizeConversations()
{
    int changed = 0;

    for (Conversation &conv : m_conversations) {
        if (!conv.category.isEmpty() && conv.category != "other") {
            continue;
        }

        QString text;
        for (const Message &msg : conv.messages) {
            if (msg.role == "user") {
                text += msg.content + " ";
                if (text.length() > 2000) {
                    break;
                }
            }
        }

        const QString guessed = Categories::classify(text);
        if (guessed.isEmpty() || guessed == conv.category) {
            continue;
        }

        conv.category = guessed;
        markDirty(conv.id);
        changed++;
    }

    saveDirtyConversations();
    return changed;
}

void ConversationManager::saveCurrentConversation()
{
    if (m_currentConversationId.isEmpty())
        return;

    Conversation *conv = findConversation(m_currentConversationId);
    if (!conv)
        return;

    conv->messages.clear();
    for (const Message &msg : m_currentConversation->messages()) {
        conv->messages.append(msg);
    }

    if (conv->title.isEmpty() && !conv->messages.isEmpty()) {
        conv->title = generateConversationTitle(conv->messages);
    }

    conv->updatedAt = QDateTime::currentMSecsSinceEpoch();

    markDirty(m_currentConversationId);
    saveDirtyConversations();
}

QString ConversationManager::currentConversationId() const
{
    return m_currentConversationId;
}

// ---------------------------------------------------------------- API payload

QVariantList ConversationManager::buildApiMessages(int contextLimit,
                                                   const QString &systemPrompt) const
{
    const QList<Message> &all = m_currentConversation->messages();

    // The pending assistant bubble is a UI placeholder; an empty content field
    // is rejected by the API, so it never belongs in the payload.
    int end = all.count();
    while (end > 0 && all.at(end - 1).role == "assistant"
           && all.at(end - 1).content.isEmpty()) {
        end--;
    }

    int start = 0;
    if (contextLimit > 0 && end > contextLimit) {
        start = end - contextLimit;
        // A history that opens on an assistant turn confuses the model.
        while (start < end && all.at(start).role != "user") {
            start++;
        }
    }

    QVariantList messages;

    if (!systemPrompt.trimmed().isEmpty()) {
        QVariantMap systemMsg;
        systemMsg["role"] = "system";
        systemMsg["content"] = systemPrompt.trimmed();
        messages.append(systemMsg);
    }

    for (int i = start; i < end; ++i) {
        const Message &msg = all.at(i);

        QVariantMap msgMap;
        msgMap["role"] = msg.role;

        // An attached image stays in the payload for every later turn,
        // otherwise a follow-up question about the picture has no picture.
        if (!msg.imagePath.isEmpty()) {
            const QString dataUrl = imageToDataUrl(msg.imagePath);
            if (!dataUrl.isEmpty()) {
                QVariantList parts;

                if (!msg.content.isEmpty()) {
                    QVariantMap textPart;
                    textPart["type"] = "text";
                    textPart["text"] = msg.content;
                    parts.append(textPart);
                }

                QVariantMap imagePart;
                imagePart["type"] = "image_url";
                imagePart["image_url"] = dataUrl;
                parts.append(imagePart);

                msgMap["content"] = parts;
                messages.append(msgMap);
                continue;
            }
        }

        msgMap["content"] = msg.content;
        messages.append(msgMap);
    }

    return messages;
}

int ConversationManager::trimmedMessageCount(int contextLimit) const
{
    if (contextLimit <= 0) {
        return 0;
    }

    const QList<Message> &all = m_currentConversation->messages();

    int end = all.count();
    while (end > 0 && all.at(end - 1).role == "assistant"
           && all.at(end - 1).content.isEmpty()) {
        end--;
    }

    if (end <= contextLimit) {
        return 0;
    }

    int start = end - contextLimit;
    while (start < end && all.at(start).role != "user") {
        start++;
    }
    return start;
}

// ---------------------------------------------------------------- overrides

QVariantMap ConversationManager::getConversationOverrides(const QString &conversationId) const
{
    QVariantMap overrides;
    overrides["model"] = QString();
    overrides["systemPrompt"] = QString();
    overrides["title"] = QString();
    overrides["category"] = QString();

    const Conversation *conv = findConversation(conversationId);
    if (conv) {
        overrides["model"] = conv->model;
        overrides["systemPrompt"] = conv->systemPrompt;
        overrides["title"] = conv->title;
        overrides["category"] = conv->category;
    }

    return overrides;
}

void ConversationManager::setConversationOverrides(const QString &conversationId,
                                                   const QString &model,
                                                   const QString &systemPrompt)
{
    Conversation *conv = findConversation(conversationId);
    if (!conv) {
        return;
    }

    conv->model = model.trimmed();
    conv->systemPrompt = systemPrompt.trimmed();
    markDirty(conversationId);
    saveDirtyConversations();
}

// ---------------------------------------------------------------- listing

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
        obj["category"] = conv.category;
        obj["model"] = conv.model;

        int userCount = 0;
        for (const Message &msg : conv.messages) {
            if (msg.role == "user") {
                userCount++;
            }
        }
        obj["userMessageCount"] = userCount;

        list.append(obj);
    }

    return list;
}

QVariant ConversationManager::getConversationDetails(const QString &conversationId) const
{
    QVariantMap details;

    const Conversation *conv = findConversation(conversationId);
    if (!conv) {
        return details;
    }

    details["id"] = conv->id;
    details["title"] = conv->title;
    details["createdAt"] = conv->createdAt;
    details["updatedAt"] = conv->updatedAt;

    QVariantList messagesList;
    for (const Message &msg : conv->messages) {
        QVariantMap msgMap;
        msgMap["role"] = msg.role;
        msgMap["content"] = msg.content;
        msgMap["timestamp"] = msg.timestamp;
        msgMap["imagePath"] = msg.imagePath;
        messagesList.append(msgMap);
    }
    details["messages"] = messagesList;
    details["messageCount"] = conv->messages.count();

    return details;
}

qint64 ConversationManager::getStorageSize() const
{
    qint64 total = 0;

    QDir dir(conversationsDir());
    if (dir.exists()) {
        const QFileInfoList files = dir.entryInfoList(QStringList() << "*.json", QDir::Files);
        for (const QFileInfo &info : files) {
            total += info.size();
        }
    }

    return total;
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
    m_dirtyIds.clear();
    m_currentConversationId.clear();

    QDir dir(conversationsDir());
    if (dir.exists()) {
        const QStringList files = dir.entryList(QStringList() << "*.json", QDir::Files);
        for (const QString &fileName : files) {
            QFile::remove(dir.filePath(fileName));
        }
    }

    m_settings.remove("lastConversationId");
    m_settings.sync();

    createNewConversation();

    emit conversationCountChanged();
}

// ---------------------------------------------------------------- pins & export

QVariantList ConversationManager::getPinnedMessages() const
{
    QVariantList result;

    for (const Conversation &conv : m_conversations) {
        for (int i = 0; i < conv.messages.count(); ++i) {
            const Message &msg = conv.messages.at(i);
            if (!msg.pinned) {
                continue;
            }
            QVariantMap entry;
            entry["conversationId"] = conv.id;
            entry["conversationTitle"] = conv.title.isEmpty() ? tr("Untitled") : conv.title;
            entry["messageIndex"] = i;
            entry["role"] = msg.role;
            entry["content"] = msg.content;
            entry["timestamp"] = msg.timestamp;
            result.append(entry);
        }
    }

    return result;
}

QString ConversationManager::conversationToMarkdown(const QString &conversationId) const
{
    const Conversation *conv = findConversation(conversationId);
    if (!conv) {
        return QString();
    }

    QString markdown;
    markdown += "# " + (conv->title.isEmpty() ? tr("Untitled") : conv->title) + "\n\n";
    markdown += QString("_Exported from SailCat - %1_\n\n")
            .arg(QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm"));

    for (const Message &msg : conv->messages) {
        markdown += (msg.role == "user") ? "## User\n\n" : "## Assistant\n\n";
        markdown += msg.content + "\n\n";
    }
    return markdown;
}

QString ConversationManager::exportConversation(const QString &conversationId) const
{
    const QString markdown = conversationToMarkdown(conversationId);
    if (markdown.isEmpty()) {
        return QString();
    }

    QString title;
    const Conversation *conv = findConversation(conversationId);
    if (conv) {
        title = conv->title;
    }

    // Filesystem-safe slug from the title
    QString slug = title.toLower();
    slug.replace(QRegExp("[^a-z0-9]+"), "-");
    slug.replace(QRegExp("(^-+|-+$)"), "");
    if (slug.length() > 40) {
        slug = slug.left(40);
    }
    if (slug.isEmpty()) {
        slug = "conversation";
    }

    QString dir = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    QString path = QString("%1/sailcat-%2-%3.md")
            .arg(dir)
            .arg(slug)
            .arg(QDateTime::currentDateTime().toString("yyyyMMdd-HHmmss"));

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "Export failed:" << file.errorString();
        return QString();
    }

    QTextStream stream(&file);
    // Qt 5.6 defaults to the locale codec; force UTF-8
    stream.setCodec("UTF-8");
    stream << markdown;
    file.close();

    // The export holds the whole conversation: keep it owner-only.
    SecureStore::restrictPermissions(path);

    return path;
}

// ---------------------------------------------------------------- images

QString ConversationManager::retainImage(const QString &filePath) const
{
    QString localPath = filePath;
    if (localPath.startsWith("file:")) {
        localPath = QUrl(localPath).toLocalFile();
    }
    if (localPath.isEmpty() || !QFile::exists(localPath)) {
        return filePath;
    }

    QImage img(localPath);
    if (img.isNull()) {
        return filePath;
    }

    if (img.width() > MAX_IMAGE_DIMENSION || img.height() > MAX_IMAGE_DIMENSION) {
        img = img.scaled(MAX_IMAGE_DIMENSION, MAX_IMAGE_DIMENSION,
                         Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }

    QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (base.isEmpty()) {
        base = QDir::homePath() + "/.local/share/harbour-sailcat";
    }
    const QString dir = base + "/images";
    QDir().mkpath(dir);
    SecureStore::restrictDirPermissions(dir);

    QString uuid = QUuid::createUuid().toString();
    uuid = uuid.mid(1, uuid.length() - 2);
    const QString target = dir + "/" + uuid + ".jpg";

    if (!img.save(target, "JPEG", JPEG_QUALITY)) {
        qWarning() << "Cannot retain image copy at" << target;
        return filePath;
    }

    SecureStore::restrictPermissions(target);
    return target;
}

QString ConversationManager::imageToDataUrl(const QString &filePath) const
{
    QString localPath = filePath;
    if (localPath.startsWith("file:")) {
        localPath = QUrl(localPath).toLocalFile();
    }

    QImage img(localPath);
    if (img.isNull()) {
        qWarning() << "Cannot load image:" << localPath;
        return QString();
    }

    // Downscale before encoding: keeps the request body small and the API happy
    if (img.width() > MAX_IMAGE_DIMENSION || img.height() > MAX_IMAGE_DIMENSION) {
        img = img.scaled(MAX_IMAGE_DIMENSION, MAX_IMAGE_DIMENSION,
                         Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }

    QByteArray bytes;
    QBuffer buffer(&bytes);
    buffer.open(QIODevice::WriteOnly);
    img.save(&buffer, "JPEG", JPEG_QUALITY);
    buffer.close();

    if (bytes.isEmpty()) {
        return QString();
    }

    return QString("data:image/jpeg;base64,") + QString::fromLatin1(bytes.toBase64());
}

// ---------------------------------------------------------------- statistics

void ConversationManager::addTokenUsage(int promptTokens, int completionTokens,
                                        const QString &model)
{
    if (promptTokens <= 0 && completionTokens <= 0) {
        return;
    }
    int total = promptTokens + completionTokens;

    m_totalPromptTokens += promptTokens;
    m_totalCompletionTokens += completionTokens;
    // Persist immediately so counters survive a crash
    m_settings.setValue("stats/totalPromptTokens", m_totalPromptTokens);
    m_settings.setValue("stats/totalCompletionTokens", m_totalCompletionTokens);

    // Daily series for the usage charts, pruned to ~2 months
    QJsonObject daily = QJsonDocument::fromJson(
                m_settings.value("stats/dailyTokens").toByteArray()).object();
    QString today = QDate::currentDate().toString("yyyy-MM-dd");
    daily[today] = daily[today].toInt() + total;

    QDate pruneLimit = QDate::currentDate().addDays(-62);
    const QStringList dailyKeys = daily.keys();
    for (const QString &key : dailyKeys) {
        if (QDate::fromString(key, "yyyy-MM-dd") < pruneLimit) {
            daily.remove(key);
        }
    }
    m_settings.setValue("stats/dailyTokens",
                        QJsonDocument(daily).toJson(QJsonDocument::Compact));

    // Per-model split, needed to turn tokens into a cost estimate
    Conversation *conv = findConversation(m_currentConversationId);
    if (!model.isEmpty()) {
        QJsonObject perModel = QJsonDocument::fromJson(
                    m_settings.value("stats/modelTokens").toByteArray()).object();
        QJsonObject entry = perModel[model].toObject();
        entry["prompt"] = entry["prompt"].toInt() + promptTokens;
        entry["completion"] = entry["completion"].toInt() + completionTokens;
        perModel[model] = entry;
        m_settings.setValue("stats/modelTokens",
                            QJsonDocument(perModel).toJson(QJsonDocument::Compact));
    }

    m_settings.sync();

    if (conv) {
        conv->totalTokens += total;
        markDirty(conv->id);
        saveDirtyConversations();
    }
}

QVariantMap ConversationManager::getConversationStatistics(const QString &conversationId) const
{
    QVariantMap stats;

    const Conversation *conv = findConversation(conversationId);
    if (!conv) {
        return stats;
    }

    int userCount = 0;
    int assistantCount = 0;
    qint64 totalChars = 0;
    qint64 userChars = 0;
    qint64 assistantChars = 0;
    int longestChars = 0;
    QVariantList rhythm;

    // Cap the rhythm chart to the last 40 messages
    int rhythmStart = qMax(0, conv->messages.count() - 40);

    for (int i = 0; i < conv->messages.count(); ++i) {
        const Message &msg = conv->messages.at(i);
        if (msg.role == "user") {
            userCount++;
            userChars += msg.content.length();
        } else {
            assistantCount++;
            assistantChars += msg.content.length();
        }
        totalChars += msg.content.length();
        longestChars = qMax(longestChars, msg.content.length());

        if (i >= rhythmStart) {
            QVariantMap bar;
            bar["chars"] = msg.content.length();
            bar["role"] = msg.role;
            rhythm.append(bar);
        }
    }

    int count = conv->messages.count();
    stats["messageCount"] = count;
    stats["userCount"] = userCount;
    stats["assistantCount"] = assistantCount;
    stats["totalChars"] = totalChars;
    stats["userChars"] = userChars;
    stats["assistantChars"] = assistantChars;
    stats["avgChars"] = count > 0 ? int(totalChars / count) : 0;
    stats["longestChars"] = longestChars;
    stats["estimatedTokens"] = totalChars / 4;
    stats["category"] = conv->category;
    stats["totalTokens"] = conv->totalTokens;

    qint64 durationMs = 0;
    if (count > 1) {
        durationMs = conv->messages.last().timestamp - conv->messages.first().timestamp;
    }
    stats["durationMs"] = durationMs;
    stats["rhythm"] = rhythm;

    return stats;
}

QVariantMap ConversationManager::getFunStats() const
{
    QVariantMap stats;

    // Common words not worth counting (French + English, all >= 4 chars)
    static const QSet<QString> stopWords = QSet<QString>::fromList(QString(
        "dans avec pour vous nous votre plus mais tout tous toute toutes elle elles cette comme "
        "aussi être fait faire peut cela sont donc entre sans sous vers leurs leur notre deux "
        "trois bien très voici ainsi alors avoir même mêmes autres autre chaque quand quelques "
        "peuvent exemple selon partie utiliser this that with from have your will which they "
        "them then than when what also more some such only very into over each other about "
        "would could should there their these those been does just like make made need want "
        "know time using used use example based here most however through while where because")
        .split(' '));

    QHash<QString, int> wordCounts;
    int longestUserChars = 0;
    qint64 hourSum = 0;
    int hourCount = 0;
    qint64 gapSum = 0;
    int gapCount = 0;
    int ghostCount = 0;

    for (const Conversation &conv : m_conversations) {
        int userCount = 0;
        qint64 lastUserTs = 0;

        for (const Message &msg : conv.messages) {
            if (msg.role == "user") {
                userCount++;
                longestUserChars = qMax(longestUserChars, msg.content.length());

                if (msg.timestamp > 0) {
                    hourSum += QDateTime::fromMSecsSinceEpoch(msg.timestamp).time().hour();
                    hourCount++;

                    if (lastUserTs > 0) {
                        qint64 gap = (msg.timestamp - lastUserTs) / 1000;
                        // Ignore long pauses: they are separate sessions, not typing speed
                        if (gap > 0 && gap < 1800) {
                            gapSum += gap;
                            gapCount++;
                        }
                    }
                    lastUserTs = msg.timestamp;
                }
            } else {
                const QStringList words = msg.content.toLower().split(
                            QRegExp(QString::fromUtf8("[^a-zà-öø-ÿ]+")), QString::SkipEmptyParts);
                for (const QString &word : words) {
                    if (word.length() >= 4 && !stopWords.contains(word)) {
                        wordCounts[word]++;
                    }
                }
            }
        }

        if (userCount == 1) {
            ghostCount++;
        }
    }

    // Top 5 words
    QList<QPair<int, QString> > sortedWords;
    for (QHash<QString, int>::const_iterator it = wordCounts.constBegin();
         it != wordCounts.constEnd(); ++it) {
        sortedWords.append(qMakePair(it.value(), it.key()));
    }
    std::sort(sortedWords.begin(), sortedWords.end(),
              [](const QPair<int, QString> &a, const QPair<int, QString> &b) {
        return a.first > b.first;
    });

    QVariantList topWords;
    for (int i = 0; i < sortedWords.count() && i < 5; ++i) {
        QVariantMap entry;
        entry["word"] = sortedWords.at(i).second;
        entry["count"] = sortedWords.at(i).first;
        topWords.append(entry);
    }

    stats["topWords"] = topWords;
    stats["longestUserChars"] = longestUserChars;
    stats["avgSendHour"] = hourCount > 0 ? int(hourSum / hourCount) : -1;
    stats["avgGapSecs"] = gapCount > 0 ? int(gapSum / gapCount) : -1;
    stats["ghostCount"] = ghostCount;

    return stats;
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
    qint64 totalUserChars = 0;
    qint64 totalAssistantChars = 0;
    QString longestConvTitle;
    QVariantMap categoryCounts;

    // Activity distribution: last 14 days (oldest first) and hour of day
    QDate today = QDate::currentDate();
    QVector<int> dayCounts(14, 0);
    QVector<int> hourCounts(24, 0);

    for (const Conversation &conv : m_conversations) {
        int convMessageCount = conv.messages.count();
        totalMessages += convMessageCount;

        if (convMessageCount > 0) {
            QString cat = conv.category.isEmpty() ? "other" : conv.category;
            categoryCounts[cat] = categoryCounts[cat].toInt() + 1;
        }

        if (convMessageCount > longestConvMessages) {
            longestConvMessages = convMessageCount;
            longestConvTitle = conv.title.isEmpty() ? tr("Untitled") : conv.title;
        }

        for (const Message &msg : conv.messages) {
            if (msg.role == "user") {
                totalUserMessages++;
                totalUserChars += msg.content.length();
            } else if (msg.role == "assistant") {
                totalAssistantMessages++;
                totalAssistantChars += msg.content.length();
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

            // Activity distribution
            if (msg.timestamp > 0) {
                QDateTime dt = QDateTime::fromMSecsSinceEpoch(msg.timestamp);
                int daysAgo = dt.date().daysTo(today);
                if (daysAgo >= 0 && daysAgo < 14) {
                    dayCounts[13 - daysAgo]++;
                }
                hourCounts[dt.time().hour()]++;
            }
        }
    }

    QVariantList messagesPerDay;
    for (int i = 0; i < 14; ++i) {
        messagesPerDay.append(dayCounts.at(i));
    }

    QVariantList messagesPerHour;
    for (int i = 0; i < 24; ++i) {
        messagesPerHour.append(hourCounts.at(i));
    }

    stats["totalMessages"] = totalMessages;
    stats["totalUserMessages"] = totalUserMessages;
    stats["totalAssistantMessages"] = totalAssistantMessages;
    stats["totalConversations"] = m_conversations.count();
    stats["longestConvMessages"] = longestConvMessages;
    stats["longestConvTitle"] = longestConvTitle;
    stats["longestMessageLength"] = longestMessageLength;
    stats["estimatedTokens"] = estimatedTokens;
    stats["totalPromptTokens"] = m_totalPromptTokens;
    stats["totalCompletionTokens"] = m_totalCompletionTokens;
    stats["totalTokens"] = m_totalPromptTokens + m_totalCompletionTokens;
    stats["totalUserChars"] = totalUserChars;
    stats["totalAssistantChars"] = totalAssistantChars;
    stats["categoryCounts"] = categoryCounts;

    // Token usage over time
    QJsonObject daily = QJsonDocument::fromJson(
                m_settings.value("stats/dailyTokens").toByteArray()).object();
    QVariantList tokensPerDay;
    qint64 tokensThisMonth = 0;
    for (int i = 13; i >= 0; --i) {
        QDate d = today.addDays(-i);
        tokensPerDay.append(daily[d.toString("yyyy-MM-dd")].toInt());
    }
    const QStringList dailyKeys = daily.keys();
    for (const QString &key : dailyKeys) {
        QDate d = QDate::fromString(key, "yyyy-MM-dd");
        if (d.year() == today.year() && d.month() == today.month()) {
            tokensThisMonth += daily[key].toInt();
        }
    }
    stats["tokensPerDay"] = tokensPerDay;
    stats["tokensThisMonth"] = tokensThisMonth;
    stats["firstMessageDate"] = firstMessageDate;
    stats["messagesPerDay"] = messagesPerDay;
    stats["messagesPerHour"] = messagesPerHour;

    // Per-model token split, so the UI can price it
    QJsonObject perModel = QJsonDocument::fromJson(
                m_settings.value("stats/modelTokens").toByteArray()).object();
    QVariantList modelUsage;
    const QStringList modelKeys = perModel.keys();
    for (const QString &key : modelKeys) {
        const QJsonObject entry = perModel[key].toObject();
        QVariantMap usage;
        usage["model"] = key;
        usage["promptTokens"] = entry["prompt"].toInt();
        usage["completionTokens"] = entry["completion"].toInt();
        modelUsage.append(usage);
    }
    stats["modelUsage"] = modelUsage;

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
        int userCount = 0;
        for (const Message &msg : conv.messages) {
            if (msg.role == "user") {
                userCount++;
            }
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
            result["userMessageCount"] = userCount;
            result["category"] = conv.category;
            result["matchCount"] = matchCount;
            result["matchPreview"] = matchPreview.isEmpty() ? tr("Match in title") : matchPreview;
            result["titleMatch"] = titleMatch;

            results.append(result);
        }
    }

    return results;
}

// ---------------------------------------------------------------- helpers

QString ConversationManager::generateConversationId() const
{
    // Qt 5.6 doesn't have QUuid::WithoutBraces, so we manually remove braces
    QString uuid = QUuid::createUuid().toString();
    return uuid.mid(1, uuid.length() - 2);  // Remove { and }
}

QString ConversationManager::generateConversationTitle(const QList<Message> &messages) const
{
    // Fallback title: the first user message, truncated
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

const Conversation* ConversationManager::findConversation(const QString &id) const
{
    for (int i = 0; i < m_conversations.count(); ++i) {
        if (m_conversations.at(i).id == id) {
            return &m_conversations.at(i);
        }
    }
    return nullptr;
}
