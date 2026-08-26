#ifndef SETTINGSMANAGER_H
#define SETTINGSMANAGER_H

#include <QObject>
#include <QSettings>
#include <QString>
#include <QStringList>
#include <QVariant>

class SettingsManager : public QObject
{
    Q_OBJECT
    // Active chat backend. The key, the default model and the model cache all
    // hang off it: switching provider swaps the whole set, it does not carry
    // a Mistral key or a Mistral model id over to Groq.
    Q_PROPERTY(QString providerId READ providerId WRITE setProviderId NOTIFY providerChanged)
    Q_PROPERTY(QString providerName READ providerName NOTIFY providerChanged)
    Q_PROPERTY(QString providerBaseUrl READ providerBaseUrl NOTIFY providerChanged)
    Q_PROPERTY(QString providerKeyUrl READ providerKeyUrl NOTIFY providerChanged)
    Q_PROPERTY(QString providerRegion READ providerRegion NOTIFY providerChanged)
    Q_PROPERTY(bool providerKeyRequired READ providerKeyRequired NOTIFY providerChanged)
    Q_PROPERTY(bool providerFreeTier READ providerFreeTier NOTIFY providerChanged)
    Q_PROPERTY(QString customBaseUrl READ customBaseUrl WRITE setCustomBaseUrl NOTIFY providerChanged)
    Q_PROPERTY(QString apiKey READ apiKey WRITE setApiKey NOTIFY apiKeyChanged)
    Q_PROPERTY(QString modelName READ modelName WRITE setModelName NOTIFY modelNameChanged)
    Q_PROPERTY(QString nextMessageModel READ nextMessageModel WRITE setNextMessageModel NOTIFY nextMessageModelChanged)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(bool hasApiKey READ hasApiKey NOTIFY hasApiKeyChanged)
    Q_PROPERTY(double temperature READ temperature WRITE setTemperature NOTIFY temperatureChanged)
    Q_PROPERTY(int maxTokens READ maxTokens WRITE setMaxTokens NOTIFY maxTokensChanged)
    Q_PROPERTY(QString systemPrompt READ systemPrompt WRITE setSystemPrompt NOTIFY systemPromptChanged)
    Q_PROPERTY(int contextMessageLimit READ contextMessageLimit WRITE setContextMessageLimit NOTIFY contextMessageLimitChanged)
    Q_PROPERTY(QString chatStyle READ chatStyle WRITE setChatStyle NOTIFY chatStyleChanged)
    Q_PROPERTY(bool showTimestamps READ showTimestamps WRITE setShowTimestamps NOTIFY showTimestampsChanged)
    Q_PROPERTY(QVariantList savedPrompts READ savedPrompts NOTIFY savedPromptsChanged)
    Q_PROPERTY(QString appVersion READ appVersion CONSTANT)

public:
    explicit SettingsManager(QObject *parent = nullptr);

    QString providerId() const;
    void setProviderId(const QString &id);

    QString providerName() const;
    QString providerBaseUrl() const;
    QString providerKeyUrl() const;
    QString providerRegion() const;
    bool providerKeyRequired() const;
    bool providerFreeTier() const;

    QString customBaseUrl() const;
    void setCustomBaseUrl(const QString &url);

    QString apiKey() const;
    void setApiKey(const QString &key);

    QString modelName() const;
    void setModelName(const QString &model);

    QString nextMessageModel() const;
    void setNextMessageModel(const QString &model);

    QString language() const;
    void setLanguage(const QString &lang);

    double temperature() const;
    void setTemperature(double temperature);

    int maxTokens() const;
    void setMaxTokens(int maxTokens);

    QString systemPrompt() const;
    void setSystemPrompt(const QString &prompt);

    int contextMessageLimit() const;
    void setContextMessageLimit(int limit);

    QString chatStyle() const;
    void setChatStyle(const QString &style);

    bool showTimestamps() const;
    void setShowTimestamps(bool show);

    QVariantList savedPrompts() const;

    QString appVersion() const;

    bool hasApiKey() const;

    // One entry per provider: id, name, region, keyUrl, keyRequired, freeTier.
    Q_INVOKABLE QVariantList availableProviders() const;

