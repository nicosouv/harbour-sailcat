#ifndef SECURESTORE_H
#define SECURESTORE_H

#include <QString>
#include <QByteArray>

// Local-at-rest protection for the API key and the conversation files.
//
// Sailfish has no per-application keystore: every app runs as the same user,
// so nothing can stop a determined local attacker. What this does buy:
//   - owner-only permissions, so the files are not world readable
//   - the key never appears in clear text, so config backups, log dumps or a
//     grep for an API key prefix do not leak it
namespace SecureStore {

// Restrict a file to owner read/write. Safe to call on a missing file.
void restrictPermissions(const QString &filePath);

// Restrict a directory to owner read/write/execute.
void restrictDirPermissions(const QString &dirPath);

// False when the salt could not be persisted. Callers must then store the
// value as-is rather than write something they will not be able to read back.
bool isAvailable();

// Reversible obfuscation keyed on a per-install random salt kept in the data
// directory. Returns an empty string for empty input.
QString obfuscate(const QString &plainText);

// Reverses obfuscate(). Input that carries no marker is returned unchanged,
// which is how values written before this scheme existed are migrated.
// Returns an empty string when the marker is there but the payload does not
// check out, so a lost salt surfaces as "no key" instead of a corrupt one.
QString deobfuscate(const QString &obfuscated);

// Path of the salt file, created on first use. Exposed for tests.
QString saltFilePath();

}

#endif // SECURESTORE_H
