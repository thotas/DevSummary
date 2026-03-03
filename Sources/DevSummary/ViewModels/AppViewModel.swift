import SwiftUI

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

    private let gitService = GitService()
    private let ollamaService = OllamaService()
    private let cacheService = CacheService()

    // Track per-project generation state
    private var generatingProjects: Set<String> = []
    private var isGeneratingOverall = false

    init() {
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
                latestCommitHash: latestHash
            ))
        }

        projectSummaries.sort { $0.commitCount > $1.commitCount }

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
                latestCommitHash: updated.latestCommitHash
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
                        latestCommitHash: p.latestCommitHash
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
                        latestCommitHash: p.latestCommitHash
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
}
