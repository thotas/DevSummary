# Decisions

## Platform: Electron Desktop App
- **Chosen:** Electron
- **Alternatives considered:** SwiftUI native macOS app, Tauri, local web app
- **Rationale:** Electron provides real desktop integration (titlebar, dark mode, vibrancy) with React's fast UI development. SwiftUI would be more native but dramatically slower to build from CLI. Tauri wasn't installed. A local web app wouldn't feel like a real app.
- **Tradeoffs:** Larger binary size (~150MB) vs native. Acceptable for a developer tool.

## Frontend: React 19 + Vite
- **Chosen:** React 19 with Vite bundler
- **Alternatives considered:** Svelte, vanilla JS, Vue
- **Rationale:** React has the richest ecosystem for animations (Framer Motion) and component patterns. Vite provides sub-second HMR and fast builds.
- **Tradeoffs:** Slightly heavier than Svelte but much more library support.

## Summarization: Template-Based Engine
- **Chosen:** Template-based commit categorization and natural language generation
- **Alternatives considered:** Claude API integration, local LLM, simple aggregation
- **Rationale:** Works fully offline with zero configuration. No API keys needed. Instant results. AI integration can be added later as an optional enhancement.
- **Tradeoffs:** Summaries are less nuanced than AI-generated ones, but they're accurate and immediate.

## Commit Categorization: Pattern Matching
- **Chosen:** Regex-based pattern matching against conventional commit prefixes and common keywords
- **Alternatives considered:** ML classifier, keyword frequency analysis
- **Rationale:** Conventional commits are widespread enough that pattern matching catches 80%+ of cases. The "other" category handles the rest gracefully.
- **Tradeoffs:** Won't perfectly categorize unconventional commit messages.

## Repo Discovery: Filesystem Walk
- **Chosen:** Recursive directory walk with depth limit (4 levels) from configurable root paths
- **Alternatives considered:** User-specified repo list, global gitconfig parsing
- **Rationale:** Auto-discovery is the zero-config experience. Most developers keep repos under a few root directories.
- **Tradeoffs:** Initial scan takes a moment. Doesn't find repos in unexpected locations.

## Architecture: Process Separation
- **Chosen:** Electron main/renderer process split with IPC bridge
- **Alternatives considered:** Single process, worker threads
- **Rationale:** Standard Electron architecture. Git operations run in the main process without blocking the UI. Context isolation ensures security.
- **Tradeoffs:** IPC adds slight complexity vs direct function calls.

## Styling: CSS Custom Properties (Design Tokens)
- **Chosen:** CSS custom properties with light/dark theme variants
- **Alternatives considered:** Tailwind CSS, CSS-in-JS, styled-components
- **Rationale:** Zero additional dependencies. Full control over the design system. Native CSS performance. Custom properties make theming trivial.
- **Tradeoffs:** More manual than utility-first CSS but results in cleaner, more intentional styling.

## Window Style: Hidden Inset Titlebar
- **Chosen:** `titleBarStyle: 'hiddenInset'` with traffic light repositioning
- **Alternatives considered:** Default titlebar, fully frameless
- **Rationale:** Matches modern macOS app conventions (like Finder, Notes). The content flows up into the titlebar area for a premium feel while keeping native window controls.
- **Tradeoffs:** macOS-specific. Other platforms get a standard titlebar.
