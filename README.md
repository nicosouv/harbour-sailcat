# SailCat 🐱⛵

<p align="center">
  <img src="icons/172x172/harbour-sailcat.png" alt="SailCat Logo" width="172"/>
</p>

**SailCat** is an elegant AI chat client, specifically designed for **Sailfish OS**. Talk to **Mistral AI**, **Scaleway**, **OVHcloud**, **Groq** or any OpenAI-compatible endpoint - including your own self-hosted one - directly from your Sailfish device.

> 🤖 **Since version 2.x, SailCat is developed with the help of AI** — Claude (Claude Code) and Mistral Vibe. Features are specified in [docs/features/](docs/features/), implemented together by a human developer and AI agents, validated by CI on three architectures and covered by unit tests before every release. A human still codes, reviews, tests on device and hits the tag button :)

## ✨ Features

- 🌍 **Your choice of provider** - Mistral AI, Scaleway, OVHcloud, Groq, or a custom OpenAI-compatible endpoint
- 🆓 **Free tiers supported** - Three of the four presets have one, and OVHcloud even answers without a key
- 🇪🇺 **European hosting available** - Scaleway and OVHcloud keep your conversations in the EU
- 🔑 **One key per provider** - Stored scrambled, never sent anywhere else
- ⚡ **Real-time streaming** - Instant and smooth responses
- 🖼️ **Image support (vision)** - Attach a photo and let Pixtral analyze it
- 🧠 **Live model list** - Fetched from whichever provider you picked, with a quick-switch button next to the input
- 🎭 **System prompt & personas** - Presets (Concise, Translator, Code assistant) or your own instruction
- 🎛️ **Generation settings** - Temperature and response length
- 💬 **Conversation history** - Search, per-conversation details, automatic titles and categories
- 📌 **Message actions** - Pin, edit & resend, regenerate, copy code blocks
- 📤 **Markdown export** - To Documents or clipboard
- 📊 **Statistics & badges** - Activity charts, real token tracking (per day/month/conversation), question categories, fun badges and top AI words
- 🎨 **Native Sailfish interface** - Swipe to history, bottom pulley menu, animations, live cover with the latest answer
- 🌍 **Multilingual** - English, French, German, Spanish, Finnish, Italian

## 🚀 Installation

### Prerequisites

- Sailfish OS 3.0+ or higher
- Internet connection
- An API key from one of the supported providers (free tiers available; OVHcloud works without one)

### Build from source

```bash
# Clone the repo
git clone https://github.com/nicosouv/harbour-sailcat.git
cd harbour-sailcat

# Build with Sailfish SDK
sfdk build

# Install the generated RPM
sfdk deploy --manual
```

### RPM Installation

