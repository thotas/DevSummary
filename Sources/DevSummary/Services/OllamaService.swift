import Foundation

actor OllamaService {
    private let baseURL: URL

    init(host: String = "http://localhost", port: Int = 11434) {
        self.baseURL = URL(string: "\(host):\(port)")!
    }

    struct GenerateRequest: Encodable {
        let model: String
        let prompt: String
        let stream: Bool
        let options: Options?

        struct Options: Encodable {
            let temperature: Double
            let num_predict: Int
        }
    }

    struct GenerateResponse: Decodable {
        let response: String
    }

    struct ModelListResponse: Decodable {
        let models: [ModelInfo]
    }

    struct ModelInfo: Decodable {
        let name: String
    }

    func isAvailable() async -> Bool {
        let url = baseURL.appendingPathComponent("api/tags")
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func listModels() async -> [String] {
        let url = baseURL.appendingPathComponent("api/tags")
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(ModelListResponse.self, from: data)
            return decoded.models.map(\.name)
        } catch {
            return []
        }
    }

    func generate(model: String, prompt: String, maxTokens: Int = 500) async throws -> String {
        let url = baseURL.appendingPathComponent("api/generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180

        let body = GenerateRequest(
            model: model,
            prompt: prompt,
            stream: false,
            options: .init(temperature: 0.3, num_predict: maxTokens)
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw OllamaError.requestFailed(statusCode: statusCode)
        }

        let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
        return decoded.response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func summarizeProject(name: String, readme: String?, commits: [GitCommit], period: TimePeriod, options: SummaryOptions? = nil) async throws -> String {
        let style = options?.style ?? AppSettings.shared.summaryStyle
        let length = options?.length ?? AppSettings.shared.summaryLength

        var context = "Project: \(name)\n\n"

        if let readme = readme, !readme.isEmpty {
            let truncated = String(readme.prefix(2000))
            context += "README:\n\(truncated)\n\n"
        }

        if !commits.isEmpty {
            let commitLimit = style == .detailed ? 50 : (style == .technical ? 40 : 30)
            context += "Recent commits (\(commits.count) total in \(period.descriptionText)):\n"
            for commit in commits.prefix(commitLimit) {
                context += "- \(commit.subject)\n"
            }
            if commits.count > commitLimit {
                context += "- ... and \(commits.count - commitLimit) more commits\n"
            }
        }

        let prompt = buildProjectPrompt(style: style, context: context)

        return try await generate(model: AppSettings.shared.ollamaModel, prompt: prompt, maxTokens: length.maxTokens)
    }

    private func buildProjectPrompt(style: SummaryStyle, context: String) -> String {
        switch style {
        case .concise:
            return """
            You are a developer summarizer. Based on the project info below, write a concise 2-3 sentence summary in plain English.

            First sentence: What the project is and what it does.
            Second sentence: What was worked on recently (based on commits).
            Third sentence (optional): Notable technical details if interesting.

            Be specific and informative. No bullet points. No markdown. Just plain flowing text.

            \(context)

            Summary:
            """
        case .detailed:
            return """
            You are a developer summarizer. Based on the project info below, write a comprehensive multi-paragraph summary in plain English.

            Cover these aspects:
            1. What the project is and its main purpose
            2. What was worked on recently in detail
            3. Any significant changes, new features, or bug fixes
            4. Technical approach or architecture notes if evident
            5. Overall development trends

            Be thorough and detailed. No bullet points. No markdown. Just flowing paragraphs.

            \(context)

            Summary:
            """
        case .technical:
            return """
            You are a senior developer writing a technical summary. Based on the project info below, write a technically-focused summary.

            Focus on:
            1. Implementation details and technical stack
            2. Code changes - what was modified, added, or removed
            3. Architecture or design patterns if evident
            4. Dependencies or configuration changes
            5. Technical decisions and their rationale

            Use appropriate technical terminology. Be specific about file changes, API modifications, or implementation approaches. No bullet points. No markdown. Just flowing technical text.

            \(context)

            Technical Summary:
            """
        }
    }

    func summarizeAllProjects(projectSummaries: [(name: String, summary: String, commitCount: Int)], period: TimePeriod, options: SummaryOptions? = nil) async throws -> String {
        let style = options?.style ?? AppSettings.shared.summaryStyle
        let length = options?.length ?? AppSettings.shared.summaryLength

        var context = "Development activity \(period.descriptionText):\n\n"
        for p in projectSummaries {
            context += "- \(p.name) (\(p.commitCount) commits): \(p.summary)\n"
        }

        let prompt = buildOverallPrompt(style: style, context: context)

        let maxTokens = min(length.maxTokens * 2, 1000)
        return try await generate(model: AppSettings.shared.ollamaModel, prompt: prompt, maxTokens: maxTokens)
    }

    func summarizeCommit(commit: GitCommit, diff: String?, files: [FileChange], style: SummaryStyle) async throws -> String {
        var context = "Commit Information:\n"
        context += "Hash: \(commit.hash)\n"
        context += "Author: \(commit.author) <\(commit.email)>\n"
        context += "Date: \(formatDate(commit.date))\n"
        context += "Subject: \(commit.subject)\n"

        if !commit.body.isEmpty {
            context += "\nCommit Message:\n\(commit.body)\n"
        }

        if !files.isEmpty {
            context += "\nFiles Changed (\(files.count)):\n"
            for file in files {
                let statusIcon: String
                switch file.status {
                case .added: statusIcon = "+"
                case .deleted: statusIcon = "-"
                case .modified: statusIcon = "M"
                case .renamed: statusIcon = "R"
                case .copied: statusIcon = "C"
                case .untracked: statusIcon = "?"
                }
                context += "  \(statusIcon) \(file.path) (+\(file.additions)/-\(file.deletions))\n"
            }
        }

        if let diff = diff, !diff.isEmpty {
            let truncatedDiff = String(diff.prefix(8000))
            context += "\nDiff:\n\(truncatedDiff)\n"
            if diff.count > 8000 {
                context += "(diff truncated due to length)\n"
            }
        }

        let prompt = buildCommitPrompt(style: style, context: context)
        let maxTokens: Int
        switch style {
        case .concise:
            maxTokens = 200
        case .detailed:
            maxTokens = 400
        case .technical:
            maxTokens = 500
        }

        return try await generate(model: AppSettings.shared.ollamaModel, prompt: prompt, maxTokens: maxTokens)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func buildCommitPrompt(style: SummaryStyle, context: String) -> String {
        switch style {
        case .concise:
            return """
            You are a code reviewer explaining a git commit in plain English. Based on the commit info below, provide a brief 2-3 sentence explanation of what this commit does and why it matters.

            First sentence: What changed overall.
            Second sentence: Why this change was made or what problem it solves.
            Third sentence (optional): Any notable technical details.

            Be specific and avoid generic phrases. No bullet points. No markdown.

            \(context)

            Explanation:
            """
        case .detailed:
            return """
            You are a senior code reviewer providing a comprehensive explanation of a git commit. Based on the commit info below, explain in detail:

            1. What exactly changed in this commit
            2. Why this change was made - the problem or need it addresses
            3. How it was implemented - the approach taken
            4. Any potential impact or side effects
            5. Code quality observations if evident

            Be thorough and technical but accessible. No bullet points. No markdown. Use flowing paragraphs.

            \(context)

            Detailed Explanation:
            """
        case .technical:
            return """
            You are a principal engineer providing a technical analysis of a git commit. Based on the commit info below, provide a deep technical analysis covering:

            1. Exact code changes - what was added, modified, or removed
            2. Technical implementation details and approach
            3. Files affected and their roles in the codebase
            4. Any architectural or design pattern implications
            5. Dependencies or integration points affected
            6. Potential performance, security, or maintainability implications
            7. Code quality assessment

            Use precise technical terminology. Reference specific files, functions, or APIs when evident. No bullet points. No markdown. Use flowing technical prose.

            \(context)

            Technical Analysis:
            """
        }
    }

    private func buildOverallPrompt(style: SummaryStyle, context: String) -> String {
        switch style {
        case .concise:
            return """
            You are a developer summarizer. Based on the project summaries below, write a comprehensive summary paragraph covering ALL projects listed. The summary should be detailed enough that every single project is mentioned by name with what was done on it. It's okay for this to be a longer paragraph (5-10 sentences) — completeness is more important than brevity. Be specific about each project name and what was worked on. No bullet points. No markdown. Just flowing text.

            \(context)

            Overall summary:
            """
        case .detailed:
            return """
            You are a development team lead writing a comprehensive status report. Based on the project summaries below, write an detailed report covering ALL projects.

            Your report should include:
            1. An executive overview of all development activity
            2. Each project mentioned by name with specific work done
            3. Patterns or trends across multiple projects
            4. Any significant milestones or achievements
            5. Overall health and progress of the codebase

            Be very thorough - every project must be mentioned. This can be multiple paragraphs. No bullet points. No markdown. Just flowing text.

            \(context)

            Detailed Report:
            """
        case .technical:
            return """
            You are a senior architect reviewing development activity. Based on the project summaries below, write a technical status report.

            Focus on:
            1. Technical changes across all projects
            2. Architecture and design patterns in use
            3. Dependencies updated or changed
            4. Integration points between projects
            5. Technical debt or concerns identified

            Use technical terminology. Be specific about implementations, APIs, and technical decisions. Every project must be covered. No bullet points. No markdown. Just flowing technical text.

            \(context)

            Technical Report:
            """
        }
    }
}

enum OllamaError: LocalizedError {
    case requestFailed(statusCode: Int)
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .requestFailed(let code): return "Ollama request failed (HTTP \(code))"
        case .notAvailable: return "Ollama is not running. Start it with: ollama serve"
        }
    }
}
