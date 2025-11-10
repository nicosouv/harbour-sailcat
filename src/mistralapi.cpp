#include "mistralapi.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkRequest>
#include <QDebug>

MistralAPI::MistralAPI(QObject *parent)
    : QObject(parent)
    , m_networkManager(new QNetworkAccessManager(this))
    , m_currentReply(nullptr)
    , m_isBusy(false)
{
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
                               const QVariant &messagesVariant)
{
    if (m_isBusy) {
        qWarning() << "Request already in progress";
        return;
    }

    if (apiKey.isEmpty()) {
        setError(tr("Missing API key. Please configure your API key in settings."));
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
        msgObj["content"] = msgMap["content"].toString();
        messages.append(msgObj);
    }

    setIsBusy(true);
    setError(QString());
    m_streamBuffer.clear();

    // Construire la requête JSON
    QJsonObject requestBody;
    requestBody["model"] = modelName;
    requestBody["messages"] = messages;
    requestBody["stream"] = true;

    QJsonDocument doc(requestBody);
    QByteArray jsonData = doc.toJson();

    qDebug() << "Sending request to Mistral API";
    qDebug() << "Model:" << modelName;
    qDebug() << "Messages count:" << messages.count();
    qDebug() << "Request body:" << QString::fromUtf8(jsonData);

    // Configurer la requête HTTP
    QNetworkRequest request(QUrl("https://api.mistral.ai/v1/chat/completions"));
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("Authorization", QString("Bearer %1").arg(apiKey).toUtf8());
    request.setRawHeader("Accept", "text/event-stream");

    // Envoyer la requête
    m_currentReply = m_networkManager->post(request, jsonData);

    connect(m_currentReply, &QNetworkReply::readyRead,
            this, &MistralAPI::onReadyRead);
    connect(m_currentReply, &QNetworkReply::finished,
            this, &MistralAPI::onFinished);
    connect(m_currentReply, SIGNAL(error(QNetworkReply::NetworkError)),
            this, SLOT(onError(QNetworkReply::NetworkError)));

    emit messageSent();
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

    QByteArray data = m_currentReply->readAll();
    qDebug() << "Received data from API:" << data.size() << "bytes";
    qDebug() << "Data preview:" << QString::fromUtf8(data.left(200));
    processStreamData(data);
}

void MistralAPI::onFinished()
{
    if (!m_currentReply)
        return;

    qDebug() << "Request finished with status:" << m_currentReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    qDebug() << "Error code:" << m_currentReply->error();

    // Traiter les données restantes
    if (m_currentReply->error() == QNetworkReply::NoError) {
        QByteArray remaining = m_currentReply->readAll();
        if (!remaining.isEmpty()) {
            qDebug() << "Processing remaining data:" << remaining.size() << "bytes";
            processStreamData(remaining);
        }
    } else {
        qDebug() << "Request failed:" << m_currentReply->errorString();
    }

    m_currentReply->deleteLater();
    m_currentReply = nullptr;
    setIsBusy(false);

    emit responseCompleted();
}

void MistralAPI::onError(QNetworkReply::NetworkError error)
{
    Q_UNUSED(error);

    if (!m_currentReply)
        return;

    QString errorString = m_currentReply->errorString();
    QByteArray responseData = m_currentReply->readAll();

    // Essayer d'extraire un message d'erreur plus détaillé du JSON
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
    m_streamBuffer.append(QString::fromUtf8(data));

    // Traiter les lignes complètes (terminées par \n)
    while (m_streamBuffer.contains('\n')) {
        int newlinePos = m_streamBuffer.indexOf('\n');
        QString line = m_streamBuffer.left(newlinePos).trimmed();
        m_streamBuffer.remove(0, newlinePos + 1);

        if (!line.isEmpty()) {
            parseStreamLine(line);
        }
    }
}

void MistralAPI::parseStreamLine(const QString &line)
{
    // Le format SSE (Server-Sent Events) utilise "data: " comme préfixe
    if (!line.startsWith("data: ")) {
        qDebug() << "Line doesn't start with 'data: ':" << line.left(50);
        return;
    }

    QString jsonData = line.mid(6); // Supprimer "data: "

    // Vérifier si c'est le marqueur de fin
    if (jsonData == "[DONE]") {
        qDebug() << "Received [DONE] marker";
        return;
    }

    // Parser le JSON
    QJsonDocument doc = QJsonDocument::fromJson(jsonData.toUtf8());
    if (!doc.isObject()) {
        qDebug() << "Failed to parse JSON:" << jsonData.left(100);
        return;
    }

    QJsonObject obj = doc.object();

    // Extraire le contenu du delta
    QJsonArray choices = obj["choices"].toArray();
    if (!choices.isEmpty()) {
        QJsonObject choice = choices.at(0).toObject();
        QJsonObject delta = choice["delta"].toObject();

        if (delta.contains("content")) {
            QString content = delta["content"].toString();
            if (!content.isEmpty()) {
                qDebug() << "Emitting content:" << content;
                emit streamingResponse(content);
            }
        }
    } else {
        qDebug() << "No choices in response:" << QString::fromUtf8(doc.toJson(QJsonDocument::Compact));
    }
}
