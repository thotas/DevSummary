import Foundation

actor GitService {
    private let maxDepth = 4
    private let skipDirs: Set<String> = ["node_modules", "vendor", ".build", "Pods", "DerivedData", "Build"]

    func scanForRepos(in scanPaths: [String]) async -> [GitRepo] {
        var repos: [GitRepo] = []
        var seen = Set<String>()

        for scanPath in scanPaths {
            let url = URL(fileURLWithPath: scanPath)
            guard FileManager.default.fileExists(atPath: scanPath) else { continue }
            await walkForGitRepos(directory: url, depth: 0, repos: &repos, seen: &seen)
        }

        return repos.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func walkForGitRepos(directory: URL, depth: Int, repos: inout [GitRepo], seen: inout Set<String>) async {
        guard depth <= maxDepth else { return }

        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        // Check for .git in this directory
        let gitDir = directory.appendingPathComponent(".git")
        if fm.fileExists(atPath: gitDir.path) {
            let repoPath = directory.path
            if !seen.contains(repoPath) {
                seen.insert(repoPath)
                let name = directory.lastPathComponent
                repos.append(GitRepo(name: name, path: repoPath))
            }
            return
        }

        for entry in entries {
            guard let isDir = try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDir else { continue }
            let name = entry.lastPathComponent
            if skipDirs.contains(name) { continue }

            await walkForGitRepos(directory: entry, depth: depth + 1, repos: &repos, seen: &seen)
        }
    }

    func getCommits(repoPaths: [String], since: Date) async -> [GitCommit] {
        let formatter = ISO8601DateFormatter()
        let sinceStr = formatter.string(from: since)
        let format = "%H%n%an%n%ae%n%aI%n%s%n%b%n---END---"

        return await withTaskGroup(of: [GitCommit].self) { group in
            for repoPath in repoPaths {
                group.addTask {
                    await self.fetchCommits(repoPath: repoPath, since: sinceStr, format: format)
                }
            }

            var allCommits: [GitCommit] = []
            for await commits in group {
                allCommits.append(contentsOf: commits)
            }
            return allCommits.sorted { $0.date > $1.date }
        }
    }

    private func fetchCommits(repoPath: String, since: String, format: String) async -> [GitCommit] {
        let args = ["log", "--all", "--since=\(since)", "--format=\(format)"]
        guard let output = runGit(args: args, in: repoPath) else { return [] }

        let repoName = URL(fileURLWithPath: repoPath).lastPathComponent
        return parseGitLog(output: output, repoName: repoName, repoPath: repoPath)
    }

    private func parseGitLog(output: String, repoName: String, repoPath: String) -> [GitCommit] {
        let entries = output.components(separatedBy: "---END---\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        var commits: [GitCommit] = []
        for entry in entries {
            let lines = entry.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
            guard lines.count >= 5 else { continue }

            let hash = lines[0].trimmingCharacters(in: .whitespaces)
            let author = lines[1].trimmingCharacters(in: .whitespaces)
            let email = lines[2].trimmingCharacters(in: .whitespaces)
            let dateStr = lines[3].trimmingCharacters(in: .whitespaces)
            let subject = lines[4].trimmingCharacters(in: .whitespaces)
            let body = lines.count > 5 ? lines[5...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) : ""

            guard let date = dateFormatter.date(from: dateStr) else { continue }

            commits.append(GitCommit(
                hash: hash,
                author: author,
                email: email,
                date: date,
                subject: subject,
                body: body,
                repo: repoName,
                repoPath: repoPath
            ))
        }
        return commits
    }

    private nonisolated func runGit(args: [String], in directory: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: directory)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    static var defaultScanPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Development",
            "\(home)/Projects",
            "\(home)/Code",
            "\(home)/repos",
            "\(home)/src",
        ]
    }
}
