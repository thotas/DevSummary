# Architecture

## System Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     Electron Application                     │
│                                                              │
│  ┌─────────────────────┐      ┌──────────────────────────┐  │
│  │    MAIN PROCESS      │      │   RENDERER PROCESS        │  │
│  │                      │      │                           │  │
│  │  ┌────────────────┐  │ IPC  │  ┌─────────────────────┐ │  │
│  │  │  git-service    │  │◄───►│  │      App.jsx         │ │  │
│  │  │  - scanForRepos │  │      │  │  (state management) │ │  │
│  │  │  - getCommits   │  │      │  └────────┬────────────┘ │  │
│  │  │  - getRepoStats │  │      │           │              │  │
│  │  └────────────────┘  │      │  ┌────────┴────────────┐ │  │
│  │                      │      │  │                      │ │  │
│  │  ┌────────────────┐  │      │  │  Sidebar   Summary   │ │  │
│  │  │  summarizer     │  │      │  │  View      View     │ │  │
│  │  │  - categorize   │  │      │  │                      │ │  │
│  │  │  - generateSum  │  │      │  └──────────────────────┘ │  │
│  │  └────────────────┘  │      │                           │  │
│  └─────────────────────┘      └──────────────────────────┘  │
│                                                              │
│  ┌─────────────────────┐                                     │
│  │   PRELOAD BRIDGE     │                                     │
│  │   (contextBridge)    │                                     │
│  └─────────────────────┘                                     │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
  ┌──────────────┐
  │  File System  │  git repos under ~/Development, etc.
  └──────────────┘
```

## Component Breakdown

### Main Process (`src/main/`)

| Module | Responsibility |
|---|---|
| `main.js` | Window creation, IPC handler registration, theme detection, lifecycle management |
| `git-service.js` | Filesystem walking for `.git` directories, `git log` execution via `execFile`, commit parsing |
| `summarizer.js` | Commit categorization via pattern matching, natural language summary generation |

### Preload (`src/preload/`)

| Module | Responsibility |
|---|---|
| `preload.js` | Exposes safe API surface to renderer via `contextBridge.exposeInMainWorld` |

### Renderer (`src/renderer/`)

| Component | Responsibility |
|---|---|
| `App.jsx` | Root state management, data fetching orchestration, layout |
| `Sidebar.jsx` | Repo selection list, time range picker |
| `SummaryView.jsx` | Main content: overview, stats cards, activity chart, repo summaries, commit list |
| `LoadingState.jsx` | Spinner with contextual message |
| `EmptyState.jsx` | Empty/error state with icon and message |
| `styles.css` | Complete design system with CSS custom properties, light/dark themes |

## Data Flow

```
User selects period/repos
        │
        ▼
App.jsx → IPC invoke 'get-commits'
        │
        ▼
Main process: git-service.getCommits()
  → execFile('git', ['log', ...]) for each repo
  → Parse stdout into commit objects
  → Sort by date, return to renderer
        │
        ▼
App.jsx → IPC invoke 'get-summary'
        │
        ▼
Main process: summarizer.generateSummary()
  → Group commits by repo and day
  → Categorize each commit (feature/fix/refactor/...)
  → Generate per-repo English summaries
  → Generate overview paragraph
  → Return structured summary object
        │
        ▼
SummaryView renders summary with animations
```

## State Management

All state lives in `App.jsx` using React `useState` hooks:

| State | Type | Description |
|---|---|---|
| `theme` | `'light' \| 'dark'` | OS theme, synced via IPC |
| `repos` | `Repo[]` | Discovered repositories |
| `selectedRepos` | `string[]` | Paths of selected repos |
| `period` | `string` | Selected time range (`'1w'`, `'1m'`, etc.) |
| `loading` | `boolean` | Whether commits are being fetched |
| `scanning` | `boolean` | Whether initial repo scan is running |
| `summary` | `Summary \| null` | Generated summary data |
| `commits` | `Commit[]` | Raw commit list |
| `error` | `string \| null` | Error message if any |

## Async Model

- Repo scanning and commit fetching happen in the **main process** (Node.js)
- All git operations use `execFile` (not `exec`) to prevent shell injection
- Multiple repos are scanned in parallel via `Promise.all`
- Each git command has a 10-second timeout
- The renderer remains responsive during all operations

## Error Handling Strategy

- Git command failures per-repo are caught silently (returns empty array)
- IPC handlers wrap all logic in try/catch, returning `{ success, data/error }` objects
- The renderer displays error state with helpful messages
- Missing scan directories are skipped gracefully
- Unreadable directories during walk are skipped

## Extension Points

- **AI Summaries**: Add a Claude API call in `summarizer.js` alongside template generation
- **Custom Scan Paths**: Add a settings store (electron-store) and settings UI panel
- **Author Filtering**: Add `--author` flag to git log args in `git-service.js`
- **Export**: Add an IPC handler that formats summary as markdown/PDF
- **Notifications**: Use Electron's notification API for scheduled weekly summaries
