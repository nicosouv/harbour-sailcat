# Feature Roadmap

Each feature has a detailed spec in `docs/features/`. Implement them one at a time, in order within a phase (later specs sometimes build on earlier ones — dependencies are listed in each spec). Bump a patch version and tag a release after each feature or small batch.

Status legend: `todo` / `in progress` / `done`

## Phase 1 — API quick wins (backend-focused, low risk)

| # | Feature | Spec | Status |
|---|---------|------|--------|
| 01 | Generation parameters (temperature, max_tokens) | [01-generation-parameters.md](features/01-generation-parameters.md) | done (v1.9.7) |
| 02 | System prompt / personas | [02-system-prompt.md](features/02-system-prompt.md) | done (v1.9.8) |
| 03 | Token usage tracking | [03-token-usage.md](features/03-token-usage.md) | done (v1.9.9) |
| 04 | Dynamic model list from API | [04-dynamic-model-list.md](features/04-dynamic-model-list.md) | done (v1.9.10) |

## Phase 2 — Chat UX

| # | Feature | Spec | Status |
|---|---------|------|--------|
| 05 | Regenerate last response | [05-regenerate-response.md](features/05-regenerate-response.md) | done (v1.9.11) |
| 06 | Edit user message & resend | [06-edit-message.md](features/06-edit-message.md) | done (v1.9.12) |
| 07 | Export conversation | [07-export-conversation.md](features/07-export-conversation.md) | done (v1.9.13) |
| 08 | Copy code block | [08-copy-code-block.md](features/08-copy-code-block.md) | done (v1.9.14) |

## Phase 3 — Vision

| # | Feature | Spec | Status |
|---|---------|------|--------|
| 09 | Image support for Pixtral | [09-pixtral-vision.md](features/09-pixtral-vision.md) | done (v2.0.0) |

## Phase 4 — Design & polish

| # | Feature | Spec | Status |
|---|---------|------|--------|
| 10 | Design fixes (theming, markdown, timestamps, dedup) | [10-design-polish.md](features/10-design-polish.md) | done (10.1 via #12, 10.4 via #11, rest v1.9.18) |

## Phase 5 — User-requested UX (July 2026)

| # | Feature | Spec | Status |
|---|---------|------|--------|
| 11 | Chat UX: bottom menu, token banner, swipe to history | [11-ux-improvements.md](features/11-ux-improvements.md) | done (v1.9.15) |
| 12 | Better markdown rendering | [12-markdown-rendering.md](features/12-markdown-rendering.md) | done (v1.9.16) |
| 13 | Pinned messages | [13-pinned-messages.md](features/13-pinned-messages.md) | done (v1.9.17) |
| 14 | Eye candy animations | [14-eye-candy.md](features/14-eye-candy.md) | done (v1.9.19) |
| 15 | Animated stats & graphs in conversation pages | [15-inline-stats-graphs.md](features/15-inline-stats-graphs.md) | done (v1.9.20) |
| 16 | Usability: full menus everywhere, model button | [16-usability.md](features/16-usability.md) | done (v1.9.21) |
| 17 | Question categories & meaningful stats | [17-categories-and-real-stats.md](features/17-categories-and-real-stats.md) | done (v1.9.22) |
| 18 | Fun stats, badges & cover mini-stats | [18-fun-stats-badges.md](features/18-fun-stats-badges.md) | done (v2.0.3) |
| 19 | Unit test suite (QtTest + CI gate) | [19-unit-tests.md](features/19-unit-tests.md) | done (v2.0.4) |

## Phase 6 — Audit follow-up (August 2026)

Everything below shipped together in v2.1.0, see [20-audit-followup.md](features/20-audit-followup.md).

| # | Feature | Status |
|---|---------|--------|
| 20.1 | Encrypted-at-rest API key, owner-only files, TLS 1.2+, link scheme allowlist | done (v2.1.0) |
| 20.2 | Per-file conversation storage with migration | done (v2.1.0) |
| 20.3 | Conversation context limit | done (v2.1.0) |
| 20.4 | Streaming render throttling | done (v2.1.0) |
| 20.5 | Prompt library | done (v2.1.0) |
| 20.6 | Per-conversation model & system prompt, rename | done (v2.1.0) |
| 20.7 | Retry on error | done (v2.1.0) |
| 20.8 | Selectable chat styles | done (v2.1.0) |
| 20.9 | 28 categories + local classifier + relabel action | done (v2.1.0) |
| 20.10 | Cost estimation in statistics | done (v2.1.0) |
| 20.11 | Share via Sailfish share menu | done (v2.1.0) |
| 20.12 | Update checker removed (was dead code) | done (v2.1.0) |
| 20.13 | Live answer on the cover | done (v2.1.0) |

Deliberately not done: conversation import (owner's call), PDF attachments (needs a
parser outside the harbour allowed dependencies).

## Already done (do not re-implement)

- Conversation persistence, history page, search (`ConversationManager::searchConversations` + `SearchField` in ConversationHistoryPage)
- Statistics page with activity charts
- Per-message model override (`nextMessageModel`)
- Auto-generated conversation titles
- Update checker via GitHub Releases
