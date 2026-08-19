#ifndef MISTRALAPI_H
#define MISTRALAPI_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QString>
#include <QByteArray>
#include <QTimer>
#include <QJsonArray>
#include <QVariant>

class MistralAPI : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isBusy READ isBusy NOTIFY isBusyChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)

public:
    explicit MistralAPI(QObject *parent = nullptr);

    bool isBusy() const;
    QString error() const;

    Q_INVOKABLE void sendMessage(const QString &apiKey,
                                   const QString &modelName,
                                   const QVariant &messages,
                                   double temperature = -1.0,
                                   int maxTokens = 0);
    Q_INVOKABLE void generateTitle(const QString &apiKey,
                                     const QString &modelName,
                                     const QString &firstUserMessage);
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
    void titleGenerated(const QString &title, const QString &category);
    void modelsFetched(const QVariantList &models);
    void modelsFetchFailed();

private slots:
    void onReadyRead();
    void onFinished();
    void onError(QNetworkReply::NetworkError error);
    void onTitleGenerationFinished();
    void onModelsFetchFinished();
    void onTimeout();

private:
    friend class TestMistralAPI;

    QNetworkAccessManager *m_networkManager;
    QNetworkReply *m_currentReply;
    QTimer *m_timeoutTimer;
    bool m_isBusy;
    bool m_timedOut;
    QString m_error;
    QByteArray m_streamBuffer;

    void setIsBusy(bool busy);
    void setError(const QString &error);
    void processStreamData(const QByteArray &data);
    void parseStreamLine(const QString &line);
};

#endif // MISTRALAPI_H
