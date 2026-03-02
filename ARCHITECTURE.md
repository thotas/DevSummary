# Architecture

## System Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                     DevSummary (Native macOS)                     │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                     SwiftUI Views                          │  │
│  │                                                            │  │
│  │  ┌─────────────────┐    ┌────────────────────────────┐     │  │
│  │  │  SidebarView    │    │  SummaryDetailView          │     │  │
│  │  │  • Period Picker│    │  • Overview Card             │     │  │
│  │  │  • Repo List    │    │  • Stats Row (3 cards)       │     │  │
│  │  │  • Select All   │    │  • Activity Chart            │     │  │
│  │  └─────────────────┘    │  • Repo Summary Cards        │     │  │
│  │                         │  • Commit Timeline           │     │  │
│  │                         └────────────────────────────┘     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                          │ @EnvironmentObject                    │
│                          ▼                                       │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                 AppViewModel (@MainActor)                   │  │
│  │  • repos, selectedRepoPaths, period                        │  │
│  │  • commits, summary                                        │  │
│  │  • isScanning, isLoading, error                            │  │
│  │  • fetchSummary(), toggleRepo(), changePeriod()            │  │
│  └──────────────┬──────────────────────┬─────────────────────┘  │
│                  │                      │                         │
│                  ▼                      ▼                         │
│  ┌──────────────────────┐  ┌─────────────────────────────────┐  │
│  │  GitService (actor)   │  │  CommitSummarizer (struct)      │  │
│  │  • scanForRepos()     │  │  • categorize()                 │  │
│  │  • getCommits()       │  │  • generateSummary()            │  │
│  │  • walkForGitRepos()  │  │  • generateOverview()           │  │
│  │  • runGit() → Process │  │  • generateRepoLines()          │  │
│  └──────────┬───────────┘  └─────────────────────────────────┘  │
│              │                                                    │
│              ▼                                                    │
│  ┌──────────────────────┐                                        │
│  │  /usr/bin/git         │  (subprocess per command)              │
│  │  via Foundation.Process│                                       │
│  └──────────────────────┘                                        │
└──────────────────────────────────────────────────────────────────┘
         │
         ▼
  ┌──────────────┐
  │  File System  │  git repos under ~/Development, etc.
  └──────────────┘
```

## Component Breakdown

### Views Layer

| Component | Responsibility |
|---|---|
| `DevSummaryApp` | App entry point, WindowGroup scene, ViewModel creation |
| `ContentView` | NavigationSplitView: routes between sidebar and detail |
| `SidebarView` | Period picker (Picker/menu), repo list with toggles |
| `SummaryDetailView` | ScrollView: overview, stats, activity, repo cards, commit list |
| `LoadingView` | ProgressView with contextual message |
| `EmptyStateView` | SF Symbol icon + message for empty/error states |
| `StatCard` | Individual stat display (value + label) |
| `ActivityChart` | Horizontal bar chart of daily commit counts |
| `RepoSummaryCard` | Per-repo card: name, count badge, type tags, summary bullets |
| `CommitTypeTag` | Colored capsule tag for commit category |
| `CommitRow` | Single commit: dot + subject + date + repo tag |
| `FlowLayout` | Custom Layout protocol for wrapping tag flow |

### ViewModel Layer

| Component | Responsibility |
|---|---|
| `AppViewModel` | @MainActor ObservableObject. Owns all app state. Orchestrates async operations between GitService and CommitSummarizer. Publishes state changes to drive UI updates. |

### Service Layer

| Component | Responsibility |
|---|---|
| `GitService` | Actor. Filesystem walking for `.git` directories. Executes `git log` via Process. Parses git log output into GitCommit objects. Runs repo operations in parallel via TaskGroup. |
| `CommitSummarizer` | Pure struct. Categorizes commits by pattern matching against conventional commit prefixes. Generates per-repo summary lines. Produces overall English overview. |

### Model Layer

| Component | Responsibility |
|---|---|
| `GitRepo` | Repository identity (name + path) |
| `GitCommit` | Single commit data (hash, author, date, subject, body, repo) |
| `CommitType` | Enum of commit categories with labels, verbs, colors |
| `TimePeriod` | Enum of selectable time ranges with day counts |
| `Summary` | Complete summary output (overview, repo summaries, daily activity, stats) |
| `RepoSummary` | Per-repo summary with lines, types, commit count |
| `DailyActivity` | Single day's commit count and active repos |

## Data Flow

```
User selects period or toggles repo
        │
        ▼
AppViewModel.changePeriod() or .toggleRepo()
        │
        ▼
AppViewModel.fetchSummary()  [async, @MainActor]
  → sets isLoading = true
  → calculates `since` date from period.days
        │
        ▼
GitService.getCommits()  [actor-isolated]
  → TaskGroup: parallel fetchCommits() per repo
    → Process: /usr/bin/git log --all --since=... --format=...
    → parseGitLog(): split output by ---END--- delimiter
    → map to [GitCommit]
  → merge and sort all commits by date
        │
        ▼
CommitSummarizer.generateSummary()  [pure function]
  → groupByRepo: Dictionary(grouping:)
  → groupByDay: Dictionary(grouping:)
  → per repo: categorize each commit → generate summary lines
  → generateOverview: natural language paragraph
  → return Summary struct
        │
        ▼
AppViewModel publishes:
  commits = [GitCommit]
  summary = Summary
  isLoading = false
        │
        ▼
SwiftUI re-renders SummaryDetailView with new data
```

## State Management

Single `AppViewModel` as `@StateObject` in the App, passed via `@EnvironmentObject`:

| Property | Type | Description |
|---|---|---|
| `repos` | `[GitRepo]` | All discovered repositories |
| `selectedRepoPaths` | `Set<String>` | Paths of selected repos |
| `period` | `TimePeriod` | Selected time range |
| `commits` | `[GitCommit]` | Fetched commits for current selection |
| `summary` | `Summary?` | Generated summary |
| `isScanning` | `Bool` | Initial repo discovery in progress |
| `isLoading` | `Bool` | Commit fetch/summarization in progress |
| `error` | `String?` | Error message |

## Concurrency Model

- **GitService** is an `actor` — thread-safe by design, no manual locks
- **AppViewModel** is `@MainActor` — all UI state updates happen on main thread
- **TaskGroup** parallelizes git operations across repositories
- **Process** runs git as a subprocess — blocks the calling thread but is called from within actor context
- `runGit()` is marked `nonisolated` since Process is synchronous and doesn't access actor state

## Error Handling Strategy

| Layer | Strategy |
|---|---|
| Process (git) | Catches errors, returns nil on failure |
| GitService | Per-repo failures return empty array, don't block other repos |
| AppViewModel | Sets error string on failure, UI displays EmptyStateView |
| Views | Conditional rendering based on state (loading / error / empty / data) |

No exceptions propagate to the UI. All failures are gracefully handled.

## Extension Points

- **AI Summaries**: Add Claude API call in `CommitSummarizer` alongside template generation
- **Custom Scan Paths**: Add UserDefaults/Settings.bundle and a settings view
- **Author Filtering**: Add `--author` argument to git log in `GitService`
- **Export**: Add menu item that formats Summary as markdown/PDF
- **Menu Bar**: Add MenuBarExtra scene in DevSummaryApp
- **Notifications**: Schedule weekly summary via UserNotifications
