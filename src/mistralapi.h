#ifndef MISTRALAPI_H
#define MISTRALAPI_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>
#include <QString>
#include <QByteArray>
#include <QTimer>
#include <QElapsedTimer>
#include <QJsonArray>
#include <QVariant>

#include "providers.h"

// Talks the OpenAI chat-completions dialect, which every supported backend
// speaks: only the endpoint and a few quirks come from the provider, through
// setEndpoint(). The class keeps its name because the app started Mistral-only.
class MistralAPI : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isBusy READ isBusy NOTIFY isBusyChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)

public:
    explicit MistralAPI(QObject *parent = nullptr);

    bool isBusy() const;
    QString error() const;

    // Points every request at a provider. Called once at startup and again on
    // every provider change, from C++, so no caller can forget to.
    void setEndpoint(const QString &providerId,
                     const QString &baseUrl,
                     Providers::ModelSource modelSource,
                     bool streamUsageOption,
                     bool keyRequired);

    Q_INVOKABLE void sendMessage(const QString &apiKey,
                                   const QString &modelName,
                                   const QVariant &messages,
                                   double temperature = -1.0,
                                   int maxTokens = 0);
    // targetId is echoed back with the result so a caller can tell which
    // conversation the title belongs to.
    Q_INVOKABLE void generateTitle(const QString &apiKey,
                                     const QString &modelName,
                                     const QString &conversationText,
                                     const QString &targetId = QString());
    Q_INVOKABLE void fetchModels(const QString &apiKey);
    Q_INVOKABLE void cancelRequest();
    Q_INVOKABLE void clearError();

signals:
    void isBusyChanged();
    void errorChanged();
    void streamingResponse(const QString &content);
    void usageReceived(int promptTokens, int completionTokens);
    // Tokens spent by an auxiliary call (title generation): billed, but not
    // part of the conversation the token banner reports on.
    void sideRequestUsage(int promptTokens, int completionTokens);
    void responseCompleted();
    void messageSent();
    void titleGenerated(const QString &title, const QString &category,
                        const QString &targetId);
    void titleGenerationFailed(const QString &targetId);
    // The provider travels with the catalogue: by the time the answer lands,
    // the user may have moved to a conversation pinned somewhere else.
    void modelsFetched(const QVariantList &models, const QString &providerId);
    void modelsFetchFailed();
    // The provider turned the request away (429/503) and it will be sent
    // again: the answer is still coming, so this is not an error yet.
    void rateLimited(int seconds, int attempt, int maxAttempts);

private slots:
    void onReadyRead();
    void onFinished();
    void onError(QNetworkReply::NetworkError error);
    void onTitleGenerationFinished();
    void onModelsFetchFinished();
    void onTimeout();
    void sendPendingChatRequest();

private:
    friend class TestMistralAPI;

    QNetworkAccessManager *m_networkManager;
    QNetworkReply *m_currentReply;
    QTimer *m_timeoutTimer;
    // Holds a chat request back, either to space it out or to retry it.
    QTimer *m_requestTimer;
    // Since the last request actually left, whatever its kind.
    QElapsedTimer m_lastRequestAt;
    bool m_isBusy;
    bool m_timedOut;
    QString m_error;
    QByteArray m_streamBuffer;
    QString m_providerId;
    QString m_baseUrl;
    Providers::ModelSource m_modelSource;
    bool m_streamUsageOption;
    bool m_keyRequired;
    int m_minRequestIntervalMs;
    int m_retryCount;
    // Content already reached the screen: resending would duplicate it.
    bool m_streamStarted;
    // The chat request as sent, kept in memory only, so a rate-limited call
    // can go out again without the UI having to know it ever failed.
    QString m_pendingApiKey;
    QByteArray m_pendingBody;

    void setIsBusy(bool busy);
    void setError(const QString &error);
    // Endpoint URL, or an invalid one when no base URL is configured.
    QUrl endpoint(const QString &path) const;
    // Content type, bearer token when there is one, TLS pinning.
    void prepareRequest(QNetworkRequest &request, const QString &apiKey) const;
    void processStreamData(const QByteArray &data);
    void parseStreamLine(const QString &line);
    // True while the same request is still worth sending again.
    bool shouldRetry(int httpStatus) const;
    // Milliseconds to wait before a request may leave, 0 when the gate is open.
    int throttleDelayMs() const;
    void noteRequestSent();
    // Sends the stored chat request, after extraDelayMs and the throttle.
    void queueChatRequest(int extraDelayMs);
    void forgetPendingRequest();
};

#endif // MISTRALAPI_H
