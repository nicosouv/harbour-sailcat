# Changelog

All notable changes to SailCat will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.3.0] - 2026-08-26

### Added

- **SailCat is no longer tied to Mistral.** Every backend it can talk to speaks the
  same OpenAI chat-completions dialect, so the API layer now takes its endpoint from
  the selected provider instead of hardcoding `api.mistral.ai`. Presets ship for
  Mistral AI, Scaleway, OVHcloud AI Endpoints and Groq, plus a custom entry that takes
  any base URL - including a llama.cpp or Ollama server on the local network.
- Three of the four presets have a free tier, and the two French ones (Scaleway,
  OVHcloud) keep conversations in the EU. OVHcloud answers without an API key at a
  lower rate limit, so the app is usable before signing up anywhere.
- Each provider keeps its own API key, its own default model and its own model cache.
  Switching provider swaps the whole set; a key is never sent to another host.
- **A conversation is pinned to the provider it started with.** Changing the provider
  in the settings decides what new conversations use; it does not silently redirect
  an ongoing one. Each conversation can be moved to another provider from its own
  settings page, which spells out that the rest of it goes elsewhere and that the
  answers already received do not change.
- The chat header names who is answering (`Groq - llama-3.3-70b-versatile`), the model
  picker lists that provider's catalogue, and the history flags a conversation whose
  provider is not the selected one.
- **Every answer records the provider and model that produced it** and shows them
  under the message, so a conversation that changed provider halfway stays readable.
  Answers written before 2.3 are stamped with Mistral - the only provider that
  existed then - and show no model, which is genuinely not recoverable.

- **Statistics know who answers.** A "Providers and models" section reports the most
  used provider and the most used model, with a breakdown of answers per provider and
  per model. Counted from the answers themselves rather than from the token ledger,
  which carries no provider - so answers received before 2.3 count towards Mistral,
  under their provider only since their model was never recorded.
- The conversation history shows the provider and the model that answered last on each
  conversation.

### Changed

- The cost estimate reports "free" for a model served by a free-tier provider instead
  of pricing it from the Mistral list, and the model picker hides the image
  attachment button unless the catalogue says the model can read images.
- A per-conversation model override is checked against the active provider before
  every request: a Mistral model id is not sent to Groq.

## [2.2.1] - 2026-08-19

### Fixed

- **An answer could land in the wrong conversation.** `ConversationModel` is a single
  reused object, so opening another conversation while a response was streaming made
  the rest of the answer appear in - and be saved into - the conversation that was
  opened next. The stream is now tied to the conversation that asked: it keeps
  buffering in the background and is written back where it belongs, and coming back
  to it mid-response shows everything received so far.
- Token usage and the unread flag are charged to the conversation that asked, not to
  whatever happens to be on screen when the response ends.

### Changed

- "Conversation History" removed from the chat pulley: swiping back does it.
- "Settings & About" added to the history pulley, which is the root page and had no
  other way in.

## [2.2.0] - 2026-08-19

### Changed

- **Two-sided navigation from a conversation.** The history is now the root page
  with the chat on top of it: swipe back for the history, swipe forward for the
  settings of the current conversation. The app still opens directly on the chat.
- **Pulley menus split by what they act on** instead of carrying the same seven
  entries twice. Top: history, pinned messages, prompt library, settings. Bottom:
  conversation settings, export, new conversation. The history pulley drops the two
  entries that duplicated the chat's.
- **Streaming moved into C++.** `ConversationManager` now owns the accumulation and
  the throttling, so an answer keeps landing in the conversation when the chat page
  is popped - which is exactly what happens when you swipe back to the history
  mid-response. Token accounting moved with it.
- Conversation settings is a page rather than a dialog: it follows the current
  conversation and writes changes when you leave it, only for fields you touched.

### Added

- **Unread indicator.** A conversation receiving an answer shows a pulsing dot in the
  history; once the answer has landed it stays lit until you open the conversation.
  The flag is persisted, so it survives a restart.

