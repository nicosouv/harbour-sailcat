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

Four main classes handle core functionality:

1. **MistralAPI** (`src/mistralapi.*`)
   - Manages HTTP communication with Mistral AI API
   - Implements SSE streaming parser for real-time responses
   - Parses `data: [DONE]` and JSON chunks from stream
   - Signals: `streamingResponse()`, `responseCompleted()`, `messageSent()`
   - Properties: `isBusy`, `error`

2. **ConversationModel** (`src/conversationmodel.*`)
   - QAbstractListModel for displaying messages in ListView
   - Stores messages with role ("user"/"assistant"), content, timestamp
   - Key methods:
     - `addUserMessage()` - Add new user message
     - `addAssistantMessage()` - Start new assistant response
     - `updateLastAssistantMessage()` - Update during streaming
     - `toJsonArray()` - Convert to Mistral API format
   - Roles: `RoleRole`, `ContentRole`, `TimestampRole`

3. **SettingsManager** (`src/settingsmanager.*`)
   - Wraps QSettings for persistent configuration
   - Properties: `apiKey`, `modelName`, `useCustomKey`
   - Available models: mistral-small-latest, mistral-large-latest, pixtral-12b-latest

4. **UpdateChecker** (`src/updatechecker.*`)
   - Checks for new app versions via GitHub Releases API
   - Endpoint: `https://api.github.com/repos/nicosouv/harbour-sailcat/releases/latest`
   - Implements semantic versioning comparison (major.minor.patch)
   - Properties: `currentVersion`, `latestVersion`, `updateAvailable`, `checking`, `releaseUrl`
   - Method: `checkForUpdates()` - Triggers version check
   - Signals: `latestVersionChanged()`, `updateAvailableChanged()`, `checkingChanged()`

### Frontend (QML/Silica)

- **qml/pages/ChatPage.qml** - Main conversation interface with SilicaListView displaying ConversationModel
- **qml/pages/SettingsPage.qml** - API key configuration, model selection, and update checker
  - Shows current version and check for updates button
  - Displays update notification when new version available (tappable to open GitHub release)
- **qml/pages/AboutPage.qml** - Application information
- **qml/cover/CoverPage.qml** - Active cover showing message count

### Data Flow

```
User sends message → ChatPage.sendMessage()
  → conversationModel.addUserMessage()
  → mistralApi.sendMessage(apiKey, modelName, messages)
  → POST https://api.mistral.ai/v1/chat/completions
  → SSE stream chunks → mistralApi.onReadyRead()
  → parseStreamLine() extracts JSON
  → emit streamingResponse(content)
  → ChatPage Connections handler
  → conversationModel.updateLastAssistantMessage()
  → ListView automatically updates
```

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
  - Uses `0.1.0-dev` for manual builds without tags
  - Updates `rpm/harbour-sailcat.spec` with extracted version
  - Builds for armv7hl, aarch64, i486 in parallel
  - Creates GitHub release with changelog (tag builds only)
- **pr-build.yml** - Validates PRs with armv7hl build

### Important Constraints

1. **Qt 5.6** - Sailfish OS uses Qt 5.6, avoid newer Qt features
2. **Harbour Rules** - Must use `harbour-` prefix, only allowed dependencies
3. **No Conversation Persistence** - Currently conversations are lost on app close (see CHANGELOG.md for future plans)
4. **Streaming Only** - The app relies on SSE streaming; non-streaming mode not implemented

### File Structure
```
src/                     # C++ backend classes
qml/pages/              # Main UI pages (Chat, Settings, About)
qml/cover/              # Active cover
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