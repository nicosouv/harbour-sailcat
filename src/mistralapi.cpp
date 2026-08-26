#include "mistralapi.h"
#include "categories.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkRequest>
#include <QSslConfiguration>
#include <QSslSocket>
#include <QDebug>
#include <QStringList>
#include <algorithm>

static const int REQUEST_TIMEOUT_MS = 60000;

// Require a verified peer and refuse the legacy TLS versions rather than
// inheriting the platform default. A custom endpoint may well be plain HTTP on
// the local network, in which case none of this applies and Qt ignores it.
static void applyTransportSecurity(QNetworkRequest &request)
{
    QSslConfiguration ssl = QSslConfiguration::defaultConfiguration();
    ssl.setProtocol(QSsl::TlsV1_2OrLater);
    ssl.setPeerVerifyMode(QSslSocket::VerifyPeer);
    request.setSslConfiguration(ssl);

    // Do not let a redirect move the request (and its bearer token) elsewhere.
    request.setAttribute(QNetworkRequest::FollowRedirectsAttribute, false);
}

MistralAPI::MistralAPI(QObject *parent)
    : QObject(parent)
    , m_networkManager(new QNetworkAccessManager(this))
    , m_currentReply(nullptr)
    , m_timeoutTimer(new QTimer(this))
    , m_isBusy(false)
    , m_timedOut(false)
    , m_modelSource(Providers::MistralCatalogue)
    , m_streamUsageOption(false)
    , m_keyRequired(true)
{
    m_timeoutTimer->setSingleShot(true);
    m_timeoutTimer->setInterval(REQUEST_TIMEOUT_MS);
    connect(m_timeoutTimer, &QTimer::timeout, this, &MistralAPI::onTimeout);

    // Sensible until the settings have been read.
    const Providers::Provider fallback = Providers::byId(Providers::defaultId());
    setEndpoint(fallback.id, fallback.baseUrl, fallback.modelSource,
                fallback.streamUsageOption, fallback.keyRequired);
}

void MistralAPI::setEndpoint(const QString &providerId,
                             const QString &baseUrl,
                             Providers::ModelSource modelSource,
                             bool streamUsageOption,
                             bool keyRequired)
{
    m_providerId = providerId;
    m_baseUrl = baseUrl;
    m_modelSource = modelSource;
    m_streamUsageOption = streamUsageOption;
    m_keyRequired = keyRequired;
}

QUrl MistralAPI::endpoint(const QString &path) const
{
    if (m_baseUrl.isEmpty()) {
        return QUrl();
    }
    return QUrl(m_baseUrl + path);
}

void MistralAPI::prepareRequest(QNetworkRequest &request, const QString &apiKey) const
{
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    // A provider that answers anonymously gets no header at all: an empty
    // bearer token is worse than none.
    if (!apiKey.isEmpty()) {
        request.setRawHeader("Authorization", QString("Bearer %1").arg(apiKey).toUtf8());
    }
    applyTransportSecurity(request);
}

bool MistralAPI::isBusy() const
{
    return m_isBusy;
}

QString MistralAPI::error() const
{
    return m_error;
}

