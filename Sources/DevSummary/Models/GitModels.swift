import Foundation

struct GitRepo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let latestCommitDate: Date?

    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }

    static func == (lhs: GitRepo, rhs: GitRepo) -> Bool {
        lhs.path == rhs.path
    }
}

struct GitCommit: Identifiable, Hashable {
    let id = UUID()
    let hash: String
    let author: String
    let email: String
    let date: Date
    let subject: String
    let body: String
    let repo: String
    let repoPath: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(hash)
    }

    static func == (lhs: GitCommit, rhs: GitCommit) -> Bool {
        lhs.hash == rhs.hash
    }
}

enum CommitType: String, CaseIterable {
    case feature, fix, refactor, docs, test, style, deps, config, remove, setup, other

    var label: String {
        switch self {
        case .feature: return "Features"
        case .fix: return "Fixes"
        case .refactor: return "Improvements"
        case .docs: return "Documentation"
        case .test: return "Testing"
        case .style: return "Styling"
        case .deps: return "Dependencies"
        case .config: return "Configuration"
        case .remove: return "Removals"
        case .setup: return "Project Setup"
        case .other: return "Other"
        }
    }

    var verb: String {
        switch self {
        case .feature: return "Added"
        case .fix: return "Fixed"
        case .refactor: return "Improved"
        case .docs: return "Updated docs for"
        case .test: return "Added tests for"
        case .style: return "Styled"
        case .deps: return "Updated"
        case .config: return "Configured"
        case .remove: return "Removed"
        case .setup: return "Set up"
        case .other: return "Worked on"
        }
    }
}

enum SummaryStyle: String, CaseIterable, Identifiable {
    case concise = "concise"
    case detailed = "detailed"
    case technical = "technical"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .concise: return "Concise"
        case .detailed: return "Detailed"
        case .technical: return "Technical"
        }
    }

    var description: String {
        switch self {
        case .concise: return "Brief 2-3 sentence summaries"
        case .detailed: return "Comprehensive multi-paragraph summaries"
        case .technical: return "Technical focus with implementation details"
        }
    }
}

enum SummaryLength: String, CaseIterable, Identifiable {
    case short = "short"
    case medium = "medium"
    case long = "long"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .short: return "Short"
        case .medium: return "Medium"
        case .long: return "Long"
        }
    }

    var maxTokens: Int {
        switch self {
        case .short: return 150
        case .medium: return 300
        case .long: return 600
        }
    }

    var description: String {
        switch self {
        case .short: return "~150 tokens"
        case .medium: return "~300 tokens"
        case .long: return "~600 tokens"
        }
    }
}

enum TimePeriod: String, CaseIterable, Identifiable {
    case oneDay = "1d"
    case oneWeek = "1w"
    case twoWeeks = "2w"
    case oneMonth = "1m"
    case threeMonths = "3m"
    case sixMonths = "6m"
    case oneYear = "1y"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneDay: return "Past 24 Hours"
        case .oneWeek: return "Past Week"
        case .twoWeeks: return "Past 2 Weeks"
        case .oneMonth: return "Past Month"
        case .threeMonths: return "Past 3 Months"
        case .sixMonths: return "Past 6 Months"
        case .oneYear: return "Past Year"
        }
    }

    var days: Int {
        switch self {
        case .oneDay: return 1
        case .oneWeek: return 7
        case .twoWeeks: return 14
        case .oneMonth: return 30
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .oneYear: return 365
        }
    }

    var descriptionText: String {
        switch self {
        case .oneDay: return "the past 24 hours"
        case .oneWeek: return "this past week"
        case .twoWeeks: return "the past two weeks"
        case .oneMonth: return "this past month"
        case .threeMonths: return "the past three months"
        case .sixMonths: return "the past six months"
        case .oneYear: return "this past year"
        }
    }
}

struct SummaryOptions: Equatable {
    let style: SummaryStyle
    let length: SummaryLength

    static let `default` = SummaryOptions(
        style: AppSettings.shared.summaryStyle,
        length: AppSettings.shared.summaryLength
    )
}

struct ProjectSummary: Identifiable {
    let id = UUID()
    let repo: String
    let repoPath: String
    let commitCount: Int
    let types: [CommitType: Int]
    let latestCommit: Date
    let readme: String?
    let aiSummary: String?
    let isGenerating: Bool
    let commitLines: [String]
    let latestCommitHash: String
    let summaryOptions: SummaryOptions?
}

struct DailyActivity: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
    let repos: [String]
}

struct Summary {
    let overallAISummary: String?
    let isGeneratingOverall: Bool
    let projectSummaries: [ProjectSummary]
    let dailyActivity: [DailyActivity]
    let totalCommits: Int
    let activeRepos: Int
    let activeDays: Int
}
