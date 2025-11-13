#ifndef SETTINGSMANAGER_H
#define SETTINGSMANAGER_H

#include <QObject>
#include <QSettings>
#include <QString>

class SettingsManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString apiKey READ apiKey WRITE setApiKey NOTIFY apiKeyChanged)
    Q_PROPERTY(QString modelName READ modelName WRITE setModelName NOTIFY modelNameChanged)
    Q_PROPERTY(bool useCustomKey READ useCustomKey WRITE setUseCustomKey NOTIFY useCustomKeyChanged)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(bool hasApiKey READ hasApiKey NOTIFY hasApiKeyChanged)

public:
    explicit SettingsManager(QObject *parent = nullptr);

    QString apiKey() const;
    void setApiKey(const QString &key);

    QString modelName() const;
    void setModelName(const QString &model);

    bool useCustomKey() const;
    void setUseCustomKey(bool use);

    QString language() const;
    void setLanguage(const QString &lang);

    bool hasApiKey() const;

    Q_INVOKABLE QStringList availableModels() const;
    Q_INVOKABLE QStringList availableLanguages() const;
    Q_INVOKABLE void clearApiKey();

signals:
    void apiKeyChanged();
    void modelNameChanged();
    void useCustomKeyChanged();
    void languageChanged();
    void hasApiKeyChanged();

private:
    QSettings m_settings;
    QString m_apiKey;
    QString m_modelName;
    bool m_useCustomKey;
    QString m_language;

    void loadSettings();
    void saveSettings();
};

#endif // SETTINGSMANAGER_H
