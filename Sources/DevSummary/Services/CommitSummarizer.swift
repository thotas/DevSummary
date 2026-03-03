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
        if let range = s.range(of: #"^[\w-]+(\(.*?\))?[!:]?\s*"#, options: .regularExpression) {
            s.removeSubrange(range)
        }
        if let range = s.range(of: #"^[^\w\s]+\s*"#, options: .regularExpression) {
            s.removeSubrange(range)
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Per-Repo Summary Lines

    static func generateRepoLines(repoCommits: [GitCommit]) -> [String] {
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
}
