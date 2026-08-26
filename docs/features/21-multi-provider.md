# 21 — Multiple providers (v2.3.0)

SailCat was written against `api.mistral.ai` and hardcoded it in three places. Every
API worth talking to speaks the same OpenAI chat-completions dialect, so the endpoint
was the only thing genuinely Mistral-specific: the streaming parser, the payload
builder and the token accounting all carried over untouched.

## What a provider is

`src/providers.*` holds the registry. A provider is an endpoint plus the handful of
quirks that differ around it:

| Field | Why it exists |
|---|---|
| `baseUrl` | `/chat/completions` and `/models` are appended to it. Empty for the custom entry, which takes its address from the settings |
| `modelSource` | Mistral tags its catalogue with a `capabilities` object; the OpenAI dialect returns bare ids and has to be filtered by name |
| `streamUsageOption` | Mistral streams token usage unasked. The OpenAI dialect only sends it when `stream_options.include_usage` is set, and 400s where the field is unsupported - so it is off for endpoints we cannot vouch for |
| `keyRequired` | OVHcloud answers anonymously at a lower rate limit, and a local llama.cpp wants no key at all |
| `freeTier` | Decides whether the cost estimate reports a price or "free" |
| `fallbackModels` | The picker has to offer something before `/v1/models` has ever been fetched |

Presets: Mistral AI, Scaleway, OVHcloud AI Endpoints, Groq, and a custom endpoint.

## Where the endpoint is applied

`main()` connects `SettingsManager::providerChanged` to `MistralAPI::setEndpoint`.
Nothing in QML configures the API layer: a page that forgot to would send the
conversation to the previous endpoint with the previous key. The class kept its name
even though it is no longer Mistral-specific - renaming it would have churned every
QML file for no behavioural gain.

## Per-provider settings

The key, the default model and the model cache all live under `providers/<id>/` in
the settings file. Switching provider swaps the whole set, so a Mistral key is never
sent to Groq and a Mistral model id is never requested from it. `resolveModel()`
guards the per-conversation override at send time: a model the active catalogue does
not list falls back to the provider default.

The pre-2.3 top-level entries are moved under `providers/mistral/` on first launch,
and the pre-2.1 clear-text key is still read during that move - an install that
skipped two releases must not lose its key.

## A conversation belongs to a provider

The alternative was a single global selection that every conversation follows, and it
fails the only question that matters when two providers are configured: who answered
this? A conversation therefore stores its own `provider`, set when it is created from
the default in the settings, and changing that default afterwards only affects new
conversations. An empty conversation is the exception - it has committed to nothing,
so it follows the default rather than stranding the user on whatever was selected at
startup.

Moving a conversation is explicit, from its settings page, and drops the model
override: it was picked from the previous provider's catalogue and would be rejected
by the new one.

`main()` keeps the endpoint in step by connecting both
`ConversationManager::currentProviderIdChanged` and `SettingsManager::providerChanged`
to `MistralAPI::setEndpoint`. QML still never configures the endpoint; it only asks
`SettingsManager` for the key, the models and the labels *of a given provider*, which
is what the `...For(providerId)` family is for.

## Retroactive data

Two things are known about a file written before 2.3 and one is not:

| | Recovered | How |
|---|---|---|
| Conversation provider | yes | Only Mistral existed, so `conversationFromJson` stamps `mistral` |
| Answer provider | yes | Same reasoning, applied to every assistant message |
| Answer model | no | Never recorded anywhere, and the conversation's model override cannot stand in for it - it may have been set long after the answers |

So an old answer shows `Mistral AI` and no model, rather than a plausible-looking
model name that would be a guess. The stamp happens on load and is written out with
the next save; user turns are left untouched, and neither field is written when empty,
so a file only grows the keys it has a real answer for.

## Catalogue filtering

`/v1/models` returns embeddings, speech, image and moderation models next to the chat
ones, and OpenAI-style entries declare nothing about themselves. Entries are dropped
by name (`Providers::isChatModelId`) and by `max_completion_tokens == 0` where the
provider fills it in. Image support is guessed from the name and defaults to *no*:
the attachment button stays hidden rather than sending a request that will fail.

## Cost

A model served by a free-tier provider costs nothing, whatever it costs at its vendor
- an open-weight model hosted for free on Groq is not billed at Mistral's list price.
`modelPricing()` therefore checks the provider before the price table, and the stats
page prints "free" rather than `$0.00`.
