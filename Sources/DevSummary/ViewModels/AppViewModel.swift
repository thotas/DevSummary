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

    private let gitService = GitService()

    init() {
        Task {
            await scanRepos()
        }
    }

    func scanRepos() async {
        isScanning = true
        error = nil

        let discovered = await gitService.scanForRepos(in: GitService.defaultScanPaths)
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
        summary = CommitSummarizer.generateSummary(commits: fetched, period: period)
        isLoading = false
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
}
