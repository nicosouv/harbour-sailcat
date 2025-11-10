#ifndef MISTRALAPI_H
#define MISTRALAPI_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QString>
#include <QJsonArray>

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
                                   const QVariant &messages);
    Q_INVOKABLE void cancelRequest();
    Q_INVOKABLE void clearError();

signals:
    void isBusyChanged();
    void errorChanged();
    void streamingResponse(const QString &content);
    void responseCompleted();
    void messageSent();

private slots:
    void onReadyRead();
    void onFinished();
    void onError(QNetworkReply::NetworkError error);

private:
    QNetworkAccessManager *m_networkManager;
    QNetworkReply *m_currentReply;
    bool m_isBusy;
    QString m_error;
    QString m_streamBuffer;

    void setIsBusy(bool busy);
    void setError(const QString &error);
    void processStreamData(const QByteArray &data);
    void parseStreamLine(const QString &line);
};

#endif // MISTRALAPI_H
