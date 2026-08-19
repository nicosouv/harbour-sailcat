# 20 — Audit follow-up (v2.1.0)

Result of a full audit of v2.0.4. Grouped by area; everything here shipped together.

## 20.1 Security

Sailfish gives every application the same user, so nothing here defends against a
determined local attacker with a shell. What it does defend against is the realistic
leak path: a config backup, a log dump, a screenshot of a settings file, or a reply
from the model that tries to steer the app.

| Change | Where |
|---|---|
| API key scrambled with a per-install random salt, never stored in clear | `src/securestore.*`, `SettingsManager::persistApiKey` |
| Settings, conversation files, image copies and exports set to owner-only (0600) | `SecureStore::restrictPermissions` |
| TLS 1.2 minimum, peer verification, redirects refused on every request | `MistralAPI::applyTransportSecurity` |
| Markdown links limited to `http`/`https`/`mailto` | `MessageBubble.formatMarkdown`, `MessageBubble.openLink` |
| Double quotes escaped before building `<a href>` | `MessageBubble.formatMarkdown` |
| Conversation ids validated before being used as file names | `ConversationManager::isSafeId` |
| API key field masked, with an explicit reveal switch | `SettingsPage.qml` |

### Key migration

Read order on startup is: `apiKeyEnc` (current), then the pre-2.1 clear-text `apiKey`.
The clear-text entry is only removed once the key has been written back through the
current scheme, so upgrading with a configured key never loses it.

The stored payload carries a 4-byte digest of the plain value. If the salt file is
ever lost, `deobfuscate` returns empty rather than a mangled key, so the app asks for
the key again instead of sending garbage to the API. If the salt cannot be persisted
at all, the key is stored as-is (still owner-only) rather than written in a form that
could not be read back.

## 20.2 Storage

One JSON file per conversation under `AppDataLocation/conversations/<uuid>.json`,
written atomically with `QSaveFile`. Previously the whole history was re-serialised
into a single QSettings value on every pin toggle, every token-usage update and every
completed answer.

Migration from the old blob runs once, on first launch, and then removes the
QSettings entry.

## 20.3 Context limit

`ConversationManager::buildApiMessages(limit, systemPrompt)` is now the single place
that builds a request payload. It:

- drops the trailing empty assistant placeholder
- keeps the last `limit` messages, sliding forward so the window opens on a user turn
- expands attached images into multimodal parts, on every turn rather than only the
  one being sent
- prepends the system prompt

`trimmedMessageCount(limit)` feeds the on-screen notice.

## 20.4 Streaming throttle

Deltas accumulate in `ChatPage.streamingContent` and are flushed to the model on a
90 ms timer. The markdown formatter used to re-parse the entire message on every SSE
token.

## 20.9 Categories

28 identifiers, defined once in `src/categories.cpp` and mirrored for display in
`qml/components/Categories.js`.

The old prompt offered 7 labels and let the model fall back to "other", which it did
almost always. Now the prompt lists all 28 and describes "other" as a last resort,
and `Categories::classify()` runs a local keyword heuristic whenever the model still
answers "other" or something unknown.

The classifier scores whole words against per-category French and English keyword
lists, accent-insensitively. A word owned by a single category is worth 3, a shared
one 1, and a total below 3 returns nothing rather than guess. "Auto-label
conversations" in the history pulley re-runs it over everything still unlabelled.

## 20.12 Update checker removed

The GitHub Releases poll was dead code in 2.0.4 — the C++ class existed but nothing
in the UI called it. Rather than wire it back in, the whole `UpdateChecker` class was
dropped in 2.1.0: the store handles updates. The version string now comes from
`SettingsManager::appVersion`, fed by `APP_VERSION` from the spec file.

## Translations

All seven languages (en, fr, de, es, fi, it, nb_NO) carry the same 273 strings, with
no obsolete entries left over. Norwegian bokmål came from PR #1 and is wired into
`availableLanguages()` and the SettingsPage picker.

Three contexts were dropped along with their files: `AboutPage`, `ConversationListPage`
and `CategoryChip`. Their translations were carried over first into the contexts that
still use those strings, which also filled gaps where de/es/fi/it had been left in
English.

## Not done

- **Conversation import**: excluded on request.
- **PDF attachments**: needs a parser outside the harbour allowed dependencies. Text
  and code files would be feasible with the same input path.
