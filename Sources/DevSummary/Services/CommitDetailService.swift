import Foundation

actor CommitDetailService {
    private let gitService: GitService
    private let ollamaService: OllamaService
    private var cache: [String: GitCommitDetail] = [:]

    init(gitService: GitService, ollamaService: OllamaService) {
        self.gitService = gitService
        self.ollamaService = ollamaService
    }

    func getCommitDetail(commit: GitCommit, style: SummaryStyle, forceRefresh: Bool = false) async -> GitCommitDetail {
        let cacheKey = "\(commit.hash)-\(style.rawValue)"

        if !forceRefresh, let cached = cache[cacheKey] {
            return cached
        }

        let files = await gitService.getCommitFiles(repoPath: commit.repoPath, hash: commit.hash)
        let diff = await gitService.getCommitDiff(repoPath: commit.repoPath, hash: commit.hash)

        var explanation: String?
        var isGenerating = false

        let isOllamaAvailable = await ollamaService.isAvailable()
        if isOllamaAvailable {
            isGenerating = true
            do {
                explanation = try await ollamaService.summarizeCommit(
                    commit: commit,
                    diff: diff,
                    files: files,
                    style: style
                )
            } catch {
                explanation = "Failed to generate explanation: \(error.localizedDescription)"
            }
            isGenerating = false
        } else {
            explanation = "Ollama is not running. Start it with: ollama serve"
        }

        let detail = GitCommitDetail(
            commit: commit,
            files: files,
            diff: diff,
            aiExplanation: explanation,
            explanationStyle: style,
            isGenerating: isGenerating
        )

        cache[cacheKey] = detail
        return detail
    }

    func regenerateExplanation(commit: GitCommit, style: SummaryStyle) async -> GitCommitDetail {
        let cacheKey = "\(commit.hash)-\(style.rawValue)"
        cache.removeValue(forKey: cacheKey)
        return await getCommitDetail(commit: commit, style: style, forceRefresh: true)
    }

    func clearCache() {
        cache.removeAll()
    }

    func clearCache(for hash: String) {
        cache = cache.filter { !$0.key.hasPrefix(hash) }
    }
}
