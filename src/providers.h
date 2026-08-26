#ifndef PROVIDERS_H
#define PROVIDERS_H

#include <QList>
#include <QString>
#include <QStringList>

// Chat backends the app can talk to. Every one of them speaks the OpenAI
// chat-completions dialect, so only the endpoint and a handful of quirks
// change: what /v1/models answers, whether token usage has to be asked for,
// and whether a key is required at all.
namespace Providers {

// How the provider describes its catalogue on /v1/models.
enum ModelSource {
    MistralCatalogue,   // entries carry a "capabilities" object
    OpenAiCatalogue     // plain {id, ...} entries, filtered by name
};

struct Provider {
    QString id;
    QString name;
    QString baseUrl;        // no trailing slash, "/chat/completions" is appended
    QString keyUrl;         // where the user goes to get a key
    QString region;         // shown next to the provider, privacy is a feature
    QString defaultModel;
    QStringList fallbackModels;  // used until /v1/models has been fetched once
    ModelSource modelSource;
    // Mistral streams usage unasked; the OpenAI dialect only sends it when
    // stream_options.include_usage is set. Off for endpoints we cannot vouch
    // for: an unknown field is a 400, a missing usage block is just no stats.
    bool streamUsageOption;
    bool keyRequired;
    // Free within published rate limits, so the cost estimate would be noise.
    bool freeTier;
};

// Every provider, the default first.
QList<Provider> all();

QString defaultId();

bool isValid(const QString &id);

// Falls back to the default provider for an unknown id.
Provider byId(const QString &id);

// True for catalogue entries that are not chat models (embeddings, speech,
// image generation, moderation). Providers rarely tag them, so this goes by
// name; a chat model that trips it would only be missing from the picker.
bool isChatModelId(const QString &modelId);

// Best guess at image support from the model name, for catalogues that do not
// declare capabilities. False on doubt: the attachment button stays hidden
// rather than sending a request the model will reject.
bool looksLikeVisionModel(const QString &modelId);

}

#endif // PROVIDERS_H