void MistralAPI::sendMessage(const QString &apiKey,
                               const QString &modelName,
                               const QVariant &messagesVariant,
                               double temperature,
                               int maxTokens)
{
    if (m_isBusy) {
        qWarning() << "Request already in progress";
        return;
    }

    if (apiKey.isEmpty() && m_keyRequired) {
        setError(tr("Missing API key. Please configure your API key in settings."));
        return;
    }

    if (m_baseUrl.isEmpty()) {
        setError(tr("No endpoint configured. Please pick a provider in settings."));
        return;
    }

    // Convert QVariant (QVariantList) to QJsonArray
    QVariantList messagesList = messagesVariant.toList();
    if (messagesList.isEmpty()) {
        qWarning() << "Messages list is empty or invalid";
        setError(tr("Failed to prepare messages for API"));
        return;
    }

    QJsonArray messages;
    for (const QVariant &msgVariant : messagesList) {
        QVariantMap msgMap = msgVariant.toMap();
        QJsonObject msgObj;
        msgObj["role"] = msgMap["role"].toString();

        // Vision messages use an array of {type, ...} parts instead of a
        // string. Test by conversion rather than by type tag: a value that
        // travelled through QML may arrive as any of several list flavours,
        // while a string always converts to an empty list.
        const QVariant contentVar = msgMap["content"];
        const QVariantList parts = contentVar.toList();
        if (!parts.isEmpty()) {
            msgObj["content"] = QJsonArray::fromVariantList(parts);
        } else {
            msgObj["content"] = contentVar.toString();
        }
        messages.append(msgObj);
    }

    setIsBusy(true);
    setError(QString());
    m_streamBuffer.clear();
    m_timedOut = false;

    // Build JSON request
    QJsonObject requestBody;
    requestBody["model"] = modelName;
    requestBody["messages"] = messages;
    requestBody["stream"] = true;

    // Omit unset parameters so the API applies its own defaults
    if (temperature >= 0.0) {
        requestBody["temperature"] = temperature;
    }
    if (maxTokens > 0) {
        requestBody["max_tokens"] = maxTokens;
    }

    // Mistral reports token usage in the last chunk on its own; the OpenAI
    // dialect only does when asked, and rejects the field where unsupported.
    if (m_streamUsageOption) {
        QJsonObject streamOptions;
        streamOptions["include_usage"] = true;
        requestBody["stream_options"] = streamOptions;
    }

    QJsonDocument doc(requestBody);
    QByteArray jsonData = doc.toJson();

    // Configure HTTP request
    QNetworkRequest request(endpoint("/chat/completions"));
    request.setRawHeader("Accept", "text/event-stream");
    prepareRequest(request, apiKey);

    // Send request
    m_currentReply = m_networkManager->post(request, jsonData);

    connect(m_currentReply, &QNetworkReply::readyRead,
            this, &MistralAPI::onReadyRead);
    connect(m_currentReply, &QNetworkReply::finished,
            this, &MistralAPI::onFinished);
    connect(m_currentReply, SIGNAL(error(QNetworkReply::NetworkError)),
            this, SLOT(onError(QNetworkReply::NetworkError)));

    m_timeoutTimer->start();

    emit messageSent();
}

void MistralAPI::generateTitle(const QString &apiKey,
                                 const QString &modelName,
                                 const QString &conversationText,
                                 const QString &targetId)
{
    if ((apiKey.isEmpty() && m_keyRequired) || m_baseUrl.isEmpty()
            || conversationText.trimmed().isEmpty()) {
        emit titleGenerationFailed(targetId);
        return;
    }

    // Build request for title generation (non-streaming)
    QJsonArray messages;
    QJsonObject systemMsg;
    systemMsg["role"] = "system";
    // "other" is deliberately described as a last resort: left to itself the
    // model picks it far too often and every conversation ends up unlabelled.
    systemMsg["content"] = QString(
                "Analyze the conversation excerpt sent by the user and reply with ONLY a "
                "compact JSON object, no explanation, no code fences: "
                "{\"title\":\"short conversation title, max 50 characters, same language as "
                "the conversation\",\"category\":\"one of the labels below\"}. "
                "Pick the single most specific matching category from this list: %1. "
                "Use \"other\" only when no other label fits at all.")
            .arg(Categories::all().join(", "));
    messages.append(systemMsg);

    QJsonObject userMsg;
    userMsg["role"] = "user";
    userMsg["content"] = conversationText;
    messages.append(userMsg);

    QJsonObject requestBody;
    requestBody["model"] = modelName;
    requestBody["messages"] = messages;
    requestBody["stream"] = false;  // Non-streaming for title generation

    QJsonDocument doc(requestBody);
    QByteArray jsonData = doc.toJson();

    // Configure HTTP request
    QNetworkRequest request(endpoint("/chat/completions"));
    prepareRequest(request, apiKey);

    // Send request
    QNetworkReply *reply = m_networkManager->post(request, jsonData);
    // Carried on the reply so the result can be routed back to the right
    // conversation: several of these can be in flight at once.
    reply->setProperty("targetId", targetId);

    connect(reply, &QNetworkReply::finished,
            this, &MistralAPI::onTitleGenerationFinished);
}

void MistralAPI::fetchModels(const QString &apiKey)
{
    if ((apiKey.isEmpty() && m_keyRequired) || m_baseUrl.isEmpty()) {
        emit modelsFetchFailed();
        return;
    }

    QNetworkRequest request(endpoint("/models"));
    prepareRequest(request, apiKey);

    QNetworkReply *reply = m_networkManager->get(request);
    // Pinned to the reply: the active provider may change before it answers
    reply->setProperty("providerId", m_providerId);
    reply->setProperty("modelSource", int(m_modelSource));

    connect(reply, &QNetworkReply::finished,
            this, &MistralAPI::onModelsFetchFinished);
}

