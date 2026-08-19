#include "securestore.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QUuid>
#include <QDebug>

namespace {

// 4 bytes of magic so a legacy plain-text value is never mistaken for a
// ciphertext, plus a version digit to allow changing the scheme later.
const char OBFUSCATION_MAGIC[] = "SCK1";

// Digest prefix stored with the payload: lets deobfuscate() tell "wrong salt"
// apart from "valid empty value".
const int CHECKSUM_BYTES = 4;

QByteArray g_salt;
bool g_saltLoaded = false;
bool g_saltPersisted = false;

void loadOrCreateSalt()
{
    if (g_saltLoaded) {
        return;
    }
    g_saltLoaded = true;

    const QString path = SecureStore::saltFilePath();

    QFile file(path);
    if (file.exists() && file.open(QIODevice::ReadOnly)) {
        const QByteArray existing = file.readAll();
        file.close();
        if (existing.size() >= 32) {
            g_salt = existing;
            g_saltPersisted = true;
            return;
        }
    }

    // Qt 5.6 has no QRandomGenerator; UUIDs are the best entropy source
    // available here. Four of them hashed together is plenty for obfuscation.
    QByteArray entropy;
    for (int i = 0; i < 4; ++i) {
        entropy.append(QUuid::createUuid().toByteArray());
    }
    entropy.append(QByteArray::number(QDateTime::currentMSecsSinceEpoch()));
    g_salt = QCryptographicHash::hash(entropy, QCryptographicHash::Sha256);

    const QString dirPath = QFileInfo(path).absolutePath();
    QDir().mkpath(dirPath);
    SecureStore::restrictDirPermissions(dirPath);

    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        const bool written = file.write(g_salt) == g_salt.size();
        file.close();
        if (written) {
            SecureStore::restrictPermissions(path);
            g_saltPersisted = true;
            return;
        }
    }

    // A salt we cannot store is a salt we cannot read back next launch:
    // anything encoded with it would be unrecoverable.
    qWarning() << "Cannot persist the obfuscation salt to" << path
               << "- values will be stored unobfuscated";
    g_saltPersisted = false;
}

// Keystream derived from the salt: SHA-256(salt || counter), concatenated
// until it covers the payload.
QByteArray keyStream(int length)
{
    loadOrCreateSalt();

    QByteArray stream;
    int counter = 0;

    while (stream.size() < length) {
        QCryptographicHash hash(QCryptographicHash::Sha256);
        hash.addData(g_salt);
        hash.addData(QByteArray::number(counter++));
        stream.append(hash.result());
    }

    return stream.left(length);
}

void applyKeyStream(QByteArray &payload)
{
    const QByteArray stream = keyStream(payload.size());
    for (int i = 0; i < payload.size(); ++i) {
        payload[i] = static_cast<char>(payload.at(i) ^ stream.at(i));
    }
}

}

namespace SecureStore {

void restrictPermissions(const QString &filePath)
{
    if (filePath.isEmpty() || !QFile::exists(filePath)) {
        return;
    }
    QFile::setPermissions(filePath, QFile::ReadOwner | QFile::WriteOwner);
}

void restrictDirPermissions(const QString &dirPath)
{
    if (dirPath.isEmpty() || !QFile::exists(dirPath)) {
        return;
    }
    QFile::setPermissions(dirPath,
                          QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner);
}

bool isAvailable()
{
    loadOrCreateSalt();
    return g_saltPersisted;
}

QString saltFilePath()
{
    QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (dir.isEmpty()) {
        dir = QDir::homePath() + "/.local/share/harbour-sailcat";
    }
    return dir + "/.keysalt";
}

QString obfuscate(const QString &plainText)
{
    if (plainText.isEmpty()) {
        return QString();
    }

    const QByteArray plain = plainText.toUtf8();
    QByteArray payload =
            QCryptographicHash::hash(plain, QCryptographicHash::Sha256).left(CHECKSUM_BYTES);
    payload.append(plain);

    applyKeyStream(payload);

    return QString::fromLatin1(OBFUSCATION_MAGIC)
            + QString::fromLatin1(payload.toBase64());
}

QString deobfuscate(const QString &obfuscated)
{
    if (obfuscated.isEmpty()) {
        return QString();
    }

    const QString magic = QString::fromLatin1(OBFUSCATION_MAGIC);
    if (!obfuscated.startsWith(magic)) {
        // Value written before this scheme existed: still plain text.
        return obfuscated;
    }

    QByteArray payload = QByteArray::fromBase64(
                obfuscated.mid(magic.length()).toLatin1());
    if (payload.size() <= CHECKSUM_BYTES) {
        return QString();
    }

    applyKeyStream(payload);

    const QByteArray checksum = payload.left(CHECKSUM_BYTES);
    const QByteArray plain = payload.mid(CHECKSUM_BYTES);
    if (QCryptographicHash::hash(plain, QCryptographicHash::Sha256).left(CHECKSUM_BYTES)
            != checksum) {
        qWarning() << "Stored value does not match this install's salt";
        return QString();
    }

    return QString::fromUtf8(plain);
}

}
