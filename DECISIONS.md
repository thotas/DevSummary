# Decisions

## Platform: Native macOS with SwiftUI
- **Chosen:** Native macOS app using SwiftUI
- **Alternatives considered:** Electron + React, Tauri, AppKit-only
- **Rationale:** SwiftUI provides the most native macOS experience — system materials, vibrancy, native controls, NavigationSplitView, dark mode integration. Zero web overhead. AppKit was considered but SwiftUI's declarative approach is more productive and modern.
- **Tradeoffs:** macOS-only (no Windows/Linux). Acceptable for a developer tool targeting Mac users.

## Build System: Swift Package Manager
- **Chosen:** SPM with executable target
- **Alternatives considered:** Xcode project, CMake, Bazel
- **Rationale:** SPM is the standard Swift build system. No Xcode project file needed — builds from command line with `swift build`. The `.app` bundle is created by a simple shell script wrapping the executable.
- **Tradeoffs:** No Xcode GUI for design iteration. Worth it for simplicity and CLI-first workflow.

## Architecture: MVVM with Actor-based Services
- **Chosen:** MVVM — Views observe a @MainActor ViewModel, which delegates to an actor-isolated GitService
- **Alternatives considered:** MVC, TCA (The Composable Architecture), Redux-style
- **Rationale:** MVVM is the natural pattern for SwiftUI's ObservableObject. The actor model for GitService provides safe concurrency without manual locking. TCA would be overkill for this scope.
- **Tradeoffs:** Less formal than TCA but perfectly adequate for a focused single-window app.

## Concurrency: Swift Concurrency (async/await + actors)
- **Chosen:** GitService as an actor, TaskGroup for parallel repo scanning
- **Alternatives considered:** GCD (DispatchQueue), Combine
- **Rationale:** Swift Concurrency is the modern standard. Actors prevent data races. TaskGroup enables parallel git operations across repos. async/await makes the code readable.
- **Tradeoffs:** Requires Swift 6.0+ with strict concurrency.

## Git Execution: Foundation Process (execFile equivalent)
- **Chosen:** Foundation's Process class with direct executable path `/usr/bin/git`
- **Alternatives considered:** libgit2 binding, shell via /bin/sh, git2-rs FFI
- **Rationale:** Process with executableURL is the safe equivalent of execFile — no shell injection risk. Direct path to git binary avoids shell interpretation. Simple, no dependencies.
- **Tradeoffs:** Spawns a subprocess per git command. Fast enough for this use case.

## Summarization: Template-Based Engine
- **Chosen:** Pattern-matching categorization + template-based natural language generation
- **Alternatives considered:** Claude API integration, local LLM, simple aggregation
- **Rationale:** Works fully offline with zero configuration. No API keys needed. Instant results. AI integration can be added later as optional enhancement.
- **Tradeoffs:** Summaries are less nuanced than AI-generated ones, but accurate and immediate.

## UI Layout: NavigationSplitView
- **Chosen:** NavigationSplitView with sidebar + detail
- **Alternatives considered:** HSplitView, TabView, single-column
- **Rationale:** NavigationSplitView is the standard macOS pattern for sidebar-detail apps (like Finder, Mail). Provides native resize handle, proper sidebar styling, and system materials.
- **Tradeoffs:** None significant — this is the correct pattern for this app type.

## Dependencies: Zero External
- **Chosen:** No third-party dependencies
- **Alternatives considered:** Charts framework, SwiftUI-Flow, etc.
- **Rationale:** Everything needed (layout, charts, materials) is available in SwiftUI natively. Custom FlowLayout handles tag wrapping. Activity chart is simple bars. No dependency means no version conflicts, no supply chain risk, instant builds.
- **Tradeoffs:** Custom FlowLayout implementation required (~30 lines), but trivial.

## Window Style: Unified Toolbar
- **Chosen:** `.windowToolbarStyle(.unified(showsTitle: false))` with `.titleBar` window style
- **Alternatives considered:** Hidden titlebar, plain titlebar, hiddenInset
- **Rationale:** Unified toolbar gives the modern macOS look where the toolbar merges with the titlebar. No title text keeps it clean — the app name appears in the sidebar.
- **Tradeoffs:** None — standard modern macOS convention.