## [2.1.1] - 2026-08-19

### Fixed

- **Conversation history was unusable in 2.1.0.** `getConversationsList()` returned a
  key named `model`, and a ListModel role called `model` shadows the delegate's own
  model object: every `model.title`, `model.id` and `model.category` lookup silently
  became `undefined`. Titles all read "Empty conversation", category chips vanished,
  and opening, renaming, exporting or sharing a conversation from the history did
  nothing. No data was lost - titles and categories were intact on disk the whole
  time, only the list could not read them.

### Added

- **Suggest a title** in the conversation settings: asks the model for a title and a
  category based on the whole conversation, not just the first message. The proposal
  fills the form and is only stored when you confirm.
- Automatic titling now reads a digest of the exchange instead of the first message
  alone, which gives noticeably better titles.

### Removed

- "Export" and "Share" from the conversation context menu in the history. Exporting
  stays available from the chat pulley menu.

## [2.1.0] - 2026-08-19

### Security

- API key is no longer written in clear text. It is scrambled with a per-install
  random salt and both the settings file and the conversation files are set to
  owner-only permissions. Existing keys are migrated automatically on first launch.
- Exported conversations are written with owner-only permissions.
- All API and update requests now require TLS 1.2 or later, verify the peer and
  refuse redirects, so a bearer token can never follow a redirect elsewhere.
- Markdown links are restricted to `http`, `https` and `mailto`; a `javascript:`
  URL in a model reply can no longer reach `Qt.openUrlExternally`.
- Quotes are escaped when rendering messages, closing an attribute injection in
  generated `<a href>` tags.
- The update checker only opens URLs on `github.com`.
- Conversation file names are validated, so an id can never escape the storage
  directory.
- The API key field is masked by default, with an explicit reveal switch.

### Added

- **Conversation context limit**: send only the most recent N messages, with an
  on-screen notice of how many were left out. Keeps long conversations affordable
  and avoids hitting the model context window.
- **Prompt library**: save, edit and reuse prompts, insertable into the input field.
- **Per-conversation model and system prompt**, plus title and category, from a new
  conversation settings page.
- **Retry button** on the error banner: resend without retyping.
- **Chat styles**: flat, bubbles, compact and cards, with an option to hide timestamps.
- **28 conversation categories** instead of 7 (code, debugging, devops, data, design,
  writing, translation, learning, research, maths, science, business, finance, career,
  legal, health, cooking, travel, home, gaming, music, books & movies, sports,
  relationships, productivity, ideas, practical, other), a local keyword classifier that
  takes over when the model answers "other", and an "Auto-label conversations" action
  that relabels existing ones.
- **Estimated cost** per model in the statistics page, from a hand-maintained price list.
- **Rename a conversation** from the history page.
- **Share a conversation** through the Sailfish share menu, when available.
- Live answer preview on the cover page.
- **Norwegian bokmål** translation (thanks @fsilye), selectable from the settings.

### Changed

- Conversations are stored as one JSON file per conversation under the app data
  directory instead of a single blob in QSettings. Writes now touch only the
  conversation that changed. Existing data is migrated automatically.
- Streaming updates are coalesced at ~11 fps instead of repainting the whole message
  on every token, which removes the stutter on long answers.
- Attached images are copied into the app data directory and stay in the request
  payload on later turns, so follow-up questions about a picture still see it.
- Images and the per-conversation model are now honoured when regenerating a response.
- The "Use my own API key" switch is gone: there is no bundled key, so it only ever
  got in the way.
- Title generation is billed and now counted in the token statistics.
- All seven translations now carry the same set of strings, with the obsolete ones
  removed and the gaps where de/es/fi/it had been left in English filled in.

### Removed

- In-app update check. It was already unreachable from the UI in 2.0.4, and the store
  handles updates; the whole `UpdateChecker` class is gone. The settings page still
  shows the running version.

