import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class AppViewModel: ObservableObject {
    @Published var repos: [GitRepo] = []
    @Published var selectedRepoPaths: Set<String> = []
    @Published var period: TimePeriod = .oneWeek
    @Published var commits: [GitCommit] = []
    @Published var summary: Summary?
    @Published var isScanning = true
    @Published var isLoading = false
    @Published var error: String?
    @Published var ollamaAvailable = false
    @Published var availableModels: [String] = []
    @Published var selectedModel: String = AppSettings.shared.ollamaModel
    @Published var showSettings = false
    @Published var selectedCommitTypes: Set<CommitType> = []
    @Published var searchText = ""
    @Published var searchMode: SearchMode = .all
    @Published var sortOption: CommitSortOption = .date
    @Published var selectedCommit: GitCommit?
    @Published var isSearchFocused = false
    @Published var presets: [ViewPreset] = []
    @Published var showSavePresetSheet = false
    @Published var newPresetName = ""

    // Commit detail for inspector
    @Published var selectedCommitDetail: GitCommitDetail?
    @Published var isLoadingCommitDetail = false

    // Filtered commits based on selected commit types and search text
    var filteredCommits: [GitCommit] {
        var result = commits

        // Filter by commit type
        if !selectedCommitTypes.isEmpty {
            result = result.filter { selectedCommitTypes.contains(CommitSummarizer.categorize($0.subject)) }
        }

        // Filter by search text with different modes
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            switch searchMode {
            case .all:
                // Search in subject, repo, and body
                result = result.filter {
                    $0.subject.lowercased().contains(query) ||
                    $0.repo.lowercased().contains(query) ||
                    $0.body.lowercased().contains(query)
                }
            case .subject:
                result = result.filter { $0.subject.lowercased().contains(query) }
            case .repo:
                result = result.filter { $0.repo.lowercased().contains(query) }
            case .body:
                result = result.filter { $0.body.lowercased().contains(query) }
            }
        }

        // Apply sorting
        switch sortOption {
        case .date:
            result.sort { $0.date > $1.date }
        case .repo:
            result.sort { $0.repo.lowercased() < $1.repo.lowercased() }
        case .relevance:
            // For relevance, prioritize subject matches, then body, then repo
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                result.sort { c1, c2 in
                    let c1Subject = c1.subject.lowercased().contains(query)
                    let c1Body = c1.body.lowercased().contains(query)
                    let c2Subject = c2.subject.lowercased().contains(query)
                    let c2Body = c2.body.lowercased().contains(query)

                    if c1Subject && !c2Subject { return true }
                    if !c1Subject && c2Subject { return false }
                    if c1Body && !c2Body { return true }
                    if !c1Body && c2Body { return false }
                    return c1.date > c2.date
                }
            }
        }

        return result
    }

    // Filtered projects based on search
    var filteredProjects: [ProjectSummary] {
        guard let summary = summary else { return [] }
        var result = summary.projectSummaries

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            switch searchMode {
            case .all:
                result = result.filter { project in
                    project.repo.lowercased().contains(query) ||
                    (project.aiSummary?.lowercased().contains(query) ?? false) ||
                    (project.readme?.lowercased().contains(query) ?? false)
                }
            case .subject, .body:
                result = result.filter { project in
                    project.repo.lowercased().contains(query) ||
                    (project.aiSummary?.lowercased().contains(query) ?? false)
                }
            case .repo:
                result = result.filter { $0.repo.lowercased().contains(query) }
            }
        }

        return result
    }

    // Check if any projects match the search
    var hasMatchingProjects: Bool {
        !filteredProjects.isEmpty
    }

    // Combined search results showing what's matched
    var searchResultsInfo: String {
        let commitCount = filteredCommits.count
        let projectCount = filteredProjects.count

        if searchText.isEmpty {
            return ""
        }

        var parts: [String] = []
        if commitCount > 0 {
            parts.append("\(commitCount) commit\(commitCount != 1 ? "s" : "")")
        }
        if projectCount > 0 {
            parts.append("\(projectCount) project\(projectCount != 1 ? "s" : "")")
        }

        return parts.isEmpty ? "No results" : parts.joined(separator: ", ")
    }

    // All commit types present in current commits
    var availableCommitTypes: Set<CommitType> {
        var types: Set<CommitType> = []
        for commit in commits {
            types.insert(CommitSummarizer.categorize(commit.subject))
        }
        return types
    }

    private let gitService = GitService()
    private let ollamaService = OllamaService()
    private let cacheService = CacheService()
    private let commitDetailService: CommitDetailService

    // Track per-project generation state
    private var generatingProjects: Set<String> = []
    private var isGeneratingOverall = false

    init() {
        self.commitDetailService = CommitDetailService(gitService: gitService, ollamaService: ollamaService)
        loadPresets()
        Task {
            async let repoScan: Void = scanRepos()
            async let ollamaCheck: Void = checkOllama()
            _ = await (repoScan, ollamaCheck)
        }
    }

    func checkOllama() async {
        ollamaAvailable = await ollamaService.isAvailable()
        if ollamaAvailable {
            availableModels = await ollamaService.listModels()
        }
    }

    func scanRepos() async {
        isScanning = true
        error = nil

        let discovered = await gitService.scanForRepos(in: AppSettings.shared.scanPaths)
        repos = discovered
        selectedRepoPaths = Set(discovered.map(\.path))
        isScanning = false

        await fetchSummary()
    }

    func fetchSummary() async {
        guard !selectedRepoPaths.isEmpty else {
            commits = []
            summary = nil
            isLoading = false
            return
        }

        isLoading = true
        error = nil

        let since = Calendar.current.date(byAdding: .day, value: -period.days, to: Date()) ?? Date()
        let fetched = await gitService.getCommits(repoPaths: Array(selectedRepoPaths), since: since)
        commits = fetched

        // Build project summaries with cached AI text
        let byRepo = Dictionary(grouping: fetched) { $0.repoPath }
        var projectSummaries: [ProjectSummary] = []

        for repoPath in selectedRepoPaths {
            let repoCommits = byRepo[repoPath] ?? []
            let repoName = URL(fileURLWithPath: repoPath).lastPathComponent
            let readme = await gitService.readReadme(repoPath: repoPath)
            let latestHash = await gitService.getLatestCommitHash(repoPath: repoPath) ?? ""
            let types = Dictionary(grouping: repoCommits) { CommitSummarizer.categorize($0.subject) }.mapValues(\.count)
            let commitLines = CommitSummarizer.generateRepoLines(repoCommits: repoCommits)

            // Check cache
            let cachedSummary = await cacheService.getCachedProjectSummary(
                repoPath: repoPath, latestCommitHash: latestHash, period: period.rawValue
            )

            projectSummaries.append(ProjectSummary(
                repo: repoName,
                repoPath: repoPath,
                commitCount: repoCommits.count,
                types: types,
                latestCommit: repoCommits.first?.date ?? Date(),
                readme: readme,
                aiSummary: cachedSummary?.summary,
                isGenerating: false,
                commitLines: commitLines,
                latestCommitHash: latestHash,
                summaryOptions: nil
            ))
        }

        projectSummaries.sort { $0.latestCommit > $1.latestCommit }

        // Check overall cache
        let projectHashes = Dictionary(uniqueKeysWithValues: projectSummaries.map { ($0.repoPath, $0.latestCommitHash) })
        let cachedOverall = await cacheService.getCachedOverallSummary(
            projectHashes: projectHashes, period: period.rawValue
        )

        let calendar = Calendar.current
        let byDay = Dictionary(grouping: fetched) { calendar.startOfDay(for: $0.date) }
        let dailyActivity = byDay.map { date, dayCommits in
            DailyActivity(date: date, count: dayCommits.count, repos: Array(Set(dayCommits.map(\.repo))))
        }.sorted { $0.date > $1.date }

        summary = Summary(
            overallAISummary: cachedOverall?.summary,
            isGeneratingOverall: false,
            projectSummaries: projectSummaries,
            dailyActivity: dailyActivity,
            totalCommits: fetched.count,
            activeRepos: Set(fetched.map(\.repoPath)).count,
            activeDays: byDay.count
        )

        isLoading = false

        // Auto-generate AI summaries for projects that need them
        if ollamaAvailable {
            await generateMissingSummaries()
        }
    }

    private func generateMissingSummaries() async {
        guard var currentSummary = summary else { return }

        for (index, project) in currentSummary.projectSummaries.enumerated() {
            guard project.aiSummary == nil, !project.commitLines.isEmpty || project.readme != nil else { continue }
            guard !generatingProjects.contains(project.repoPath) else { continue }

            generatingProjects.insert(project.repoPath)

            // Mark as generating
            var updated = currentSummary.projectSummaries[index]
            updated = ProjectSummary(
                repo: updated.repo, repoPath: updated.repoPath, commitCount: updated.commitCount,
                types: updated.types, latestCommit: updated.latestCommit, readme: updated.readme,
                aiSummary: nil, isGenerating: true, commitLines: updated.commitLines,
                latestCommitHash: updated.latestCommitHash, summaryOptions: nil
            )
            currentSummary = replaceProject(in: currentSummary, at: index, with: updated)
            summary = currentSummary

            // Generate
            let repoCommits = commits.filter { $0.repoPath == project.repoPath }
            do {
                let aiText = try await ollamaService.summarizeProject(
                    name: project.repo, readme: project.readme,
                    commits: repoCommits, period: period
                )

                await cacheService.cacheProjectSummary(
                    repoPath: project.repoPath, summary: aiText, readme: project.readme,
                    lastCommitHash: project.latestCommitHash, commitCount: project.commitCount,
                    period: period.rawValue
                )

                if var s = summary, let idx = s.projectSummaries.firstIndex(where: { $0.repoPath == project.repoPath }) {
                    let p = s.projectSummaries[idx]
                    let done = ProjectSummary(
                        repo: p.repo, repoPath: p.repoPath, commitCount: p.commitCount,
                        types: p.types, latestCommit: p.latestCommit, readme: p.readme,
                        aiSummary: aiText, isGenerating: false, commitLines: p.commitLines,
                        latestCommitHash: p.latestCommitHash, summaryOptions: nil
                    )
                    s = replaceProject(in: s, at: idx, with: done)
                    summary = s
                    currentSummary = s
                }
            } catch {
                if var s = summary, let idx = s.projectSummaries.firstIndex(where: { $0.repoPath == project.repoPath }) {
                    let p = s.projectSummaries[idx]
                    let done = ProjectSummary(
                        repo: p.repo, repoPath: p.repoPath, commitCount: p.commitCount,
                        types: p.types, latestCommit: p.latestCommit, readme: p.readme,
                        aiSummary: nil, isGenerating: false, commitLines: p.commitLines,
                        latestCommitHash: p.latestCommitHash, summaryOptions: nil
                    )
                    s = replaceProject(in: s, at: idx, with: done)
                    summary = s
                    currentSummary = s
                }
            }

            generatingProjects.remove(project.repoPath)
        }

        // Generate overall summary
        await generateOverallSummary()
    }

    private func generateOverallSummary() async {
        guard let currentSummary = summary, currentSummary.overallAISummary == nil else { return }
        guard !isGeneratingOverall else { return }

        let projectsWithSummaries = currentSummary.projectSummaries.filter { $0.aiSummary != nil }
        guard !projectsWithSummaries.isEmpty else { return }

        isGeneratingOverall = true
        summary = Summary(
            overallAISummary: nil, isGeneratingOverall: true,
            projectSummaries: currentSummary.projectSummaries,
            dailyActivity: currentSummary.dailyActivity,
            totalCommits: currentSummary.totalCommits,
            activeRepos: currentSummary.activeRepos,
            activeDays: currentSummary.activeDays
        )

        do {
            let inputs = projectsWithSummaries.map {
                (name: $0.repo, summary: $0.aiSummary ?? "", commitCount: $0.commitCount)
            }
            let overallText = try await ollamaService.summarizeAllProjects(
                projectSummaries: inputs, period: period
            )

            let projectHashes = Dictionary(uniqueKeysWithValues: currentSummary.projectSummaries.map { ($0.repoPath, $0.latestCommitHash) })
            await cacheService.cacheOverallSummary(
                summary: overallText, projectHashes: projectHashes, period: period.rawValue
            )

            if let s = summary {
                summary = Summary(
                    overallAISummary: overallText, isGeneratingOverall: false,
                    projectSummaries: s.projectSummaries, dailyActivity: s.dailyActivity,
                    totalCommits: s.totalCommits, activeRepos: s.activeRepos, activeDays: s.activeDays
                )
            }
        } catch {
            if let s = summary {
                summary = Summary(
                    overallAISummary: nil, isGeneratingOverall: false,
                    projectSummaries: s.projectSummaries, dailyActivity: s.dailyActivity,
                    totalCommits: s.totalCommits, activeRepos: s.activeRepos, activeDays: s.activeDays
                )
            }
        }

        isGeneratingOverall = false
    }

    func regenerateAllSummaries() async {
        await cacheService.invalidateAll()
        await fetchSummary()
    }

    func regenerateProjectSummary(_ repoPath: String) async {
        await cacheService.invalidateProject(repoPath)
        await fetchSummary()
    }

    func regenerateProjectSummaryWithOptions(_ repoPath: String, options: SummaryOptions) async {
        await cacheService.invalidateProject(repoPath)

        guard var currentSummary = summary,
              let index = currentSummary.projectSummaries.firstIndex(where: { $0.repoPath == repoPath }) else {
            await fetchSummary()
            return
        }

        let project = currentSummary.projectSummaries[index]

        // Mark as generating with options
        let updated = ProjectSummary(
            repo: project.repo, repoPath: project.repoPath, commitCount: project.commitCount,
            types: project.types, latestCommit: project.latestCommit, readme: project.readme,
            aiSummary: nil, isGenerating: true, commitLines: project.commitLines,
            latestCommitHash: project.latestCommitHash, summaryOptions: options
        )
        currentSummary = replaceProject(in: currentSummary, at: index, with: updated)
        summary = currentSummary

        // Generate with custom options
        let repoCommits = commits.filter { $0.repoPath == repoPath }
        do {
            let aiText = try await ollamaService.summarizeProject(
                name: project.repo, readme: project.readme,
                commits: repoCommits, period: period, options: options
            )

            await cacheService.cacheProjectSummary(
                repoPath: project.repoPath, summary: aiText, readme: project.readme,
                lastCommitHash: project.latestCommitHash, commitCount: project.commitCount,
                period: period.rawValue
            )

            if var s = summary, let idx = s.projectSummaries.firstIndex(where: { $0.repoPath == repoPath }) {
                let p = s.projectSummaries[idx]
                let done = ProjectSummary(
                    repo: p.repo, repoPath: p.repoPath, commitCount: p.commitCount,
                    types: p.types, latestCommit: p.latestCommit, readme: p.readme,
                    aiSummary: aiText, isGenerating: false, commitLines: p.commitLines,
                    latestCommitHash: p.latestCommitHash, summaryOptions: options
                )
                s = replaceProject(in: s, at: idx, with: done)
                summary = s
            }
        } catch {
            if var s = summary, let idx = s.projectSummaries.firstIndex(where: { $0.repoPath == repoPath }) {
                let p = s.projectSummaries[idx]
                let done = ProjectSummary(
                    repo: p.repo, repoPath: p.repoPath, commitCount: p.commitCount,
                    types: p.types, latestCommit: p.latestCommit, readme: p.readme,
                    aiSummary: nil, isGenerating: false, commitLines: p.commitLines,
                    latestCommitHash: p.latestCommitHash, summaryOptions: options
                )
                s = replaceProject(in: s, at: idx, with: done)
                summary = s
            }
        }
    }

    func toggleRepo(_ path: String) {
        if selectedRepoPaths.contains(path) {
            selectedRepoPaths.remove(path)
        } else {
            selectedRepoPaths.insert(path)
        }
        Task { await fetchSummary() }
    }

    func selectAll() {
        selectedRepoPaths = Set(repos.map(\.path))
        Task { await fetchSummary() }
    }

    func deselectAll() {
        selectedRepoPaths.removeAll()
        commits = []
        summary = nil
    }

    func changePeriod(_ newPeriod: TimePeriod) {
        period = newPeriod
        Task { await fetchSummary() }
    }

    func toggleCommitTypeFilter(_ type: CommitType) {
        if selectedCommitTypes.contains(type) {
            selectedCommitTypes.remove(type)
        } else {
            selectedCommitTypes.insert(type)
        }
    }

    func clearCommitTypeFilters() {
        selectedCommitTypes.removeAll()
    }

    func clearSearch() {
        searchText = ""
        isSearchFocused = false
    }

    func setSearchMode(_ mode: SearchMode) {
        searchMode = mode
    }

    func setSortOption(_ option: CommitSortOption) {
        sortOption = option
    }

    func clearAllFilters() {
        searchText = ""
        selectedCommitTypes.removeAll()
    }

    func toggleSearchFocus() {
        isSearchFocused.toggle()
    }

    func selectCommit(_ commit: GitCommit?) {
        selectedCommit = commit
    }

    func loadCommitDetail(for commit: GitCommit, style: SummaryStyle = .concise) async {
        isLoadingCommitDetail = true
        selectedCommitDetail = nil

        let detail = await commitDetailService.getCommitDetail(commit: commit, style: style)
        selectedCommitDetail = detail
        isLoadingCommitDetail = false
    }

    func regenerateCommitExplanation(style: SummaryStyle) async {
        guard let commit = selectedCommit else { return }

        isLoadingCommitDetail = true

        let detail = await commitDetailService.regenerateExplanation(commit: commit, style: style)
        selectedCommitDetail = detail
        isLoadingCommitDetail = false
    }

    func exportSummaryToClipboard() {
        guard let summary = summary else { return }

        let markdown = generateMarkdown(from: summary)

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
    }

    func exportSummaryToFile() {
        guard let summary = summary else { return }

        let markdown = generateMarkdown(from: summary)

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.plainText]
        savePanel.nameFieldStringValue = "DevSummary-\(Date().formatted(.dateTime.month().day().year())).md"
        savePanel.title = "Export Summary"
        savePanel.message = "Choose a location to save the summary"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try markdown.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    self.error = "Failed to save file: \(error.localizedDescription)"
                }
            }
        }
    }

    private func generateMarkdown(from summary: Summary) -> String {
        var markdown = "# Dev Summary\n\n"
        markdown += "Generated \(Date().formatted(.dateTime.weekday(.wide).month(.wide).day().year()))\n\n"

        if let overallSummary = summary.overallAISummary {
            markdown += "## AI Summary\n\n\(overallSummary)\n\n"
        }

        markdown += "## Stats\n\n"
        markdown += "- **Total Commits:** \(summary.totalCommits)\n"
        markdown += "- **Active Repos:** \(summary.activeRepos)\n"
        markdown += "- **Active Days:** \(summary.activeDays)\n\n"

        markdown += "## Daily Activity\n\n"
        for day in summary.dailyActivity.prefix(7) {
            markdown += "- \(day.date.formatted(.dateTime.month(.abbreviated).day())): \(day.count) commits\n"
        }
        markdown += "\n"

        markdown += "## Projects\n\n"
        for project in summary.projectSummaries {
            markdown += "### \(project.repo)\n"
            if let aiSummary = project.aiSummary {
                markdown += "\(aiSummary)\n"
            }
            markdown += "- \(project.commitCount) commits\n"
            if !project.types.isEmpty {
                markdown += "- Types: \(project.types.map { "\($0.key.rawValue): \($0.value)" }.joined(separator: ", "))\n"
            }
            markdown += "\n"
        }

        return markdown
    }

    func updateModel(_ model: String) {
        selectedModel = model
        AppSettings.shared.ollamaModel = model
    }

    private func replaceProject(in summary: Summary, at index: Int, with project: ProjectSummary) -> Summary {
        var projects = summary.projectSummaries
        projects[index] = project
        return Summary(
            overallAISummary: summary.overallAISummary,
            isGeneratingOverall: summary.isGeneratingOverall,
            projectSummaries: projects,
            dailyActivity: summary.dailyActivity,
            totalCommits: summary.totalCommits,
            activeRepos: summary.activeRepos,
            activeDays: summary.activeDays
        )
    }

    // MARK: - Presets

    func loadPresets() {
        presets = AppSettings.shared.presets
    }

    func saveCurrentAsPreset(name: String) {
        let preset = ViewPreset(
            name: name,
            repoPaths: selectedRepoPaths,
            period: period
        )
        AppSettings.shared.addPreset(preset)
        loadPresets()
    }

    func applyPreset(_ preset: ViewPreset) {
        selectedRepoPaths = preset.repoPathsSet
        period = preset.period
        AppSettings.shared.lastUsedPresetId = preset.id
        Task { await fetchSummary() }
    }

    func deletePreset(_ preset: ViewPreset) {
        AppSettings.shared.removePreset(id: preset.id)
        loadPresets()
    }

    func quickSwitchToPreset(index: Int) {
        guard index >= 0 && index < presets.count else { return }
        applyPreset(presets[index])
    }

    // MARK: - Favorites

    var favoriteRepos: Set<String> {
        AppSettings.shared.favoriteRepos
    }

    func isFavorite(_ repoPath: String) -> Bool {
        AppSettings.shared.isFavorite(repoPath)
    }

    func toggleFavorite(_ repoPath: String) {
        AppSettings.shared.toggleFavorite(repoPath)
        objectWillChange.send()
    }

    var favoriteReposList: [GitRepo] {
        repos.filter { favoriteRepos.contains($0.path) }
    }

    var nonFavoriteRepos: [GitRepo] {
        repos.filter { !favoriteRepos.contains($0.path) }
    }
}
