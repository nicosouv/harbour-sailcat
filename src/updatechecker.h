#ifndef UPDATECHECKER_H
#define UPDATECHECKER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QString>

class UpdateChecker : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString currentVersion READ currentVersion CONSTANT)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY latestVersionChanged)
    Q_PROPERTY(bool updateAvailable READ updateAvailable NOTIFY updateAvailableChanged)
    Q_PROPERTY(bool checking READ checking NOTIFY checkingChanged)
    Q_PROPERTY(QString releaseUrl READ releaseUrl NOTIFY releaseUrlChanged)

public:
    explicit UpdateChecker(QObject *parent = nullptr);
    ~UpdateChecker();

    QString currentVersion() const;
    QString latestVersion() const;
    bool updateAvailable() const;
    bool checking() const;
    QString releaseUrl() const;

public slots:
    void checkForUpdates();

signals:
    void latestVersionChanged();
    void updateAvailableChanged();
    void checkingChanged();
    void releaseUrlChanged();

private slots:
    void handleNetworkReply();

private:
    QNetworkAccessManager *m_networkManager;
    QString m_currentVersion;
    QString m_latestVersion;
    bool m_updateAvailable;
    bool m_checking;
    QString m_releaseUrl;

    void setLatestVersion(const QString &version);
    void setUpdateAvailable(bool available);
    void setChecking(bool checking);
    void setReleaseUrl(const QString &url);
    bool isNewerVersion(const QString &latest, const QString &current) const;
};

#endif // UPDATECHECKER_H
