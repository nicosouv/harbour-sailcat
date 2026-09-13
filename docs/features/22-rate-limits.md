# 22 — Rate limits and self-made requests (v2.3.0)

Mistral's free tier answers about one request per second and turns the rest away
with `429 Too Many Requests`. The app had no idea: a 429 ended the exchange, the
empty assistant bubble was dropped, and the user got

```
API Error: Error transferring https://api.mistral.ai/v1/chat/completions -
server replied: Too Many Requests
```

Three things were wrong with that. The request was never sent again although the
provider was explicitly saying "not now". Nothing stopped the app from sending two
calls within the same second in the first place. And the app was making a request
the user never asked for.

## Spacing requests out

`MistralAPI` keeps a `QElapsedTimer` of when the last request actually left, and
every call - chat, title, catalogue - goes through the same gate. A request that
would leave less than 1.2 s after the previous one is held back on a timer rather
than sent and rejected.

A custom endpoint is exempt: it is the user's own machine as often as not, and
nobody rate-limits their own llama.cpp.

## Retrying

`429`, `502`, `503` and `529` all mean "not now" rather than "no". When one comes
back the same body is posted again, up to three times, waiting for `Retry-After`
when the provider sends one and 2 s, 4 s, 8 s otherwise.

The retry is invisible to everything above the API layer:

- the request body is kept in `m_pendingBody`, so nothing has to rebuild it,
- `messageSent()` is emitted once, when the request is accepted - not when it
  leaves. A request held back for a moment must not put its empty assistant bubble
  in whichever conversation the user opened in the meantime,
- `isBusy` never drops, so no `responseCompleted()` is emitted and the empty bubble
  is not swept away between attempts,
- `onError()` sets no error text while a retry is pending, so no banner flashes.

A retry is refused once content has reached the screen (`m_streamStarted`): half an
answer plus a fresh stream would read as a duplicate. A cancelled request clears the
pending body, so it can never come back.

The user sees `rateLimited(seconds, attempt, maxAttempts)` as a highlight-coloured
notice with a countdown, not an error. Only when the attempts run out does the error
banner appear, and then it says what actually happened instead of quoting libcurl.

## Not making the request at all

The one call the app made on its own was title generation: after the first answer it
sent a digest back to the model and asked for a title and a category. Good titles,
but on a free tier that is one request per conversation that the user did not ask
for, and it lands right after the answer - exactly when the per-second window is
busiest.

It is now a setting, `generation/autoTitleMode`:

| Mode | Requests | What you get |
|---|---|---|
| `local` (default) | none | The first question as the title, the category from the local keyword classifier that already backs "Auto-label conversations" |
| `ai` | one per conversation | The old behaviour |
| `off` | none | The first question as the title, no category |

`ConversationManager::autoLabelConversation()` does the local work. It never
overwrites a category the user picked by hand - `other` is not a choice, it is what
the app falls back to. "Suggest a title" in the conversation settings is unaffected:
an explicit request is still worth a call.

The model catalogue is the other self-made request, and it was already cached for
24 h per provider.
