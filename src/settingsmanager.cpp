#include "settingsmanager.h"

SettingsManager::SettingsManager(QObject *parent)
    : QObject(parent)
    , m_settings("harbour-sailcat", "SailCat")
    , m_useCustomKey(false)
{
    loadSettings();
}

QString SettingsManager::apiKey() const
{
    return m_apiKey;
}

void SettingsManager::setApiKey(const QString &key)
{
    if (m_apiKey != key) {
        bool hadKey = !m_apiKey.isEmpty();
        m_apiKey = key;
        bool hasKey = !m_apiKey.isEmpty();
        saveSettings();
        emit apiKeyChanged();
        if (hadKey != hasKey) {
            emit hasApiKeyChanged();
        }
    }
}

QString SettingsManager::modelName() const
{
    return m_modelName;
}

void SettingsManager::setModelName(const QString &model)
{
    if (m_modelName != model) {
        m_modelName = model;
        saveSettings();
        emit modelNameChanged();
    }
}

bool SettingsManager::useCustomKey() const
{
    return m_useCustomKey;
}

void SettingsManager::setUseCustomKey(bool use)
{
    if (m_useCustomKey != use) {
        m_useCustomKey = use;
        saveSettings();
        emit useCustomKeyChanged();
    }
}

QString SettingsManager::language() const
{
    return m_language;
}

void SettingsManager::setLanguage(const QString &lang)
{
    if (m_language != lang) {
        m_language = lang;
        saveSettings();
        emit languageChanged();
    }
}

QStringList SettingsManager::availableModels() const
{
    return QStringList()
        << "mistral-small-latest"
        << "mistral-large-latest"
        << "pixtral-12b-latest";
}

QStringList SettingsManager::availableLanguages() const
{
    return QStringList()
        << "en"
        << "fr"
        << "de"
        << "es"
        << "fi"
        << "it";
}

void SettingsManager::clearApiKey()
{
    setApiKey(QString());
}

bool SettingsManager::hasApiKey() const
{
    return !m_apiKey.isEmpty();
}

bool SettingsManager::isFirstLaunch(int conversationCount) const
{
    // Show first launch only if:
    // - firstLaunchComplete flag is not set
    // - AND no API key configured
    // - AND no conversations exist
    if (m_settings.contains("firstLaunchComplete") && m_settings.value("firstLaunchComplete").toBool()) {
        return false;
    }

    bool hasApiKey = !m_apiKey.isEmpty();
    bool hasConversations = conversationCount > 0;

    // Only show for truly new installations
    return !hasApiKey && !hasConversations;
}

void SettingsManager::setFirstLaunchComplete()
{
    m_settings.setValue("firstLaunchComplete", true);
    m_settings.sync();
}

void SettingsManager::loadSettings()
{
    m_apiKey = m_settings.value("apiKey", "").toString();
    m_modelName = m_settings.value("modelName", "mistral-small-latest").toString();
    m_useCustomKey = m_settings.value("useCustomKey", false).toBool();
    m_language = m_settings.value("language", "en").toString();
}

void SettingsManager::saveSettings()
{
    m_settings.setValue("apiKey", m_apiKey);
    m_settings.setValue("modelName", m_modelName);
    m_settings.setValue("useCustomKey", m_useCustomKey);
    m_settings.setValue("language", m_language);
    m_settings.sync();
}
