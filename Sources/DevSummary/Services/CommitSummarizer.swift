import Foundation

struct CommitSummarizer {

    // MARK: - Categorization

    private static let patterns: [(CommitType, [String])] = [
        (.feature, ["feat", "add", "implement", "create", "new", "introduce"]),
        (.fix, ["fix", "bug", "patch", "resolve", "hotfix", "repair"]),
        (.refactor, ["refactor", "restructure", "reorganize", "simplif", "clean", "improve", "enhance", "optimiz", "perf"]),
        (.docs, ["doc", "readme", "comment", "typo", "spell"]),
        (.test, ["test", "spec", "coverage"]),
        (.style, ["style", "format", "lint", "css", "ui", "design", "layout"]),
        (.deps, ["dep", "bump", "upgrad", "updat", "install", "packag"]),
        (.config, ["config", "setup", "env", "build", "ci", "cd", "deploy", "docker"]),
        (.remove, ["remov", "delet", "drop", "deprecat"]),
        (.setup, ["init", "initial", "first", "bootstrap", "scaffold"]),
    ]

    static func categorize(_ subject: String) -> CommitType {
        let lower = subject.lowercased()
        let cleaned = cleanSubject(lower)

        for (type, keywords) in patterns {
            for keyword in keywords {
                if lower.hasPrefix(keyword) || cleaned.hasPrefix(keyword) {
                    return type
                }
            }
        }
        return .other
    }

    static func cleanSubject(_ subject: String) -> String {
        var s = subject
        // Remove conventional commit prefix like "feat(scope):"
        if let range = s.range(of: #"^[\w-]+(\(.*?\))?[!:]?\s*"#, options: .regularExpression) {
            s.removeSubrange(range)
        }
        // Remove emoji prefixes
        if let range = s.range(of: #"^[^\w\s]+\s*"#, options: .regularExpression) {
            s.removeSubrange(range)
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Summary Generation

    static func generateSummary(commits: [GitCommit], period: TimePeriod) -> Summary {
        guard !commits.isEmpty else {
            return Summary(
                overview: "No commits found for \(period.descriptionText).",
                repoSummaries: [],
                dailyActivity: [],
                totalCommits: 0,
                activeRepos: 0,
                activeDays: 0
            )
        }

        let byRepo = Dictionary(grouping: commits) { $0.repo }
        let calendar = Calendar.current
        let byDay = Dictionary(grouping: commits) { calendar.startOfDay(for: $0.date) }

        let repoSummaries = byRepo.map { repo, repoCommits -> RepoSummary in
            let types = Dictionary(grouping: repoCommits) { categorize($0.subject) }
                .mapValues { $0.count }
            let lines = generateRepoLines(repoCommits: repoCommits, types: types)
            return RepoSummary(
                repo: repo,
                commitCount: repoCommits.count,
                summaryLines: lines,
                types: types,
                latestCommit: repoCommits.map(\.date).max() ?? Date()
            )
        }.sorted { $0.commitCount > $1.commitCount }

        let dailyActivity = byDay.map { date, dayCommits -> DailyActivity in
            DailyActivity(
                date: date,
                count: dayCommits.count,
                repos: Array(Set(dayCommits.map(\.repo)))
            )
        }.sorted { $0.date > $1.date }

        let overview = generateOverview(
            commits: commits,
            repoSummaries: repoSummaries,
            period: period,
            dayCount: byDay.count
        )

        return Summary(
            overview: overview,
            repoSummaries: repoSummaries,
            dailyActivity: dailyActivity,
            totalCommits: commits.count,
            activeRepos: byRepo.count,
            activeDays: byDay.count
        )
    }

    private static func generateRepoLines(repoCommits: [GitCommit], types: [CommitType: Int]) -> [String] {
        var lines: [String] = []
        let categorized = Dictionary(grouping: repoCommits) { categorize($0.subject) }

        for type in CommitType.allCases {
            guard let items = categorized[type], !items.isEmpty else { continue }

            if items.count == 1 {
                lines.append("\(type.verb) \(cleanSubject(items[0].subject).lowercased())")
            } else if items.count <= 3 {
                let subjects = items.map { cleanSubject($0.subject).lowercased() }
                let joined = subjects.dropLast().joined(separator: ", ") + " and " + (subjects.last ?? "")
                lines.append("\(type.verb) \(joined)")
            } else {
                let first = items.prefix(2).map { cleanSubject($0.subject).lowercased() }
                lines.append("\(type.verb) \(first.joined(separator: ", ")), and \(items.count - 2) more \(type.label.lowercased()) changes")
            }
        }

        return lines
    }

    private static func generateOverview(commits: [GitCommit], repoSummaries: [RepoSummary], period: TimePeriod, dayCount: Int) -> String {
        let total = commits.count
        let repoCount = repoSummaries.count

        var overview = "Over \(period.descriptionText), you made \(total) commit\(total != 1 ? "s" : "") across \(repoCount) project\(repoCount != 1 ? "s" : ""), active on \(dayCount) day\(dayCount != 1 ? "s" : "")."

        if let topRepo = repoSummaries.first, repoCount > 1 {
            overview += " Your most active project was \(topRepo.repo) with \(topRepo.commitCount) commits."
        }

        let allTypes = Dictionary(grouping: commits) { categorize($0.subject) }
        if let topType = allTypes.max(by: { $0.value.count < $1.value.count })?.key {
            let labels: [CommitType: String] = [
                .feature: "building new features",
                .fix: "fixing bugs",
                .refactor: "improving and refactoring code",
                .docs: "writing documentation",
                .test: "adding tests",
                .style: "working on UI and styling",
                .deps: "updating dependencies",
                .config: "configuring builds and tooling",
                .remove: "cleaning up code",
                .setup: "setting up new projects",
                .other: "various development tasks",
            ]
            overview += " Most of your time was spent \(labels[topType] ?? "coding")."
        }

        return overview
    }
}