void MistralAPI::cancelRequest()
{
    if (m_currentReply) {
        m_currentReply->abort();
    }
}

void MistralAPI::clearError()
{
    setError(QString());
}

void MistralAPI::onReadyRead()
{
    if (!m_currentReply)
        return;

    // Restart timeout on activity so long streams are not aborted
    m_timeoutTimer->start();
    processStreamData(m_currentReply->readAll());
}

void MistralAPI::onFinished()
{
    if (!m_currentReply)
        return;

    m_timeoutTimer->stop();

    // Process remaining data
    if (m_currentReply->error() == QNetworkReply::NoError) {
        QByteArray remaining = m_currentReply->readAll();
        if (!remaining.isEmpty()) {
            processStreamData(remaining);
        }
    }

    m_currentReply->deleteLater();
    m_currentReply = nullptr;
    setIsBusy(false);

    emit responseCompleted();
}

void MistralAPI::onError(QNetworkReply::NetworkError error)
{
    if (!m_currentReply)
        return;

    // User cancellation is not an error; timeout gets its own message
    if (error == QNetworkReply::OperationCanceledError) {
        if (m_timedOut) {
            setError(tr("Request timed out. Please check your connection."));
        }
        return;
    }

    QString errorString = m_currentReply->errorString();
    QByteArray responseData = m_currentReply->readAll();

    // Try to extract a more detailed error message from the JSON body
    if (!responseData.isEmpty()) {
        QJsonDocument doc = QJsonDocument::fromJson(responseData);
        if (doc.isObject()) {
            QJsonObject obj = doc.object();
            if (obj.contains("error")) {
                QJsonValue errorValue = obj["error"];
                if (errorValue.isObject()) {
                    QString message = errorValue.toObject()["message"].toString();
                    if (!message.isEmpty()) {
                        errorString = message;
                    }
                } else if (errorValue.isString()) {
                    errorString = errorValue.toString();
                }
            }
        }
    }

    setError(tr("API Error: %1").arg(errorString));
    qWarning() << "API Error:" << errorString;
}

void MistralAPI::setIsBusy(bool busy)
{
    if (m_isBusy != busy) {
        m_isBusy = busy;
        emit isBusyChanged();
    }
}

void MistralAPI::setError(const QString &error)
{
    if (m_error != error) {
        m_error = error;
        emit errorChanged();
    }
}

void MistralAPI::processStreamData(const QByteArray &data)
{
    // Buffer raw bytes: a multi-byte UTF-8 character can be split across
    // network chunks, so decode only complete lines
    m_streamBuffer.append(data);

    int newlinePos;
    while ((newlinePos = m_streamBuffer.indexOf('\n')) != -1) {
        QString line = QString::fromUtf8(m_streamBuffer.left(newlinePos)).trimmed();
        m_streamBuffer.remove(0, newlinePos + 1);

        if (!line.isEmpty()) {
            parseStreamLine(line);
        }
    }
}

void MistralAPI::onTimeout()
{
    if (m_currentReply) {
        m_timedOut = true;
        m_currentReply->abort();
    }
}

void MistralAPI::onTitleGenerationFinished()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply)
        return;

    const QString targetId = reply->property("targetId").toString();
    bool delivered = false;

    if (reply->error() == QNetworkReply::NoError) {
        QByteArray responseData = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(responseData);

        if (doc.isObject()) {
            QJsonObject obj = doc.object();

            // Titling is billed like any other call: report it so the token
            // counters match the invoice.
            if (obj.contains("usage") && obj["usage"].isObject()) {
                QJsonObject usage = obj["usage"].toObject();
                emit sideRequestUsage(usage["prompt_tokens"].toInt(),
                                      usage["completion_tokens"].toInt());
            }

            QJsonArray choices = obj["choices"].toArray();

            if (!choices.isEmpty()) {
                QJsonObject choice = choices.at(0).toObject();
                QJsonObject message = choice["message"].toObject();
                QString content = message["content"].toString().trimmed();

                QString title;
                QString category;

                // Extract the JSON object even if wrapped in fences or prose
                int start = content.indexOf('{');
                int end = content.lastIndexOf('}');
                if (start >= 0 && end > start) {
                    QJsonDocument titleDoc = QJsonDocument::fromJson(
                                content.mid(start, end - start + 1).toUtf8());
                    if (titleDoc.isObject()) {
                        title = titleDoc.object()["title"].toString().trimmed();
                        category = titleDoc.object()["category"].toString().trimmed().toLower();
                    }
                }

                // Fallback: model ignored the JSON format, use raw content as title
                if (title.isEmpty()) {
                    title = content;
                    if (title.startsWith("\"") && title.endsWith("\"")) {
                        title = title.mid(1, title.length() - 2);
                    }
                }

                if (!Categories::isValid(category)) {
                    category = "other";
                }

                if (title.length() > 50) {
                    title = title.left(47) + "...";
                }

                if (!title.isEmpty()) {
                    delivered = true;
                    emit titleGenerated(title, category, targetId);
                }
            }
        }
    } else {
        qWarning() << "Title generation failed:" << reply->errorString();
    }

    if (!delivered) {
        emit titleGenerationFailed(targetId);
    }

    reply->deleteLater();
}

