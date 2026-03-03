# Decisions

## AI Backend: Ollama (Local)
- **Chosen:** Ollama HTTP API at localhost:11434
- **Alternatives considered:** Claude API, OpenAI API, no AI (template-only)
- **Rationale:** User explicitly requested Ollama. Local-first means zero API costs, full privacy, works offline. The HTTP API is simple (POST /api/generate) and model selection is trivial.
- **Tradeoffs:** Requires Ollama installed and running. Quality depends on chosen model.

## Default Model: llama3
- **Chosen:** llama3 as default, user-configurable via Settings
- **Alternatives considered:** gemma3:4b (faster), qwen2.5-coder (code-aware)
- **Rationale:** llama3 is the most common Ollama model, good balance of quality and speed. User can switch to any installed model via the Settings panel.
- **Tradeoffs:** Larger than gemma3 but better summary quality.

## Summary Caching: JSON in Application Support
- **Chosen:** JSON file at `~/Library/Application Support/DevSummary/summary_cache.json`
- **Alternatives considered:** Core Data, SQLite, UserDefaults, in-memory only
- **Rationale:** JSON is simple to inspect, debug, and version. Each cached entry stores the last commit hash — summaries are only regenerated when git changes are detected. No database overhead needed.
- **Tradeoffs:** Slightly slower than SQLite for large caches, but cache size is tiny.

## Cache Invalidation: Commit Hash Comparison
- **Chosen:** Store latest commit hash per repo alongside cached summary. On fetch, compare HEAD hash — if different, regenerate.
- **Alternatives considered:** Time-based expiry, file modification timestamps
- **Rationale:** Commit hash comparison is the most accurate signal of actual changes. No false positives from clock skew or file touches.
- **Tradeoffs:** None significant — this is the correct approach.

## README Reading: Direct File Access
- **Chosen:** Read README.md directly from the repo filesystem
- **Alternatives considered:** GitHub API, git show HEAD:README.md
- **Rationale:** Direct file read is instant, works offline, and handles uncommitted changes. Tries multiple filename variants (README.md, Readme.md, README.txt, etc.).
- **Tradeoffs:** Won't find README if it's not in the repo root. Acceptable.

## Summarization Strategy: Per-Project Then Overall
- **Chosen:** Generate per-project AI summary first (using README + commits), then generate overall summary from project summaries
- **Alternatives considered:** Single monolithic prompt, overall summary only
- **Rationale:** Two-stage approach produces better results. Per-project summaries benefit from README context. Overall summary benefits from already-distilled project summaries. Also enables per-project cache invalidation.
- **Tradeoffs:** More Ollama API calls, but each is small and they're cached.

## Settings Storage: UserDefaults
- **Chosen:** UserDefaults via AppSettings singleton
- **Alternatives considered:** JSON config file, environment variables
- **Rationale:** UserDefaults is the standard macOS pattern for app preferences. Simple, fast, persistent, no file management needed.
- **Tradeoffs:** Not as inspectable as a JSON file, but appropriate for settings.

## App Icon: Custom .icns from User-Provided PNG
- **Chosen:** Convert user-provided PNG to .icns with all required sizes (16-1024px)
- **Alternatives considered:** SF Symbol, no icon
- **Rationale:** User provided a specific app icon image. macOS requires .icns format with multiple resolutions for proper display in Dock, Finder, and Spotlight.
- **Tradeoffs:** None — this is the standard approach.

## Platform: Native macOS with SwiftUI
- **Chosen:** Native macOS app using SwiftUI (carried forward from v1)
- **Rationale:** User explicitly requested native Mac app. No web wrappers.

## Architecture: MVVM with Actor-based Services
- **Chosen:** MVVM with three actor services: GitService, OllamaService, CacheService
- **Rationale:** Clean separation. Each actor is thread-safe. ViewModel orchestrates the three services and manages all UI state.
