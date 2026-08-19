#include "settingsmanager.h"
#include "securestore.h"

#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QVariant>
#include <QDebug>

// Injected by qmake from the spec file version
#ifndef APP_VERSION
#define APP_VERSION "2.2.0"
#endif

namespace {

struct ModelPrice {
    const char *match;      // matched as a substring of the model id
    double inputPerMillion;
    double outputPerMillion;
};

// Public list prices in USD per million tokens. Ordered from the most
// specific match to the least so "pixtral-large" does not resolve as "pixtral".
const ModelPrice PRICES[] = {
    { "pixtral-large",     2.00, 6.00 },
    { "mistral-large",     2.00, 6.00 },
    { "magistral-medium",  2.00, 5.00 },
    { "mistral-medium",    0.40, 2.00 },
    { "magistral-small",   0.50, 1.50 },
    { "codestral",         0.30, 0.90 },
    { "devstral",          0.10, 0.30 },
    { "mistral-small",     0.10, 0.30 },
    { "ministral-8b",      0.10, 0.10 },
    { "ministral-3b",      0.04, 0.04 },
    { "pixtral",           0.15, 0.15 },
    { "nemo",              0.15, 0.15 },
    { "mistral-saba",      0.20, 0.60 }
};

const int PRICE_COUNT = int(sizeof(PRICES) / sizeof(PRICES[0]));

const int MAX_SAVED_PROMPTS = 100;

}

SettingsManager::SettingsManager(QObject *parent)
    : QObject(parent)
    , m_settings("harbour-sailcat", "SailCat")
    , m_temperature(-1.0)
    , m_maxTokens(0)
    , m_contextMessageLimit(0)
    , m_chatStyle("flat")
    , m_showTimestamps(true)
    , m_modelSwitches(0)
{
    loadSettings();
    secureSettingsFile();
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
        m_modelSwitches++;
        m_settings.setValue("stats/modelSwitches", m_modelSwitches);
        saveSettings();
        emit modelNameChanged();
    }
}

