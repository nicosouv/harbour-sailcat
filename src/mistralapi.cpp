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
                               const QJsonArray &messages)
{
    if (m_isBusy) {
        qWarning() << "Request already in progress";
        return;
    }

    if (apiKey.isEmpty()) {
        setError(tr("Missing API key. Please configure your API key in settings."));
        return;
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
    processStreamData(data);
}

void MistralAPI::onFinished()
{
    if (!m_currentReply)
        return;

    // Traiter les données restantes
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
        return;
    }

    QString jsonData = line.mid(6); // Supprimer "data: "

    // Vérifier si c'est le marqueur de fin
    if (jsonData == "[DONE]") {
        return;
    }

    // Parser le JSON
    QJsonDocument doc = QJsonDocument::fromJson(jsonData.toUtf8());
    if (!doc.isObject()) {
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
                emit streamingResponse(content);
            }
        }
    }
}
