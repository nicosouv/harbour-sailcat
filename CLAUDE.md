# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SailCat is a native Sailfish OS chat client for Mistral AI, built with Qt/C++ backend and QML/Silica frontend. The app uses streaming SSE (Server-Sent Events) to display real-time AI responses.

## Build Commands

### Local Development (with Sailfish SDK)

```bash
# Configure target architecture
sfdk config target=SailfishOS-5.0.0.43-armv7hl

# Build the project
sfdk build

# Deploy to emulator
sfdk emulator start
sfdk deploy --manual

# Deploy to device
sfdk device set <device-ip>
sfdk deploy
```

### Docker Build (without SDK)

```bash
# Build using Docker container
docker run --rm -it \
  -v $(pwd):/home/sailfish/src \
  -w /home/sailfish/src \
  coderus/sailfishos-platform-sdk:5.0.0.43 \
  mb2 -t SailfishOS-5.0.0.43-armv7hl build

# RPMs are generated in RPMS/ directory
```

### Release Process

```bash
# Create and push a semver tag to trigger automated builds
git tag v1.0.0
git push origin v1.0.0

# GitHub Actions builds for armv7hl, aarch64, i486 and creates release
# For manual/test builds, use workflow_dispatch (builds with version 0.1.0-dev)
```

## Architecture

### Backend (Qt/C++)

Four QObject classes are exposed to QML as context properties, plus two helper
namespaces:

1. **MistralAPI** (`src/mistralapi.*`)
   - Manages HTTP communication with Mistral AI API
   - Implements SSE streaming parser for real-time responses
   - Parses `data: [DONE]` and JSON chunks from stream
   - Enforces TLS 1.2+, peer verification and no redirects on every request
   - Signals: `streamingResponse()`, `responseCompleted()`, `messageSent()`,
     `usageReceived()`, `sideRequestUsage()`, `titleGenerated()`, `modelsFetched()`
   - Properties: `isBusy`, `error`

2. **ConversationModel** (`src/conversationmodel.*`)
   - QAbstractListModel for displaying messages in ListView
   - Stores messages with role ("user"/"assistant"), content, timestamp, pinned, imagePath
   - Key methods:
     - `addUserMessage()` - Add new user message
     - `addAssistantMessage()` - Start new assistant response
     - `updateLastAssistantMessage()` - Update during streaming
     - `messages()` - Read-only view used by ConversationManager
   - Roles: `RoleRole`, `ContentRole`, `TimestampRole`, `PinnedRole`, `ImagePathRole`

3. **ConversationManager** (`src/conversationmanager.*`)
   - Owns the conversation list and the current ConversationModel
   - Storage: one JSON file per conversation under `AppDataLocation/conversations/`,
     written atomically, owner-only, with dirty tracking so a save touches one file.
     Migrates the pre-2.1 single QSettings blob on first launch
   - `buildApiMessages(contextLimit, systemPrompt)` is the **single** place a request
     payload is built: trims history, expands images into multimodal parts,
     prepends the system prompt, drops the pending empty assistant bubble
   - Per-conversation overrides: `model`, `systemPrompt`, `category`, title
   - Statistics, fun stats, search, markdown export, cost input (`modelUsage`)

4. **SettingsManager** (`src/settingsmanager.*`)
   - Wraps QSettings for persistent configuration, file kept owner-only
   - API key stored scrambled via SecureStore, never in clear text
   - Properties: `apiKey`, `modelName`, `nextMessageModel`, `language`, `temperature`,
     `maxTokens`, `systemPrompt`, `contextMessageLimit`, `chatStyle`, `showTimestamps`,
     `savedPrompts`
   - `modelPricing()` / `estimatedCost()` back the cost estimate in the stats page
   - `appVersion` exposes `APP_VERSION`, injected by qmake from the spec version

There is deliberately no in-app update check: the store handles updates, and the
GitHub Releases poll was removed in 2.1.0.

Helpers (plain namespaces, not QObjects):

- **SecureStore** (`src/securestore.*`) - owner-only file permissions and salted
  obfuscation for the API key. See `docs/features/20-audit-followup.md` for the
  threat model and the migration rules.
- **Categories** (`src/categories.*`) - the 28 conversation categories and a local
  keyword classifier used when the model answers "other". Display labels and colors
  live in `qml/components/Categories.js` and **must stay in sync**.

### Frontend (QML/Silica)

- **qml/pages/ChatPage.qml** - Main conversation interface. Owns the streaming
  throttle (deltas flushed on a 90 ms timer, never per token)
- **qml/pages/ConversationHistoryPage.qml** - List, search, share, auto-label
- **qml/pages/ConversationDetailPage.qml** - Read-only view with per-conversation charts
- **qml/pages/ConversationSettingsPage.qml** - Per-conversation title, category, model, prompt
- **qml/pages/PromptLibraryPage.qml** - Saved prompts
- **qml/pages/PinnedMessagesPage.qml** - Pinned messages across conversations
- **qml/pages/SettingsPage.qml** - API key, appearance, generation, update checker
- **qml/pages/StatsPage.qml** - Charts, badges, estimated cost
- **qml/cover/CoverPage.qml** - Active cover, follows the answer while streaming
- **qml/components/MessageBubble.qml** - Message delegate, implements the four chat
  styles (`flat`, `bubbles`, `compact`, `cards`) and the markdown renderer

