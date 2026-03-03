# Architecture

## System Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                    DevSummary v2 (Native macOS)                   │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                      SwiftUI Views                         │  │
│  │  ┌─────────────┐  ┌────────────────────────────────────┐  │  │
│  │  │ SidebarView  │  │ SummaryDetailView                  │  │  │
│  │  │ • Period     │  │ • AI Overall Summary (purple card) │  │  │
│  │  │ • Repo List  │  │ • Stats Row (3 cards)              │  │  │
│  │  │              │  │ • Activity Chart                   │  │  │
│  │  └─────────────┘  │ • Project Cards (AI + commits)     │  │  │
│  │                    │ • Commit Timeline                  │  │  │
│  │  SettingsView      └────────────────────────────────────┘  │  │
│  │  • Model picker                                            │  │
│  └────────────────────────────────────────────────────────────┘  │
│                          │ @EnvironmentObject                    │
│                          ▼                                       │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │              AppViewModel (@MainActor)                      │  │
│  │  Orchestrates: fetchSummary → cache check → Ollama gen     │  │
│  └─────┬──────────────────┬──────────────────┬───────────────┘  │
│        │                  │                  │                   │
│        ▼                  ▼                  ▼                   │
│  ┌───────────┐   ┌──────────────┐   ┌──────────────┐           │
│  │GitService │   │OllamaService │   │ CacheService │           │
│  │(actor)    │   │(actor)       │   │ (actor)      │           │
│  │• scanRepos│   │• generate()  │   │• getCached() │           │
│  │• getCommit│   │• summarize   │   │• cache()     │           │
│  │• readReadm│   │  Project()   │   │• invalidate()│           │
│  │• getLatest│   │• summarize   │   │              │           │
│  │  CommitHsh│   │  AllProjects│   │              │           │
│  └─────┬─────┘   └──────┬──────┘   └──────┬──────┘           │
│        ▼                 ▼                  ▼                   │
│  /usr/bin/git    localhost:11434    ~/Library/AppSupport/       │
│                   (Ollama API)     DevSummary/cache.json        │
│                                                                  │
│  ┌────────────┐  ┌────────────────┐                             │
│  │AppSettings │  │CommitSummarizer│                             │
│  │(singleton) │  │(pure struct)   │                             │
│  │UserDefaults│  │categorize()    │                             │
│  └────────────┘  │repoLines()    │                             │
│                  └────────────────┘                             │
└──────────────────────────────────────────────────────────────────┘
```

## Data Flow: Full Cycle

```
User opens app or changes period/repos
        │
        ▼
AppViewModel.fetchSummary()
  ├─► GitService.getCommits() — parallel per repo via TaskGroup
  ├─► GitService.readReadme() — reads README.md for each repo
  ├─► GitService.getLatestCommitHash() — HEAD hash per repo
  │
  ├─► For each repo:
  │     CacheService.getCachedProjectSummary(repoPath, latestHash, period)
  │     ├─► Cache HIT: use cached AI summary
  │     └─► Cache MISS: mark as "needs generation"
  │
  └─► Build Summary struct with cached summaries + placeholders
        │
        ▼  (if Ollama is available)
generateMissingSummaries()
  ├─► For each uncached project:
  │     OllamaService.summarizeProject(name, readme, commits, period)
  │     └─► CacheService.cacheProjectSummary(...)
  │     └─► Update UI incrementally (each card fills in as it completes)
  │
  └─► generateOverallSummary()
        OllamaService.summarizeAllProjects(projectSummaries)
        └─► CacheService.cacheOverallSummary(...)
        └─► Update UI with overall paragraph
```

## Cache Invalidation Logic

```
For each repo:
  1. Get current HEAD commit hash
  2. Look up cache entry for (repoPath, period)
  3. If cache.lastCommitHash == currentHash AND cache.period == currentPeriod:
       → Use cached summary (skip Ollama call)
  4. Else:
       → Generate new summary via Ollama
       → Store with current hash

Overall summary:
  1. Build map of {repoPath: latestCommitHash} for all selected repos
  2. Compare with cached overall summary's projectHashes
  3. If all match: use cached
  4. Else: regenerate from project summaries
```

## State Management

Single `AppViewModel` as `@StateObject`:

| Property | Type | Description |
|---|---|---|
| `repos` | `[GitRepo]` | Discovered repositories |
| `selectedRepoPaths` | `Set<String>` | Selected repos |
| `period` | `TimePeriod` | Time range |
| `commits` | `[GitCommit]` | All commits for current selection |
| `summary` | `Summary?` | Full summary with AI text |
| `isScanning` | `Bool` | Initial repo scan |
| `isLoading` | `Bool` | Commit fetch in progress |
| `ollamaAvailable` | `Bool` | Ollama connectivity |
| `availableModels` | `[String]` | Ollama model list |
| `selectedModel` | `String` | Current Ollama model |
| `showSettings` | `Bool` | Settings sheet |

## Storage Schema

### summary_cache.json
```json
{
  "projects": {
    "/path/to/repo": {
      "summary": "AI-generated text...",
      "readme": "First 3000 chars of README...",
      "lastCommitHash": "abc123...",
      "commitCount": 12,
      "generatedAt": "2026-03-02T...",
      "period": "1w"
    }
  },
  "overallSummary": {
    "summary": "Overall AI text...",
    "projectHashes": { "/path/to/repo": "abc123..." },
    "generatedAt": "2026-03-02T...",
    "period": "1w"
  }
}
```

## Concurrency Model

- **GitService**: actor — safe parallel git operations via TaskGroup
- **OllamaService**: actor — HTTP requests to Ollama API
- **CacheService**: actor — thread-safe JSON read/write
- **AppViewModel**: @MainActor — all UI updates on main thread
- AI summaries generate incrementally — each project card updates as its summary completes

## Error Handling

| Layer | Strategy |
|---|---|
| Git commands | Per-repo failures return empty, don't block others |
| Ollama API | Connection failures caught; UI shows "Ollama not running" |
| Ollama generation | Per-project failures leave aiSummary as nil |
| Cache | Read failures start fresh; write failures silently skip |
| Views | Conditional rendering based on state |

## Extension Points

- **Additional AI providers**: Add new service conforming to a summarization protocol
- **Custom scan paths UI**: Add picker in SettingsView, save to AppSettings
- **Author filtering**: Add `--author` to git log args
- **Export**: Format Summary as markdown/PDF
- **Menu bar**: Add MenuBarExtra scene
- **Notifications**: Scheduled weekly summary via UserNotifications