void MistralAPI::onModelsFetchFinished()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply)
        return;

    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        qWarning() << "Models fetch failed:" << reply->errorString();
        emit modelsFetchFailed();
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    if (!doc.isObject()) {
        emit modelsFetchFailed();
        return;
    }

    const QString providerId = reply->property("providerId").toString();
    const Providers::ModelSource modelSource =
            Providers::ModelSource(reply->property("modelSource").toInt());

    QJsonArray data = doc.object()["data"].toArray();
    QStringList ids;
    QVariantList models;

    for (const QJsonValue &value : data) {
        QJsonObject modelObj = value.toObject();
        QString id = modelObj["id"].toString();
        QJsonObject caps = modelObj["capabilities"].toObject();
        bool vision = false;

        if (modelSource == Providers::MistralCatalogue) {
            // Keep only current chat models; dated aliases add noise
            if (!caps["completion_chat"].toBool() || !id.endsWith("-latest")) {
                continue;
            }
            vision = caps["vision"].toBool();
        } else {
            // The OpenAI catalogue describes nothing but an id, and mixes in
            // embeddings, speech and image models. Filter by name, and drop
            // entries the provider says cannot complete anything.
            if (!Providers::isChatModelId(id)) {
                continue;
            }
            if (modelObj.contains("max_completion_tokens")
                    && modelObj["max_completion_tokens"].toInt() == 0) {
                continue;
            }
            // Some of them do fill in capabilities; believe them over the name.
            vision = caps.contains("vision") ? caps["vision"].toBool()
                                             : Providers::looksLikeVisionModel(id);
        }

        if (ids.contains(id)) {
            continue;
        }
        ids.append(id);

        QVariantMap entry;
        entry["id"] = id;
        entry["vision"] = vision;
        models.append(entry);
    }

    if (models.isEmpty()) {
        emit modelsFetchFailed();
        return;
    }

    // Sort alphabetically by id
    std::sort(models.begin(), models.end(),
              [](const QVariant &a, const QVariant &b) {
        return a.toMap()["id"].toString() < b.toMap()["id"].toString();
    });

    emit modelsFetched(models, providerId);
}

void MistralAPI::parseStreamLine(const QString &line)
{
    // SSE (Server-Sent Events) format uses "data: " as prefix
    if (!line.startsWith("data: ")) {
        return;
    }

    QString jsonData = line.mid(6); // Remove "data: "

    // Check for end-of-stream marker
    if (jsonData == "[DONE]") {
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(jsonData.toUtf8());
    if (!doc.isObject()) {
        return;
    }

    QJsonObject obj = doc.object();

    // The final chunk before [DONE] carries token usage
    if (obj.contains("usage") && obj["usage"].isObject()) {
        QJsonObject usage = obj["usage"].toObject();
        emit usageReceived(usage["prompt_tokens"].toInt(),
                           usage["completion_tokens"].toInt());
    }

    // Extract delta content
    QJsonArray choices = obj["choices"].toArray();
    if (!choices.isEmpty()) {
        QJsonObject choice = choices.at(0).toObject();
        QJsonObject delta = choice["delta"].toObject();

        if (delta.contains("content")) {
            QString content = delta["content"].toString();
            if (!content.isEmpty()) {
                emit streamingResponse(content);
            }
        }
    }
}
