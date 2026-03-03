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

    func summarizeProject(name: String, readme: String?, commits: [GitCommit], period: TimePeriod) async throws -> String {
        var context = "Project: \(name)\n\n"

        if let readme = readme, !readme.isEmpty {
            let truncated = String(readme.prefix(2000))
            context += "README:\n\(truncated)\n\n"
        }

        if !commits.isEmpty {
            context += "Recent commits (\(commits.count) total in \(period.descriptionText)):\n"
            for commit in commits.prefix(30) {
                context += "- \(commit.subject)\n"
            }
            if commits.count > 30 {
                context += "- ... and \(commits.count - 30) more commits\n"
            }
        }

        let prompt = """
        You are a developer summarizer. Based on the project info below, write a concise 2-3 sentence summary in plain English.

        First sentence: What the project is and what it does.
        Second sentence: What was worked on recently (based on commits).
        Third sentence (optional): Notable technical details if interesting.

        Be specific and informative. No bullet points. No markdown. Just plain flowing text.

        \(context)

        Summary:
        """

        return try await generate(model: AppSettings.shared.ollamaModel, prompt: prompt, maxTokens: 300)
    }

    func summarizeAllProjects(projectSummaries: [(name: String, summary: String, commitCount: Int)], period: TimePeriod) async throws -> String {
        var context = "Development activity \(period.descriptionText):\n\n"
        for p in projectSummaries {
            context += "- \(p.name) (\(p.commitCount) commits): \(p.summary)\n"
        }

        let prompt = """
        You are a developer summarizer. Based on the project summaries below, write a comprehensive summary paragraph covering ALL projects listed. The summary should be detailed enough that every single project is mentioned by name with what was done on it. It's okay for this to be a longer paragraph (5-10 sentences) — completeness is more important than brevity. Be specific about each project name and what was worked on. No bullet points. No markdown. Just flowing text.

        \(context)

        Overall summary:
        """

        return try await generate(model: AppSettings.shared.ollamaModel, prompt: prompt, maxTokens: 800)
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