int SettingsManager::modelSwitches() const
{
    return m_modelSwitches;
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

double SettingsManager::temperature() const
{
    return m_temperature;
}

void SettingsManager::setTemperature(double temperature)
{
    if (m_temperature != temperature) {
        m_temperature = temperature;
        saveSettings();
        emit temperatureChanged();
    }
}

int SettingsManager::maxTokens() const
{
    return m_maxTokens;
}

void SettingsManager::setMaxTokens(int maxTokens)
{
    if (m_maxTokens != maxTokens) {
        m_maxTokens = maxTokens;
        saveSettings();
        emit maxTokensChanged();
    }
}

QString SettingsManager::systemPrompt() const
{
    return m_systemPrompt;
}

void SettingsManager::setSystemPrompt(const QString &prompt)
{
    if (m_systemPrompt != prompt) {
        m_systemPrompt = prompt;
        saveSettings();
        emit systemPromptChanged();
    }
}

int SettingsManager::contextMessageLimit() const
{
    return m_contextMessageLimit;
}

void SettingsManager::setContextMessageLimit(int limit)
{
    // Always an even number: a trimmed history should start on a user turn.
    int normalized = limit < 0 ? 0 : limit;
    if (normalized > 0 && normalized % 2 != 0) {
        normalized += 1;
    }

    if (m_contextMessageLimit != normalized) {
        m_contextMessageLimit = normalized;
        saveSettings();
        emit contextMessageLimitChanged();
    }
}

QString SettingsManager::chatStyle() const
{
    return m_chatStyle;
}

void SettingsManager::setChatStyle(const QString &style)
{
    if (!availableChatStyles().contains(style)) {
        return;
    }
    if (m_chatStyle != style) {
        m_chatStyle = style;
        saveSettings();
        emit chatStyleChanged();
    }
}

bool SettingsManager::showTimestamps() const
{
    return m_showTimestamps;
}

void SettingsManager::setShowTimestamps(bool show)
{
    if (m_showTimestamps != show) {
        m_showTimestamps = show;
        saveSettings();
        emit showTimestampsChanged();
    }
}

QVariantList SettingsManager::savedPrompts() const
{
    return m_savedPrompts;
}

QString SettingsManager::appVersion() const
{
    return QString::fromLatin1(APP_VERSION);
}

void SettingsManager::addSavedPrompt(const QString &title, const QString &text)
{
    if (text.trimmed().isEmpty() || m_savedPrompts.count() >= MAX_SAVED_PROMPTS) {
        return;
    }

    QVariantMap entry;
    entry["title"] = title.trimmed().isEmpty() ? text.trimmed().left(40) : title.trimmed();
    entry["text"] = text.trimmed();
    m_savedPrompts.prepend(entry);

    saveSavedPrompts();
    emit savedPromptsChanged();
}

void SettingsManager::updateSavedPrompt(int index, const QString &title, const QString &text)
{
    if (index < 0 || index >= m_savedPrompts.count() || text.trimmed().isEmpty()) {
        return;
    }

    QVariantMap entry;
    entry["title"] = title.trimmed().isEmpty() ? text.trimmed().left(40) : title.trimmed();
    entry["text"] = text.trimmed();
    m_savedPrompts[index] = entry;

    saveSavedPrompts();
    emit savedPromptsChanged();
}

void SettingsManager::removeSavedPrompt(int index)
{
    if (index < 0 || index >= m_savedPrompts.count()) {
        return;
    }

    m_savedPrompts.removeAt(index);
    saveSavedPrompts();
    emit savedPromptsChanged();
}

QVariantMap SettingsManager::modelPricing(const QString &modelId) const
{
    QVariantMap pricing;
    pricing["input"] = 0.0;
    pricing["output"] = 0.0;
    pricing["known"] = false;

    const QString id = modelId.toLower();
    for (int i = 0; i < PRICE_COUNT; ++i) {
        if (id.contains(QString::fromLatin1(PRICES[i].match))) {
            pricing["input"] = PRICES[i].inputPerMillion;
            pricing["output"] = PRICES[i].outputPerMillion;
            pricing["known"] = true;
            break;
        }
    }

    return pricing;
}

double SettingsManager::estimatedCost(const QString &modelId,
                                      qint64 promptTokens,
                                      qint64 completionTokens) const
{
    const QVariantMap pricing = modelPricing(modelId);
    if (!pricing["known"].toBool()) {
        return -1.0;
    }

    return (promptTokens / 1000000.0) * pricing["input"].toDouble()
         + (completionTokens / 1000000.0) * pricing["output"].toDouble();
}

QStringList SettingsManager::availableModels() const
{
    if (!m_cachedModels.isEmpty()) {
        return m_cachedModels;
    }
    // Fallback when the model list was never fetched
    return QStringList()
        << "mistral-small-latest"
        << "mistral-large-latest"
        << "pixtral-12b-latest";
}

QStringList SettingsManager::availableChatStyles() const
{
    return QStringList()
        << "flat"       // full width tinted rows (historical look)
        << "bubbles"    // rounded bubbles aligned left/right
        << "compact"    // dense rows with a role prefix
        << "cards";     // separated cards with a role header
}

bool SettingsManager::isVisionModel(const QString &modelId) const
{
    if (!m_cachedModels.isEmpty()) {
        return m_cachedVisionModels.contains(modelId);
    }
    return modelId.contains("pixtral");
}

void SettingsManager::updateModelCache(const QVariantList &models)
{
    QStringList ids;
    QStringList visionIds;

    for (const QVariant &modelVariant : models) {
        QVariantMap model = modelVariant.toMap();
        QString id = model["id"].toString();
        if (id.isEmpty()) {
            continue;
        }
        ids.append(id);
        if (model["vision"].toBool()) {
            visionIds.append(id);
        }
    }

    if (ids.isEmpty()) {
        return;
    }

    m_cachedModels = ids;
    m_cachedVisionModels = visionIds;
    m_settings.setValue("models/cachedList", m_cachedModels);
    m_settings.setValue("models/visionList", m_cachedVisionModels);
    m_settings.setValue("models/cacheTimestamp", QDateTime::currentMSecsSinceEpoch() / 1000);
    m_settings.sync();
    secureSettingsFile();
    emit availableModelsChanged();
}

bool SettingsManager::modelCacheStale() const
{
    if (m_cachedModels.isEmpty()) {
        return true;
    }
    qint64 cachedAt = m_settings.value("models/cacheTimestamp", 0).toLongLong();
    qint64 now = QDateTime::currentMSecsSinceEpoch() / 1000;
    return (now - cachedAt) > 24 * 3600;
}

QStringList SettingsManager::availableLanguages() const
{
    // Codes must match the translations/harbour-sailcat-<code>.ts file names
    return QStringList()
        << "en"
        << "fr"
        << "de"
        << "es"
        << "fi"
        << "it"
        << "nb_NO";
}

void SettingsManager::clearApiKey()
{
    setApiKey(QString());
}

bool SettingsManager::hasApiKey() const
{
    return !m_apiKey.isEmpty();
}

QString SettingsManager::nextMessageModel() const
{
    return m_nextMessageModel;
}

void SettingsManager::setNextMessageModel(const QString &model)
{
    if (m_nextMessageModel != model) {
        m_nextMessageModel = model;
        saveSettings();
        emit nextMessageModelChanged();
    }
}

void SettingsManager::resetNextMessageModel()
{
    setNextMessageModel(QString());
}

bool SettingsManager::isFirstLaunch() const
{
    // If the flag is set and true, never show again
    if (m_settings.value("firstLaunchComplete", false).toBool()) {
        return false;
    }

    // Show if no API key configured
    return m_apiKey.isEmpty();
}

void SettingsManager::setFirstLaunchComplete()
{
    m_settings.setValue("firstLaunchComplete", true);
    m_settings.sync();
    secureSettingsFile();
}

void SettingsManager::loadSettings()
{
    // The key moved to an obfuscated entry in 2.1. Read order matters:
    //   1. the new entry, which deobfuscate() also passes through untouched if
    //      it happens to hold a plain value (salt unavailable at write time)
    //   2. the pre-2.1 clear-text entry, migrated in place
    // The clear-text entry is only dropped once the key is stored again, so an
    // upgrade with a configured key never loses it.
    const QString storedKey = m_settings.value("apiKeyEnc", "").toString();
    if (!storedKey.isEmpty()) {
        m_apiKey = SecureStore::deobfuscate(storedKey);
        if (m_apiKey.isEmpty()) {
            qWarning() << "Stored API key could not be decoded; it must be entered again";
            m_settings.remove("apiKeyEnc");
        }
    }

    if (m_apiKey.isEmpty()) {
        const QString legacyKey = m_settings.value("apiKey", "").toString();
        if (!legacyKey.isEmpty()) {
            m_apiKey = legacyKey;
        }
    }

    if (!m_apiKey.isEmpty()) {
        persistApiKey();
    }
    m_settings.remove("apiKey");

    // Dropped in 2.1: there is no bundled key, so the toggle only ever got in
    // the way. Remove the leftover entry.
    m_settings.remove("useCustomKey");

    m_modelName = m_settings.value("modelName", "mistral-small-latest").toString();
    m_nextMessageModel = m_settings.value("nextMessageModel", "").toString();
    m_language = m_settings.value("language", "en").toString();
    m_temperature = m_settings.value("generation/temperature", -1.0).toDouble();
    m_maxTokens = m_settings.value("generation/maxTokens", 0).toInt();
    m_systemPrompt = m_settings.value("generation/systemPrompt", "").toString();
    m_contextMessageLimit = m_settings.value("generation/contextMessageLimit", 0).toInt();
    m_chatStyle = m_settings.value("ui/chatStyle", "flat").toString();
    if (!availableChatStyles().contains(m_chatStyle)) {
        m_chatStyle = "flat";
    }
    m_showTimestamps = m_settings.value("ui/showTimestamps", true).toBool();
    m_cachedModels = m_settings.value("models/cachedList").toStringList();
    m_cachedVisionModels = m_settings.value("models/visionList").toStringList();
    m_modelSwitches = m_settings.value("stats/modelSwitches", 0).toInt();

    m_savedPrompts.clear();
    QJsonDocument promptsDoc = QJsonDocument::fromJson(
                m_settings.value("prompts/library").toByteArray());
    if (promptsDoc.isArray()) {
        const QJsonArray array = promptsDoc.array();
        for (int i = 0; i < array.count(); ++i) {
            const QJsonObject obj = array.at(i).toObject();
            const QString text = obj["text"].toString();
            if (text.isEmpty()) {
                continue;
            }
            QVariantMap entry;
            entry["title"] = obj["title"].toString();
            entry["text"] = text;
            m_savedPrompts.append(entry);
        }
    }

    m_settings.sync();
}

void SettingsManager::persistApiKey()
{
    if (m_apiKey.isEmpty()) {
        m_settings.remove("apiKeyEnc");
        return;
    }

    // Without a persisted salt the ciphertext would be unreadable on the next
    // launch, so store the key as-is rather than destroy it. The file is still
    // owner-only either way.
    m_settings.setValue("apiKeyEnc", SecureStore::isAvailable()
                        ? SecureStore::obfuscate(m_apiKey)
                        : m_apiKey);
}

void SettingsManager::saveSettings()
{
    persistApiKey();
    m_settings.setValue("modelName", m_modelName);
    if (!m_nextMessageModel.isEmpty()) {
        m_settings.setValue("nextMessageModel", m_nextMessageModel);
    } else {
        m_settings.remove("nextMessageModel");
    }
    m_settings.setValue("language", m_language);
    m_settings.setValue("generation/temperature", m_temperature);
    m_settings.setValue("generation/maxTokens", m_maxTokens);
    m_settings.setValue("generation/systemPrompt", m_systemPrompt);
    m_settings.setValue("generation/contextMessageLimit", m_contextMessageLimit);
    m_settings.setValue("ui/chatStyle", m_chatStyle);
    m_settings.setValue("ui/showTimestamps", m_showTimestamps);
    m_settings.sync();
    secureSettingsFile();
}

void SettingsManager::saveSavedPrompts()
{
    QJsonArray array;
    for (const QVariant &entry : m_savedPrompts) {
        const QVariantMap map = entry.toMap();
        QJsonObject obj;
        obj["title"] = map["title"].toString();
        obj["text"] = map["text"].toString();
        array.append(obj);
    }

    m_settings.setValue("prompts/library",
                        QJsonDocument(array).toJson(QJsonDocument::Compact));
    m_settings.sync();
    secureSettingsFile();
}

void SettingsManager::secureSettingsFile()
{
    SecureStore::restrictPermissions(m_settings.fileName());
}
