# DevSummary

> Summarize all your git commits in plain English.

DevSummary is a desktop app that scans your local git repositories, analyzes your commit history, and generates clear, human-readable summaries of what you've been working on.

## What It Does

DevSummary automatically discovers git repositories on your machine, reads your commit history for a selected time period, and produces:

- **A plain-English overview** of your development activity
- **Per-project breakdowns** with categorized changes (features, fixes, refactors, etc.)
- **Daily activity visualization** showing your coding patterns
- **A full commit timeline** across all your projects

## Why It Exists

When you work across multiple projects, it's hard to remember what you did last week — let alone explain it to someone else. DevSummary gives you an instant answer to "What have I been working on?" without digging through git logs manually.

## Features

- Auto-discovers git repos under `~/Development`, `~/Projects`, `~/Code`, `~/repos`, `~/src`
- Scans commit history across all branches
- Categorizes commits: features, bug fixes, refactors, docs, tests, style, deps, config
- Generates natural language summaries
- Time range selector: 1 week, 2 weeks, 1/3/6 months, 1 year
- Per-repo toggle — include or exclude any repository
- Daily activity bar chart
- Full commit list with repo tags
- Native macOS dark mode support
- Frameless window with native traffic lights
- Smooth animations (Framer Motion)

## Tech Stack

| Technology | Why |
|---|---|
| **Electron** | Real desktop app with native OS integration (titlebar, dark mode, vibrancy) |
| **React 19** | Fast, declarative UI with hooks |
| **Vite** | Sub-second HMR in development, fast production builds |
| **Framer Motion** | Fluid, physics-based animations |
| **Lucide React** | Clean, consistent icons |
| **date-fns** | Lightweight date formatting |

## Prerequisites

- **Node.js** >= 18 (`node --version`)
- **npm** >= 9 (`npm --version`)
- **git** (`git --version`)

## Installation

```bash
git clone https://github.com/thotas/DevSummary.git
cd DevSummary
npm install
```

## How to Run

**Development mode** (with hot reload):
```bash
npm run dev
```

**Production mode** (pre-built):
```bash
npx vite build && npx electron .
```

## Configuration

DevSummary scans these directories by default:
- `~/Development`
- `~/Projects`
- `~/Code`
- `~/repos`
- `~/src`

To change scan paths, modify the `getDefaultScanPaths` handler in `src/main/main.js`.

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│                  Electron                    │
│  ┌──────────┐  IPC  ┌───────────────────┐  │
│  │  Main     │◄────►│  Renderer (React)  │  │
│  │  Process  │      │  ┌─────────────┐   │  │
│  │           │      │  │ Sidebar     │   │  │
│  │ git-svc   │      │  │ SummaryView │   │  │
│  │ summarizer│      │  │ LoadingState│   │  │
│  └──────────┘      │  │ EmptyState  │   │  │
│                     │  └─────────────┘   │  │
│                     └───────────────────┘  │
└─────────────────────────────────────────────┘
```

- **Main Process**: Scans filesystem for repos, runs git commands, generates summaries
- **Preload Bridge**: Exposes safe IPC methods to the renderer
- **Renderer**: React app with sidebar (repo/period selection) and main content (summary display)

## File Structure

```
DevSummary/
├── src/
│   ├── main/
│   │   ├── main.js          # Electron main process, window management, IPC
│   │   ├── git-service.js   # Repo discovery, git log parsing, commit fetching
│   │   └── summarizer.js    # Commit categorization, plain-English summary generation
│   ├── preload/
│   │   └── preload.js       # Context bridge for secure IPC
│   └── renderer/
│       ├── index.html        # Entry HTML
│       ├── main.jsx          # React entry point
│       ├── App.jsx           # Root component, state management
│       ├── styles.css        # Full design system (light + dark themes)
│       └── components/
│           ├── Sidebar.jsx     # Repo list, period selector
│           ├── SummaryView.jsx # Main summary display
│           ├── LoadingState.jsx
│           └── EmptyState.jsx
├── package.json
├── vite.config.js
├── DECISIONS.md
└── ARCHITECTURE.md
```

## Known Limitations

- Scans only local repositories (no GitHub API integration)
- Summary generation is template-based (no AI/LLM — works fully offline)
- No persistent settings storage yet (scan paths are hardcoded)
- Commits are attributed by git author, not filtered by current user

## Roadmap

- [ ] AI-powered summaries (optional Claude API integration)
- [ ] Settings panel for custom scan paths
- [ ] Filter commits by author
- [ ] Export summary as markdown/PDF
- [ ] Slack/email integration for weekly reports
- [ ] GitHub integration for remote-only repos

## License

MIT
