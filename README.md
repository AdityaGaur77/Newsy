# Newsy 📰

A child-friendly news reader built with Flutter. Newsy fetches age-appropriate
news, lets kids explore topics they love, optionally explains stories with AI in
simple language, reads them aloud, and gives parents a biometric-protected
dashboard to monitor activity.

## Features

- **Personalised feed** — pick topics (animals, space, sports, food…) and get a
  curated, de-duplicated news feed.
- **Explore** — full-text search with synonym expansion and relevance ranking.
- **AI Summary & Q&A** *(optional)* — explains a story in a few simple sentences
  and answers a child's follow-up questions. Requires an OpenAI key; the app
  hides these features automatically when no key is configured.
- **Read aloud** — text-to-speech narration of any story.
- **Saved stories** — bookmark articles to read later.
- **Parent Zone** — biometric / device-PIN protected dashboard with reading
  stats and recent activity.
- **Daily quotas** that reset at noon Pacific Time, with a live countdown.

## Getting started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart `>=3.x`)

### First-time setup

This repository tracks only the application code (`lib/`) and `pubspec.yaml`.
Generate the platform folders and fetch dependencies:

```bash
flutter create .      # scaffolds android/ ios/ web/ etc.
flutter pub get
```

### Configuring API keys

Keys are **never** committed to source. They are injected at build time via
`--dart-define`:

| Key                | Required | Purpose                                            |
| ------------------ | -------- | -------------------------------------------------- |
| `NEWSDATA_API_KEY` | No\*     | News feed via [newsdata.io](https://newsdata.io)   |
| `OPENAI_API_KEY`   | No       | Enables AI Summary & Q&A. Hidden when unset.        |
| `OPENAI_MODEL`     | No       | Defaults to `gpt-4o-mini`.                          |

\* A free demo NewsData key is bundled as a fallback so the feed works out of
the box, but you should supply your own for anything beyond local testing.

```bash
flutter run \
  --dart-define=NEWSDATA_API_KEY=your_newsdata_key \
  --dart-define=OPENAI_API_KEY=your_openai_key
```

Without an OpenAI key the app runs perfectly — the AI Summary button and the
"Ask a question" section simply don't appear.

## Project structure

```
lib/main.dart            # Entire app (UI, state, data layer)
pubspec.yaml             # Dependencies & metadata
analysis_options.yaml    # Lint rules (flutter_lints)
```

## Building for release

```bash
flutter build apk --release \
  --dart-define=NEWSDATA_API_KEY=... \
  --dart-define=OPENAI_API_KEY=...
```
