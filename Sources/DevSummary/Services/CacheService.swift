import Foundation

actor CacheService {
    private let cacheDir: URL
    private var cache: SummaryCache

    struct SummaryCache: Codable {
        var projects: [String: CachedProjectSummary]
        var overallSummary: CachedOverallSummary?
    }

    struct CachedProjectSummary: Codable {
        let summary: String
        let readme: String?
        let lastCommitHash: String
        let commitCount: Int
        let generatedAt: Date
        let period: String
    }

    struct CachedOverallSummary: Codable {
        let summary: String
        let projectHashes: [String: String]
        let generatedAt: Date
        let period: String
    }

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDir = appSupport.appendingPathComponent("DevSummary", isDirectory: true)

        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let cacheFile = cacheDir.appendingPathComponent("summary_cache.json")
        if let data = try? Data(contentsOf: cacheFile),
           let decoded = try? JSONDecoder().decode(SummaryCache.self, from: data) {
            cache = decoded
        } else {
            cache = SummaryCache(projects: [:], overallSummary: nil)
        }
    }

    func getCachedProjectSummary(repoPath: String, latestCommitHash: String, period: String) -> CachedProjectSummary? {
        guard let cached = cache.projects[repoPath] else { return nil }
        guard cached.lastCommitHash == latestCommitHash && cached.period == period else { return nil }
        return cached
    }

    func cacheProjectSummary(repoPath: String, summary: String, readme: String?, lastCommitHash: String, commitCount: Int, period: String) {
        cache.projects[repoPath] = CachedProjectSummary(
            summary: summary,
            readme: readme,
            lastCommitHash: lastCommitHash,
            commitCount: commitCount,
            generatedAt: Date(),
            period: period
        )
        save()
    }

    func getCachedOverallSummary(projectHashes: [String: String], period: String) -> CachedOverallSummary? {
        guard let cached = cache.overallSummary else { return nil }
        guard cached.period == period && cached.projectHashes == projectHashes else { return nil }
        return cached
    }

    func cacheOverallSummary(summary: String, projectHashes: [String: String], period: String) {
        cache.overallSummary = CachedOverallSummary(
            summary: summary,
            projectHashes: projectHashes,
            generatedAt: Date(),
            period: period
        )
        save()
    }

    func invalidateProject(_ repoPath: String) {
        cache.projects.removeValue(forKey: repoPath)
        cache.overallSummary = nil
        save()
    }

    func invalidateAll() {
        cache = SummaryCache(projects: [:], overallSummary: nil)
        save()
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(cache) else { return }
        let cacheFile = cacheDir.appendingPathComponent("summary_cache.json")
        try? data.write(to: cacheFile, options: .atomic)
    }
}