    // Same questions, asked about a provider that is not the active one. A
    // conversation is pinned to its own provider, so the chat page has to
    // reason about that one rather than about the global selection.
    Q_INVOKABLE QString providerNameFor(const QString &providerId) const;
    Q_INVOKABLE QString baseUrlFor(const QString &providerId) const;
    Q_INVOKABLE QString apiKeyFor(const QString &providerId) const;
    Q_INVOKABLE bool hasApiKeyFor(const QString &providerId) const;
    Q_INVOKABLE QString modelNameFor(const QString &providerId) const;
    Q_INVOKABLE QStringList availableModelsFor(const QString &providerId) const;
    Q_INVOKABLE bool isVisionModelFor(const QString &providerId, const QString &modelId) const;
    Q_INVOKABLE QString resolveModelFor(const QString &providerId, const QString &candidate) const;
    Q_INVOKABLE bool modelCacheStaleFor(const QString &providerId) const;

    // Keeps a model override from following the user to another provider:
    // returns the candidate when the active provider knows it, the provider
    // default otherwise. An unfetched catalogue accepts anything.
    Q_INVOKABLE QString resolveModel(const QString &candidate) const;

    Q_INVOKABLE QStringList availableModels() const;
    Q_INVOKABLE QStringList availableLanguages() const;
    Q_INVOKABLE QStringList availableChatStyles() const;
    Q_INVOKABLE bool isVisionModel(const QString &modelId) const;
    // providerId empty means the active provider. A fetch made for a
    // conversation pinned elsewhere must not overwrite the active cache.
    Q_INVOKABLE void updateModelCache(const QVariantList &models,
                                      const QString &providerId = QString());
    Q_INVOKABLE bool modelCacheStale() const;
    Q_INVOKABLE int modelSwitches() const;
    Q_INVOKABLE void clearApiKey();
    Q_INVOKABLE bool isFirstLaunch() const;
    Q_INVOKABLE void setFirstLaunchComplete();
    Q_INVOKABLE void resetNextMessageModel();

    // Saved prompt library. Each entry is a map with "title" and "text".
    Q_INVOKABLE void addSavedPrompt(const QString &title, const QString &text);
    Q_INVOKABLE void updateSavedPrompt(int index, const QString &title, const QString &text);
    Q_INVOKABLE void removeSavedPrompt(int index);

    // Published price per million tokens, in US dollars. Estimates only:
    // the API does not expose pricing, so the table is maintained by hand.
    Q_INVOKABLE QVariantMap modelPricing(const QString &modelId) const;
    Q_INVOKABLE double estimatedCost(const QString &modelId,
                                     qint64 promptTokens,
                                     qint64 completionTokens) const;

signals:
    void providerChanged();
    void apiKeyChanged();
    void modelNameChanged();
    void nextMessageModelChanged();
    void languageChanged();
    void hasApiKeyChanged();
    void temperatureChanged();
    void maxTokensChanged();
    void systemPromptChanged();
    void availableModelsChanged();
    void contextMessageLimitChanged();
    void chatStyleChanged();
    void showTimestampsChanged();
    void savedPromptsChanged();

private:
    QSettings m_settings;
    QString m_providerId;
    QString m_customBaseUrl;
    QString m_apiKey;
    QString m_modelName;
    QString m_nextMessageModel;
    QString m_language;
    double m_temperature;
    int m_maxTokens;
    QString m_systemPrompt;
    int m_contextMessageLimit;
    QString m_chatStyle;
    bool m_showTimestamps;
    QStringList m_cachedModels;
    QStringList m_cachedVisionModels;
    QVariantList m_savedPrompts;
    int m_modelSwitches;

    void loadSettings();
    void saveSettings();
    void saveSavedPrompts();
    void persistApiKey();
    void secureSettingsFile();

    // "providers/<id>/<key>", the per-provider half of the settings file.
    QString providerKey(const QString &key) const;
    QString providerKeyFor(const QString &providerId, const QString &key) const;
    QStringList cachedModelsFor(const QString &providerId) const;
    QStringList cachedVisionModelsFor(const QString &providerId) const;
    // Reads key, model name and model cache for the active provider.
    void loadProviderSettings();
    // Moves the pre-2.3 single-provider entries under providers/mistral/.
    void migrateToProviderSettings();
};

#endif // SETTINGSMANAGER_H
