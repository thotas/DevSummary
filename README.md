# DevSummary

> AI-powered summaries of all your git commits in plain English — native macOS app.

DevSummary is a native macOS app that scans your local git repositories, reads README files and commit history, and uses Ollama to generate rich, human-readable summaries of what each project is and what you've been working on.

```
┌─────────────────────────────────────────────────────────────┐
│ DevSummary                                                  │
│ ┌──────────────┬────────────────────────────────────────────┤
│ │ Time Range   │  Dev Summary              ● Ollama  ⟳  ⚙  │
│ │ [Past Week▾] │  Generated Sunday, March 2, 2026           │
│ │              │                                            │
│ │ Repositories │  ✨ AI Summary                              │
│ │ ☑ BillCalendar  This week you focused on building two   │
│ │ ☑ ClockIn    │  new apps — DevSummary for commit          │
│ │ ☑ LocalMind  │  analysis and ClockIn for time tracking... │
│ │ ☑ podcast-dig│                                            │
│ │ ☑ RedDrop    │  ┌──────┐ ┌──────┐ ┌──────┐               │
│ │              │  │  47  │ │   8  │ │   5  │               │
│ │              │  │Commit│ │Repos │ │ Days │               │
│ │              │  └──────┘ └──────┘ └──────┘               │
│ │              │                                            │
│ │              │  📁 LocalMind                    12 commits│
│ │              │  ┌─────────────────────────────────────┐   │
│ │              │  │ LocalMind is a native macOS app for │   │
│ │              │  │ local AI chat. This week, work       │   │
│ │              │  │ focused on adding RAG support...     │   │
│ │              │  └─────────────────────────────────────┘   │
│ └──────────────┴────────────────────────────────────────────┤
└─────────────────────────────────────────────────────────────┘
```

## What It Does

DevSummary automatically discovers git repositories, reads each project's README and commit history, and uses a local Ollama model to generate:

- An **AI-powered overall summary** paragraph of all your development activity
- **Per-project summaries** explaining what each project is and what changed recently
- **Daily activity visualization** showing your coding patterns
- **Commit categorization** (features, fixes, refactors, docs, etc.)
- A **full commit timeline** across all projects

Summaries are **cached locally** and only regenerated when git changes are detected or you explicitly ask for a refresh.

## Why It Exists

When you work across multiple projects, it's hard to explain what you've been doing. DevSummary gives you a polished, AI-written report of your development activity — like a standup update that writes itself.

## Features

- **Native macOS app** — SwiftUI, system materials, vibrancy
- **Ollama integration** — uses local AI models for intelligent summarization
- **Configurable model** — choose any Ollama model (llama3, gemma3, qwen2.5-coder, etc.)
- **README-aware** — reads each project's README to understand what it does
- **Smart caching** — persists summaries in `~/Library/Application Support/DevSummary/`, only regenerates on git changes
- **Per-project regeneration** — refresh individual project summaries on demand
- Auto-discovers repos under `~/Development`, `~/Projects`, `~/Code`, `~/repos`, `~/src`
- Time range selector: 1 week to 1 year
- Commit categorization: features, fixes, refactors, docs, tests, style, deps, config
- Daily activity bar chart
- Full commit list with repo tags
- Dark mode support (follows system)
- Custom app icon
- Settings panel for model selection

## Tech Stack

| Technology | Why |
|---|---|
| **Swift 6.0** | Latest language features, strict concurrency |
| **SwiftUI** | Native macOS declarative UI |
| **Ollama API** | Local AI inference, no cloud dependency, privacy-first |
| **Swift Concurrency** | async/await, actors, TaskGroup for parallel operations |
| **UserDefaults** | Persistent settings (model selection, scan paths) |
| **JSON file cache** | Summary persistence in Application Support |
| **Foundation Process** | Safe subprocess execution for git commands |

**Zero third-party Swift dependencies.** Ollama runs separately.

## Prerequisites

- **macOS 14.0+** (Sonoma or later)
- **Xcode Command Line Tools** (`xcode-select --install`)
- **Ollama** installed and running (`brew install ollama && ollama serve`)
- At least one Ollama model pulled (`ollama pull llama3`)

## Installation

```bash
git clone https://github.com/thotas/DevSummary.git
cd DevSummary
./build.sh
open DevSummary.app
```

## How to Run

**Build and launch:**
```bash
./build.sh && open DevSummary.app
```

**Install to Applications:**
```bash
./build.sh && cp -r DevSummary.app /Applications/
```

**Development mode:**
```bash
swift build && .build/debug/DevSummary
```

## Configuration

### Ollama Model
Open Settings (gear icon) to select which Ollama model to use. Default: `llama3`.

### Scan Paths
By default scans: `~/Development`, `~/Projects`, `~/Code`, `~/repos`, `~/src`

### Cache
Summaries are stored in `~/Library/Application Support/DevSummary/summary_cache.json`. Use the "Regenerate" button to force refresh all summaries.

## Architecture Overview

```
┌──────────────────────────────────────────────────┐
│            DevSummaryApp (@main)                  │
│  ┌─────────┐  ┌────────────────────────────────┐ │
│  │ Sidebar  │  │  SummaryDetailView              │ │
│  │ • Period │  │  • AI Overall Summary           │ │
│  │ • Repos  │  │  • Stats Cards                  │ │
│  │          │  │  • Activity Chart               │ │
│  └─────────┘  │  • Project Cards (AI + commits)  │ │
│                │  • Commit Timeline               │ │
│  AppViewModel  └────────────────────────────────┘ │
│      ↕              ↕               ↕             │
│  GitService    OllamaService    CacheService      │
│  (actor)       (actor)          (actor)           │
│      ↓              ↓               ↓             │
│  /usr/bin/git   localhost:11434   AppSupport/     │
└──────────────────────────────────────────────────┘
```

## File Structure

```
DevSummary/
├── Package.swift
├── build.sh                       # Builds .app bundle with icon
├── Assets/
│   └── AppIcon.icns               # App icon
├── Sources/DevSummary/
│   ├── DevSummaryApp.swift        # @main entry
│   ├── Models/
│   │   └── GitModels.swift        # GitRepo, GitCommit, ProjectSummary, Summary, etc.
│   ├── Services/
│   │   ├── GitService.swift       # Repo discovery, git log, README reading
│   │   ├── OllamaService.swift    # Ollama HTTP API client, summarization prompts
│   │   ├── CacheService.swift     # JSON-based summary persistence
│   │   ├── CommitSummarizer.swift # Commit categorization, template-based lines
│   │   └── AppSettings.swift      # UserDefaults-backed settings
│   ├── ViewModels/
│   │   └── AppViewModel.swift     # Orchestrates git, Ollama, and cache
│   └── Views/
│       ├── ContentView.swift
│       ├── SidebarView.swift
│       ├── SummaryDetailView.swift # Stats, AI summary, project cards, commits
│       ├── SettingsView.swift      # Ollama model picker
│       ├── LoadingView.swift
│       └── EmptyStateView.swift
├── README.md
├── DECISIONS.md
└── ARCHITECTURE.md
```

## Known Limitations

- Requires Ollama running locally (no cloud AI fallback)
- Not code-signed (may need right-click → Open on first launch)
- Scan paths not yet configurable from the UI
- Commits are not filtered by author

## Roadmap

- [ ] UI for configuring scan paths
- [ ] Filter commits by author
- [ ] Export summary as markdown/PDF
- [ ] Menu bar widget
- [ ] Code signing and notarization
- [ ] Scheduled weekly summary with notifications

## License

MIT
