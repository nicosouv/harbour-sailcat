# Changelog

All notable changes to SailCat will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
