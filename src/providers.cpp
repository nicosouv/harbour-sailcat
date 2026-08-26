#include "providers.h"
#include <QObject>

namespace {

Providers::Provider make(const QString &id,
                         const QString &name,
                         const QString &baseUrl,
                         const QString &keyUrl,
                         const QString &region,
                         const QStringList &models,
                         Providers::ModelSource source,
                         bool streamUsageOption,
                         bool keyRequired,
                         bool freeTier)
{
    Providers::Provider p;
    p.id = id;
    p.name = name;
    p.baseUrl = baseUrl;
    p.keyUrl = keyUrl;
    p.region = region;
    p.defaultModel = models.isEmpty() ? QString() : models.first();
    p.fallbackModels = models;
    p.modelSource = source;
    p.streamUsageOption = streamUsageOption;
    p.keyRequired = keyRequired;
    p.freeTier = freeTier;
    return p;
}

// Substrings that mark a catalogue entry as something other than a chat model.
const char * const NON_CHAT[] = {
    "embed", "bge-", "rerank", "whisper", "-tts", "tts-", "voice", "audio",
    "stable-diffusion", "flux", "-image", "image-", "dall-e", "moderation",
    "guard", "-ocr", "ocr-"
};

const int NON_CHAT_COUNT = int(sizeof(NON_CHAT) / sizeof(NON_CHAT[0]));

const char * const VISION_HINTS[] = {
    "pixtral", "llava", "vision", "-vl-", "vl-", "-vl", "gemma-3", "gpt-4o"
};

const int VISION_HINT_COUNT = int(sizeof(VISION_HINTS) / sizeof(VISION_HINTS[0]));

}

namespace Providers {

QList<Provider> all()
{
    QList<Provider> list;

    list << make("mistral", "Mistral AI",
                 "https://api.mistral.ai/v1",
                 "console.mistral.ai",
                 QObject::tr("France (EU)"),
                 QStringList() << "mistral-small-latest"
                               << "mistral-large-latest"
                               << "pixtral-12b-latest",
                 MistralCatalogue, false, true, false);

    list << make("scaleway", "Scaleway",
                 "https://api.scaleway.ai/v1",
                 "console.scaleway.com",
                 QObject::tr("France (EU)"),
                 QStringList() << "mistral-small-3.2-24b-instruct-2506"
                               << "llama-3.3-70b-instruct"
                               << "gpt-oss-120b",
                 OpenAiCatalogue, true, true, true);

    list << make("ovh", "OVHcloud AI Endpoints",
                 "https://oai.endpoints.kepler.ai.cloud.ovh.net/v1",
                 "endpoints.ai.cloud.ovh.net",
                 QObject::tr("France (EU)"),
                 QStringList() << "Mistral-Small-3.2-24B-Instruct-2506"
                               << "Meta-Llama-3_3-70B-Instruct"
                               << "gpt-oss-120b",
                 // Answers without a key at a lower rate limit, which makes it
                 // the one provider usable before the user signs up anywhere.
                 OpenAiCatalogue, true, false, true);

    list << make("groq", "Groq",
                 "https://api.groq.com/openai/v1",
                 "console.groq.com",
                 QObject::tr("United States"),
                 QStringList() << "llama-3.3-70b-versatile"
                               << "openai/gpt-oss-120b"
                               << "qwen/qwen3-32b",
                 OpenAiCatalogue, true, true, true);

    // Base URL comes from the settings; anything OpenAI-compatible fits,
    // including a self-hosted llama.cpp or Ollama on the local network.
    list << make("custom", QObject::tr("Custom endpoint"),
                 QString(),
                 QString(),
                 QObject::tr("Wherever you point it"),
                 QStringList(),
                 OpenAiCatalogue, false, false, false);

    return list;
}

QString defaultId()
{
    return QStringLiteral("mistral");
}

bool isValid(const QString &id)
{
    const QList<Provider> list = all();
    for (int i = 0; i < list.count(); ++i) {
        if (list.at(i).id == id) {
            return true;
        }
    }
    return false;
}

Provider byId(const QString &id)
{
    const QList<Provider> list = all();
    for (int i = 0; i < list.count(); ++i) {
        if (list.at(i).id == id) {
            return list.at(i);
        }
    }
    return byId(defaultId());
}

bool isChatModelId(const QString &modelId)
{
    const QString id = modelId.toLower();
    if (id.isEmpty()) {
        return false;
    }

    for (int i = 0; i < NON_CHAT_COUNT; ++i) {
        if (id.contains(QString::fromLatin1(NON_CHAT[i]))) {
            return false;
        }
    }
    return true;
}

bool looksLikeVisionModel(const QString &modelId)
{
    const QString id = modelId.toLower();
    for (int i = 0; i < VISION_HINT_COUNT; ++i) {
        if (id.contains(QString::fromLatin1(VISION_HINTS[i]))) {
            return true;
        }
    }
    return false;
}

}
