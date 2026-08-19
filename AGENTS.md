# AGENTS.md

Instructions for AI coding agents (Mistral Vibe, Claude Code, etc.) working on this repository.

## Project

SailCat is a native Sailfish OS chat client for Mistral AI. Qt/C++ backend, QML/Silica frontend, SSE streaming for real-time responses.

## Hard Constraints

These are non-negotiable. Violating them produces code that does not compile or gets rejected by the Jolla Store:

1. **Qt 5.6 only.** Sailfish OS ships Qt 5.6. Do not use any API introduced in Qt 5.7+ (no `qAsConst`, no `QRandomGenerator`, no connection syntax requiring newer Qt, no C++17-dependent Qt APIs). When unsure whether an API exists in 5.6, check the Qt 5.6 docs before using it.
2. **QML: QtQuick 2.0 + Sailfish.Silica 1.0.** No QtQuick.Controls, no ToolTip, no `additionalContent`, no Qt Labs modules. Only Silica components. Past crashes were caused by exactly this (see git log).
3. **Harbour rules.** App name keeps the `harbour-` prefix. Only Harbour-allowed imports (Sailfish.Silica, Sailfish.Pickers, QtQuick, QtQuick.Layouts, Nemo.Configuration, Nemo.Notifications). `Sailfish.TransferEngine` and `Sailfish.Share` are NOT allowed.
4. **JavaScript in QML is ES5.** No arrow functions, no `let`/`const` in older QML contexts, no template literals.

## Architecture

- `src/mistralapi.{h,cpp}` — HTTP + SSE streaming to `POST https://api.mistral.ai/v1/chat/completions`. Signals: `streamingResponse(content)`, `responseCompleted()`, `messageSent()`, `titleGenerated(title)`.
- `src/conversationmodel.{h,cpp}` — QAbstractListModel of messages (`role`, `content`, `timestamp`, `pinned`, `imagePath`).
- `src/conversationmanager.{h,cpp}` — persistence (one JSON file per conversation under `AppDataLocation`), current conversation lifecycle, `buildApiMessages()`, statistics, search.
- `src/settingsmanager.{h,cpp}` — QSettings wrapper: `apiKey` (stored obfuscated), `modelName`, `nextMessageModel`, `language`, `contextMessageLimit`, `chatStyle`, `savedPrompts`.
- `src/securestore.{h,cpp}` — owner-only file permissions and salted obfuscation for the API key.
- `src/categories.{h,cpp}` — conversation categories and the local keyword classifier. Mirrored for display in `qml/components/Categories.js`.
- `qml/pages/ChatPage.qml` — main chat UI. `qml/components/MessageBubble.qml` — message rendering with regex-based markdown. `qml/pages/SettingsPage.qml` — settings dialog.

All C++ classes are exposed to QML as context properties: `mistralApi`, `conversationModel`, `conversationManager`, `settingsManager` (registered in `src/harbour-sailcat.cpp`).

## Translations

`translations/harbour-sailcat-<code>.ts`, one per entry in `SettingsManager::availableLanguages()`:
en, fr, de, es, fi, it, nb_NO. Adding a language means adding the `.ts` file, the code in
`availableLanguages()`, the `TRANSLATIONS` list in the `.pro`, and the entry in the SettingsPage
language ComboBox — the ComboBox order must match `availableLanguages()`.

## Build & Test

```bash
# Docker build (no SDK needed) — this is the reliable way to verify compilation
docker run --rm -it -v $(pwd):/home/sailfish/src -w /home/sailfish/src \
  coderus/sailfishos-platform-sdk:5.0.0.43 \
  mb2 -t SailfishOS-5.0.0.43-armv7hl build
```

Unit tests live in `tests/` (QtTest, no Silica dependency — the C++ classes are pure Qt). They run in CI on plain Ubuntu Qt and block releases. Locally:

```bash
cd tests && qmake tests.pro && make && ./tst_sailcat
```

When changing `src/` behavior, extend `tests/tst_main.cpp` accordingly. QML remains manually tested: hot-deploy without rebuilding via `scp qml/... nemo@<device-ip>:/usr/share/harbour-sailcat/qml/...` then restart the app.

New source files must be added to `harbour-sailcat.pro` (SOURCES/HEADERS) and new QML files to the `OTHER_FILES`/install sections. New user-visible strings must use `qsTr()`.

## Conventions

- **Everything in English**: code, comments, commit messages, tags, docs.
- **Commits**: one-liner, very concise, conventional prefix (`feat:`, `fix:`, `chore:`). No emoji, no "Co-authored-by" or AI attribution lines.
- **Tags/releases**: semver `vX.Y.Z`, prefer patch bumps for most changes. Pushing a tag triggers the release CI (`.github/workflows/build-docker.yml`), which builds armv7hl/aarch64/i486 and creates the GitHub release. Bump the version in `rpm/harbour-sailcat.spec` and `harbour-sailcat.yaml` when releasing.
- Match existing code style: 4-space indent in C++ and QML, Qt naming (`m_` member prefix, camelCase).

## Working Style

- Be concise. Answer the question first, then supporting detail. No filler.
- Read the relevant files before editing; never guess a method name or signature — verify it in the header.
- Keep changes minimal and scoped to the request. Do not refactor adjacent code unless asked.
- Comments only where the code cannot explain itself (protocol quirks, Qt 5.6 workarounds). No narrative comments.
- If a build or test fails, report the actual error output — do not claim success without verifying.
- Feature work is specified in `docs/features/`. When asked to implement a feature, read its spec file first and follow it; update `docs/ROADMAP.md` status when done.

## Mistral API Quick Reference

```
POST https://api.mistral.ai/v1/chat/completions
Authorization: Bearer <key>
{"model": "...", "messages": [{"role": "user|assistant|system", "content": "..."}], "stream": true}
```

SSE response: lines of `data: {"choices":[{"delta":{"content":"..."}}]}` terminated by `data: [DONE]`. Parsing lives in `MistralAPI::parseStreamLine()`; UTF-8-safe buffering in `processStreamData()`.