### Data Flow

```
User sends message → ChatPage.sendMessage()
  → conversationModel.addUserMessage()
  → conversationManager.saveCurrentConversation()   // before the round trip
  → ChatPage.dispatchRequest()
  → conversationManager.buildApiMessages(contextLimit, systemPrompt)
  → mistralApi.sendMessage(apiKey, model, messages, temperature, maxTokens)
  → emit messageSent() → conversationModel.addAssistantMessage("")
  → POST https://api.mistral.ai/v1/chat/completions
  → SSE stream chunks → mistralApi.onReadyRead()
  → parseStreamLine() extracts JSON
  → emit streamingResponse(content)
  → ChatPage accumulates into streamingContent, marks streamPending
  → streamFlushTimer (90 ms) → conversationModel.updateLastAssistantMessage()
  → ListView automatically updates
```

Two invariants worth keeping:

- The empty assistant bubble is added on `messageSent()`, not before the call. A
  request the API layer rejects must not leave a placeholder behind.
- Nothing but `buildApiMessages()` assembles a payload. Regenerate, retry and send
  all go through `dispatchRequest()`.

## Mistral AI Integration

### Endpoint
```
POST https://api.mistral.ai/v1/chat/completions
```

### Request Format
```json
{
  "model": "mistral-small-latest",
  "messages": [
    {"role": "user", "content": "Hello"},
    {"role": "assistant", "content": "Hi!"}
  ],
  "stream": true
}
```

### SSE Stream Format
```
data: {"choices":[{"delta":{"content":"Hello"}}]}
data: {"choices":[{"delta":{"content":" there"}}]}
data: [DONE]
```

The `MistralAPI::parseStreamLine()` method handles parsing these SSE events and extracting content deltas.

## Key Development Notes

### QML Hot Reload
QML files can be updated without rebuilding C++:
```bash
scp qml/pages/ChatPage.qml nemo@<device-ip>:/usr/share/harbour-sailcat/qml/pages/
# Then restart the app
```

### Debugging
```bash
# View app logs on device/emulator
devel-su
journalctl -f | grep sailcat
```

### CI/CD Workflows
- **build-docker.yml** - Triggered on `v*.*.*` tags or manual dispatch
  - Extracts version from `GITHUB_REF` (e.g., `refs/tags/v1.0.0` → `1.0.0`)
  - Uses `0.1.0` for manual builds without tags (RPM forbids `-` in Version)
  - Updates `rpm/harbour-sailcat.spec` with extracted version
  - Builds for armv7hl, aarch64, i486 in parallel
  - Creates GitHub release with changelog (tag builds only)
- **pr-build.yml** - Validates PRs with armv7hl build

### Important Constraints

1. **Qt 5.6** - Sailfish OS uses Qt 5.6, avoid newer Qt features
2. **Harbour Rules** - Must use `harbour-` prefix, only allowed dependencies
3. **Conversation storage format** - One JSON file per conversation under
   `AppDataLocation/conversations/`. Never reintroduce a single-blob write: it made
   every token-usage update rewrite the whole history.
4. **Streaming Only** - The app relies on SSE streaming; non-streaming mode not implemented
   (title generation is the one exception and uses a plain request)
5. **API key handling** - Never log it, never write it in clear text, never widen the
   permissions of the settings file. See `src/securestore.*`.
6. **Category identifiers** - `src/categories.cpp` and `qml/components/Categories.js`
   hold the same list twice; changing one without the other silently degrades to "Other".

### File Structure
```
src/                     # C++ backend classes and helpers
qml/pages/              # Main UI pages
qml/components/         # Reusable delegates and Categories.js
qml/cover/              # Active cover
tests/                  # QtTest suite, gates CI
rpm/harbour-sailcat.spec # RPM packaging spec
harbour-sailcat.pro     # QMake project file
harbour-sailcat.yaml    # Sailfish build config
harbour-sailcat.desktop # Desktop launcher entry
```

## Testing

Manual testing checklist from DEVELOPMENT.md:
1. First launch - verify welcome, enter API key in Settings
2. Send message - verify streaming display works
3. New conversation via pulley menu
4. Model switching in Settings
5. Cover page actions
6. Error handling with invalid API key

Test API directly:
```bash
curl -X POST https://api.mistral.ai/v1/chat/completions \
  -H "Authorization: Bearer YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"mistral-small-latest","messages":[{"role":"user","content":"Test"}],"stream":true}'
```
- memory message de commit, tag, commentaaire, code, tout doit etre en anglais
- memory Sailfish utilise Qt 5.6
- memory quand on fait des modifications, fait le plus possible de version patch