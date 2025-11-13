#include "updatechecker.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkRequest>
#include <QDebug>

UpdateChecker::UpdateChecker(QObject *parent)
    : QObject(parent)
    , m_networkManager(new QNetworkAccessManager(this))
    , m_currentVersion("1.9.2")
    , m_updateAvailable(false)
    , m_checking(false)
{
}

UpdateChecker::~UpdateChecker()
{
}

QString UpdateChecker::currentVersion() const
{
    return m_currentVersion;
}

QString UpdateChecker::latestVersion() const
{
    return m_latestVersion;
}

bool UpdateChecker::updateAvailable() const
{
    return m_updateAvailable;
}

bool UpdateChecker::checking() const
{
    return m_checking;
}

QString UpdateChecker::releaseUrl() const
{
    return m_releaseUrl;
}

void UpdateChecker::setLatestVersion(const QString &version)
{
    if (m_latestVersion != version) {
        m_latestVersion = version;
        emit latestVersionChanged();
    }
}

void UpdateChecker::setUpdateAvailable(bool available)
{
    if (m_updateAvailable != available) {
        m_updateAvailable = available;
        emit updateAvailableChanged();
    }
}

void UpdateChecker::setChecking(bool checking)
{
    if (m_checking != checking) {
        m_checking = checking;
        emit checkingChanged();
    }
}

void UpdateChecker::setReleaseUrl(const QString &url)
{
    if (m_releaseUrl != url) {
        m_releaseUrl = url;
        emit releaseUrlChanged();
    }
}

void UpdateChecker::checkForUpdates()
{
    setChecking(true);
    setUpdateAvailable(false);

    QUrl url("https://api.github.com/repos/nicosouv/harbour-sailcat/releases/latest");
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, "SailCat-SailfishOS");

    QNetworkReply *reply = m_networkManager->get(request);
    connect(reply, &QNetworkReply::finished, this, &UpdateChecker::handleNetworkReply);
}

void UpdateChecker::handleNetworkReply()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) {
        setChecking(false);
        return;
    }

    if (reply->error() == QNetworkReply::NoError) {
        QByteArray data = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(data);

        if (doc.isObject()) {
            QJsonObject obj = doc.object();
            QString tagName = obj.value("tag_name").toString();
            QString htmlUrl = obj.value("html_url").toString();

            // Remove 'v' prefix if present
            if (tagName.startsWith("v")) {
                tagName = tagName.mid(1);
            }

            setLatestVersion(tagName);
            setReleaseUrl(htmlUrl);

            // Check if update is available
            if (isNewerVersion(tagName, m_currentVersion)) {
                setUpdateAvailable(true);
            }
        }
    } else {
        qWarning() << "Update check failed:" << reply->errorString();
    }

    setChecking(false);
    reply->deleteLater();
}

bool UpdateChecker::isNewerVersion(const QString &latest, const QString &current) const
{
    QStringList latestParts = latest.split('.');
    QStringList currentParts = current.split('.');

    // Pad with zeros if needed
    while (latestParts.size() < 3) latestParts.append("0");
    while (currentParts.size() < 3) currentParts.append("0");

    // Compare major, minor, patch
    for (int i = 0; i < 3; ++i) {
        int latestNum = latestParts[i].toInt();
        int currentNum = currentParts[i].toInt();

        if (latestNum > currentNum) {
            return true;
        } else if (latestNum < currentNum) {
            return false;
        }
    }

    return false; // Versions are equal
}