Download the `.rpm` file from [releases](https://github.com/nicosouv/harbour-sailcat/releases) and install it on your Sailfish device.

## 🔧 Configuration

### Pick a provider

| Provider | Free tier | Hosting | Key |
|---|---|---|---|
| [Mistral AI](https://console.mistral.ai) | Experiment plan | 🇪🇺 France | Required |
| [Scaleway](https://console.scaleway.com) | 1M tokens | 🇪🇺 France | Required |
| [OVHcloud](https://endpoints.ai.cloud.ovh.net) | Rate-limited | 🇪🇺 France | Optional |
| [Groq](https://console.groq.com) | Yes, no credit card | 🇺🇸 US | Required |
| Custom endpoint | - | Wherever you point it | Optional |

⚠️ On Mistral's free "Experiment" plan, API inputs and outputs go into their model
training programs by default. Opt out in the Admin Console privacy settings if that
matters to you - the paid plans are excluded automatically.

### Configure SailCat

1. Launch SailCat
2. Access **Settings** via the pulley menu
3. Choose your **provider**
4. Paste the API key it gave you (or leave it empty on OVHcloud)
5. Choose your preferred model
6. Save and start chatting!

## 📖 Usage

### Start a conversation

1. Open SailCat
2. Type your message in the input field
3. Press the send button or Enter
4. Watch the response appear in real-time thanks to streaming

### New conversation

Use the pulley menu and select **"New conversation"** to clear history and start fresh.

### Available models

The model list is fetched live from the provider you selected and cached per provider for offline use. Switch models anytime with the button next to the text input. Each provider keeps its own key, its own default model and its own cached list.

## 🏗️ Technical Architecture

### Qt C++ Backend

- **MistralAPI** - HTTP request management with SSE (Server-Sent Events) streaming
- **ConversationModel** - QAbstractListModel for message display
- **ConversationManager** - Conversation persistence and management
- **SettingsManager** - Settings persistence with QSettings

### QML Frontend

- **ChatPage** - Main conversation interface with SilicaListView
- **SettingsPage** - API configuration and model selection
- **ConversationHistoryPage** - Browse past conversations
- **CoverPage** - Active cover with statistics

### Technologies used

- Qt 5.6 (QtCore, QtNetwork, QtQuick, QtQml)
- Sailfish Silica UI Components
- Mistral AI API (REST + Streaming)
- QML + JavaScript for the interface

## 🎯 Mistral API Features

### What's possible

SailCat fully leverages Mistral API capabilities:

- **Chat Completions** - Contextual conversations
- **Streaming** - Real-time responses (SSE)
- **Multiple models** - Access to Small, Large, and Pixtral
- **History** - Manual conversation context management
- **Free Tier** - Rate limits suitable for experimentation

### Endpoint used

```
POST https://api.mistral.ai/v1/chat/completions
```

### Request format

```json
{
  "model": "mistral-small-latest",
  "messages": [
    {"role": "user", "content": "Hello!"},
    {"role": "assistant", "content": "Hello! How can I help you?"}
  ],
  "stream": true
}
```

## 🔒 Security & Privacy

- ✅ API keys are stored locally with QSettings, isolated by Sailjail sandboxing
- ✅ No telemetry or analytics
- ✅ Direct communication with your provider (HTTPS), no intermediary
- ✅ No intermediate server
- ✅ Conversations stored locally on your device
- ✅ No sync with any web interface
- ✅ Sailjail permissions: Internet, Pictures (attachments), Documents (exports)
- ⚠️ Your API key gives access to your provider account - keep it secret

## 🚀 Releases & CI/CD

SailCat uses GitHub Actions to automatically build and publish releases.

### Automatic build

Each `vX.Y.Z` tag triggers a multi-architecture build:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The **build-docker.yml** workflow:
- ✅ Builds for armv7hl, aarch64, and i486
- ✅ Generates changelog from commits
- ✅ Creates GitHub release with RPMs
- ✅ Publishes automatically

Compiled RPMs are available in [Releases](https://github.com/nicosouv/harbour-sailcat/releases).

### PR Validation

Pull Requests are automatically validated with the **pr-build.yml** workflow that builds for armv7hl and runs the unit test suite.

### Tests

Backend classes are covered by a QtTest suite (`tests/`) that runs in CI on every build and blocks releases on failure:

```bash
cd tests && qmake tests.pro && make && ./tst_sailcat
```

### For maintainers

See [RELEASE.md](RELEASE.md) for the complete release guide.

## 🤝 Contributing

Contributions are welcome! Here's how to participate:

1. Fork the project
2. Create a branch for your feature (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 TODO / Roadmap

The detailed feature roadmap with per-feature specs lives in [docs/ROADMAP.md](docs/ROADMAP.md).

- [x] Image support with Pixtral (upload from gallery)
- [x] Persistent conversation saving
- [x] Conversation export (text, markdown)
- [x] Multiple simultaneous conversations
- [x] Advanced settings (temperature, max_tokens, system prompt)
- [x] Translations (English, French, German, Spanish, Finnish, Italian)
- [x] Statistics, token tracking, badges
- [ ] Custom color themes
- [ ] Mistral agents support

## 🐛 Known Issues

- Free tier rate limits can be restrictive for intensive usage
- Streaming can sometimes be slow depending on network connection
- No offline support (requires Internet connection)

## 📄 License

MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Mistral AI** for their excellent API and generous free tier
- **Jolla** for Sailfish OS and the Silica framework
- **The Sailfish community** for their support and feedback

## 📧 Contact

Nicolas Souv - [@nicosouv](https://github.com/nicosouv)

Project link: [https://github.com/nicosouv/harbour-sailcat](https://github.com/nicosouv/harbour-sailcat)

---

<p align="center">
  Made with ❤️ for Sailfish OS
</p>
