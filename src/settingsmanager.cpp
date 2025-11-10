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
        m_apiKey = key;
        saveSettings();
        emit apiKeyChanged();
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

QStringList SettingsManager::availableModels() const
{
    return QStringList()
        << "mistral-small-latest"
        << "mistral-large-latest"
        << "pixtral-12b-latest";
}

void SettingsManager::clearApiKey()
{
    setApiKey(QString());
}

bool SettingsManager::hasApiKey() const
{
    return !m_apiKey.isEmpty();
}

void SettingsManager::loadSettings()
{
    m_apiKey = m_settings.value("apiKey", "").toString();
    m_modelName = m_settings.value("modelName", "mistral-small-latest").toString();
    m_useCustomKey = m_settings.value("useCustomKey", false).toBool();
}

void SettingsManager::saveSettings()
{
    m_settings.setValue("apiKey", m_apiKey);
    m_settings.setValue("modelName", m_modelName);
    m_settings.setValue("useCustomKey", m_useCustomKey);
    m_settings.sync();
}