### Fixed

- A message sent just before the app was closed is no longer lost: the conversation
  is saved before the request and whenever the app leaves the foreground.
- The token banner keeps the running total when reopening an existing conversation
  instead of showing zero.
- A rejected request no longer leaves an empty assistant bubble behind, which used to
  be persisted and then sent back to the API.
- The conversation title is no longer regenerated after editing a message back down
  to two messages.
- Removed the dead `ConversationListPage.qml` and stale entries in the translation files.

## [2.0.4] - 2026-07-04

### Added

- QtTest unit suite covering the backend classes, wired as a CI gate on pull
  requests and on release builds.

### Changed

- README updated for the 2.x feature set.

## [1.0.0] - 2025-11-10

### Added

#### Core Features
- Complete Mistral AI integration with streaming support
- Native Sailfish OS UI using Silica components
- Real-time conversation with Server-Sent Events (SSE)
- Support for Mistral free tier and custom API keys
- Multiple model selection (Small, Large, Pixtral)

#### Backend (Qt C++)
- **MistralAPI** class for HTTP communication
  - POST requests to `/v1/chat/completions`
  - SSE streaming parser for progressive responses
  - Error handling and network management
  - Request cancellation support
- **ConversationModel** (QAbstractListModel)
  - Message history management
  - Real-time update during streaming
  - JSON conversion for API requests
- **SettingsManager**
  - Persistent storage with QSettings
  - API key management
  - Model selection persistence

#### Frontend (QML/Silica)
- **ChatPage**
  - Message list with SilicaListView
  - Text input with send button
  - Streaming response display
  - Loading indicators
  - Error messages
  - Pulley menu (Settings, About, New Conversation)
- **SettingsPage**
  - API key configuration dialog
  - Model selection ComboBox
  - Custom key toggle switch
  - Key deletion with remorse
- **AboutPage**
  - Application information
  - Feature list
  - Credits and license
  - GitHub link
- **CoverPage**
  - Active cover with message count
  - Quick action to clear conversation

#### Infrastructure
- GitHub Actions CI/CD
  - Multi-architecture builds (armv7hl, aarch64, i486)
  - Automated RPM releases on tags
  - PR validation builds
- Comprehensive documentation
  - README.md with usage guide
  - ARCHITECTURE.md with technical details
  - DEVELOPMENT.md for contributors
  - CONTRIBUTING.md with guidelines
- RPM packaging configuration
  - Spec file for all architectures
  - Desktop file for launcher
  - YAML build configuration

### Technical Details

#### API Integration
- Endpoint: `https://api.mistral.ai/v1/chat/completions`
- Supported models:
  - mistral-small-latest (default)
  - mistral-large-latest
  - pixtral-12b-latest
- Authentication: Bearer token
- Streaming: SSE with real-time parsing

#### Platform Support
- Sailfish OS 3.0+
- Qt 5.6
- Architectures: armv7hl, aarch64, i486

#### Security
- Local API key storage only
- HTTPS-only communication
- No telemetry or tracking
- No third-party services

### Known Limitations

- No offline mode (requires internet)
- No conversation persistence (lost on app close)
- No image upload support (Pixtral model text-only for now)
- Free tier rate limits may be restrictive

## Future Plans

### [1.1.0] - Planned

- Persistent conversation storage
- Multiple conversation threads
- Export conversations (text, markdown)
- Dark theme option

### [1.2.0] - Planned

- Image upload support for Pixtral
- Voice input integration
- Advanced API parameters (temperature, max_tokens)

### [2.0.0] - Ideas

- Mistral Agents API support
- Local conversation search
- Conversation sharing
- Multiple language support
- Custom system prompts

---

[Unreleased]: https://github.com/nicosouv/harbour-sailcat/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/nicosouv/harbour-sailcat/releases/tag/v1.0.0
