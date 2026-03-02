# DevSummary

> Summarize all your git commits in plain English — native macOS app.

DevSummary is a native macOS app built with SwiftUI that scans your local git repositories, analyzes your commit history, and generates clear, human-readable summaries of what you've been working on.

```
┌─────────────────────────────────────────────────────────┐
│ DevSummary                                              │
│ ┌──────────────┬────────────────────────────────────────┤
│ │ Time Range   │  Your Dev Summary                      │
│ │ [Past Week▾] │  Generated Sunday, March 2, 2026       │
│ │              │                                        │
│ │ Repositories │  Over this past week, you made 47      │
│ │ ☑ BillCalendar  commits across 8 projects, active on │
│ │ ☑ ClockIn    │  5 days. Your most active project was  │
│ │ ☑ email-tldr │  LocalMind with 12 commits.            │
│ │ ☑ hn-digest  │                                        │
│ │ ☑ LocalMind  │  ┌──────┐ ┌──────┐ ┌──────┐           │
│ │ ☑ podcast-dig│  │  47  │ │   8  │ │   5  │           │
│ │ ☑ RecipeManag│  │Commit│ │Repos │ │ Days │           │
│ │ ☑ RedDrop    │  └──────┘ └──────┘ └──────┘           │
│ │              │                                        │
│ └──────────────┴────────────────────────────────────────┤
└─────────────────────────────────────────────────────────┘
```

## What It Does

DevSummary automatically discovers git repositories on your machine, reads your commit history for a selected time period, and produces:

- A **plain-English overview** of your development activity
- **Per-project breakdowns** with categorized changes (features, fixes, refactors, etc.)
- **Daily activity visualization** showing your coding patterns
- A **full commit timeline** across all your projects

## Why It Exists

When you work across multiple projects, it's hard to remember what you did last week — let alone explain it to someone else. DevSummary gives you an instant answer to "What have I been working on?" without digging through git logs manually.

## Features

- **Native macOS app** — SwiftUI, system materials, vibrancy, native titlebar
- Auto-discovers git repos under `~/Development`, `~/Projects`, `~/Code`, `~/repos`, `~/src`
- Scans commit history across all branches
- Categorizes commits: features, bug fixes, refactors, docs, tests, style, deps, config
- Generates natural language summaries
- Time range selector: 1 week, 2 weeks, 1/3/6 months, 1 year
- Per-repo toggle — include or exclude any repository
- Daily activity bar chart
- Full commit list with repo tags
- Dark mode support (follows system)
- NavigationSplitView with sidebar

## Tech Stack

| Technology | Why |
|---|---|
| **Swift 6.0** | Latest language features, strict concurrency |
| **SwiftUI** | Native macOS declarative UI framework |
| **Swift Concurrency** | async/await, actors, TaskGroup for parallel git ops |
| **Process (Foundation)** | Safe subprocess execution for git commands |
| **Swift Package Manager** | Native build system, no third-party dependencies |

**Zero third-party dependencies.** Everything is built with Apple frameworks.

## Prerequisites

- **macOS 14.0+** (Sonoma or later)
- **Xcode Command Line Tools** or Xcode (`xcode-select --install`)
- **git** (included with macOS developer tools)

## Installation

```bash
git clone https://github.com/thotas/DevSummary.git
cd DevSummary
```

## How to Run

**Build and run directly:**
```bash
swift build && .build/debug/DevSummary
```

**Build as .app bundle and install:**
```bash
./build.sh
open DevSummary.app
```

**Install to Applications:**
```bash
./build.sh
cp -r DevSummary.app /Applications/
```

## Configuration

DevSummary scans these directories by default:
- `~/Development`
- `~/Projects`
- `~/Code`
- `~/repos`
- `~/src`

To change scan paths, modify `GitService.defaultScanPaths` in `Sources/DevSummary/Services/GitService.swift`.

## Architecture Overview

```
┌────────────────────────────────────────────┐
│            DevSummaryApp (@main)            │
│  ┌──────────┐  ┌─────────────────────────┐ │
│  │ Sidebar   │  │  SummaryDetailView      │ │
│  │ View      │  │  ┌─────────────────┐    │ │
│  │           │  │  │ Overview Card    │    │ │
│  │ • Period  │  │  │ Stats Row       │    │ │
│  │ • Repos   │  │  │ Activity Chart  │    │ │
│  │           │  │  │ Repo Summaries  │    │ │
│  └──────────┘  │  │ Commit List     │    │ │
│                 │  └─────────────────┘    │ │
│  AppViewModel   └─────────────────────────┘ │
│  (ObservableObject)                         │
│      ↕                                      │
│  GitService (actor)                         │
│  CommitSummarizer (struct)                  │
└────────────────────────────────────────────┘
```

## File Structure

```
DevSummary/
├── Package.swift                  # SPM manifest, macOS 14+
├── build.sh                       # Builds .app bundle
├── Sources/DevSummary/
│   ├── DevSummaryApp.swift        # @main entry, WindowGroup
│   ├── Models/
│   │   └── GitModels.swift        # GitRepo, GitCommit, Summary, TimePeriod, CommitType
│   ├── Services/
│   │   ├── GitService.swift       # Actor: repo discovery, git log, Process-based execution
│   │   └── CommitSummarizer.swift # Commit categorization, plain-English generation
│   ├── ViewModels/
│   │   └── AppViewModel.swift     # @MainActor ObservableObject, orchestrates data flow
│   └── Views/
│       ├── ContentView.swift      # NavigationSplitView root
│       ├── SidebarView.swift      # Repo list, period picker
│       ├── SummaryDetailView.swift # Stats, charts, repo cards, commit list, FlowLayout
│       ├── LoadingView.swift      # ProgressView with context message
│       └── EmptyStateView.swift   # Empty/error state
├── README.md
├── DECISIONS.md
└── ARCHITECTURE.md
```

## Known Limitations

- Scans only local repositories (no GitHub API integration)
- Summary generation is template-based (no AI/LLM — works fully offline)
- No persistent settings storage yet (scan paths are hardcoded)
- Commits are attributed by git author, not filtered by current user
- Not code-signed (may require right-click → Open on first launch)

## Roadmap

- [ ] AI-powered summaries (optional Claude API integration)
- [ ] Settings panel for custom scan paths
- [ ] Filter commits by author
- [ ] Export summary as markdown/PDF
- [ ] Slack/email integration for weekly reports
- [ ] Menu bar widget for quick glance
- [ ] Code signing and notarization

## License

MIT
