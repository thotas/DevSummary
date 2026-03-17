import Foundation

final class AppSettings: @unchecked Sendable {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let ollamaModel = "ollamaModel"
        static let ollamaHost = "ollamaHost"
        static let ollamaPort = "ollamaPort"
        static let scanPaths = "scanPaths"
        static let summaryStyle = "summaryStyle"
        static let summaryLength = "summaryLength"
        static let presets = "viewPresets"
        static let lastUsedPresetId = "lastUsedPresetId"
        static let favoriteRepos = "favoriteRepos"
        static let commitFavorites = "commitFavorites"
        static let commitNotes = "commitNotes"
        static let repoSortOption = "repoSortOption"
    }

    var ollamaModel: String {
        get { defaults.string(forKey: Keys.ollamaModel) ?? "llama3" }
        set { defaults.set(newValue, forKey: Keys.ollamaModel) }
    }

    var ollamaHost: String {
        get { defaults.string(forKey: Keys.ollamaHost) ?? "http://localhost" }
        set { defaults.set(newValue, forKey: Keys.ollamaHost) }
    }

    var ollamaPort: Int {
        get {
            let val = defaults.integer(forKey: Keys.ollamaPort)
            return val > 0 ? val : 11434
        }
        set { defaults.set(newValue, forKey: Keys.ollamaPort) }
    }

    var scanPaths: [String] {
        get {
            if let paths = defaults.stringArray(forKey: Keys.scanPaths), !paths.isEmpty {
                return paths
            }
            return Self.defaultScanPaths
        }
        set { defaults.set(newValue, forKey: Keys.scanPaths) }
    }

    var summaryStyle: SummaryStyle {
        get {
            guard let raw = defaults.string(forKey: Keys.summaryStyle),
                  let style = SummaryStyle(rawValue: raw) else {
                return .concise
            }
            return style
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.summaryStyle) }
    }

    var summaryLength: SummaryLength {
        get {
            guard let raw = defaults.string(forKey: Keys.summaryLength),
                  let length = SummaryLength(rawValue: raw) else {
                return .medium
            }
            return length
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.summaryLength) }
    }

    var presets: [ViewPreset] {
        get {
            guard let data = defaults.data(forKey: Keys.presets),
                  let decoded = try? JSONDecoder().decode([ViewPreset].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                defaults.set(encoded, forKey: Keys.presets)
            }
        }
    }

    var lastUsedPresetId: UUID? {
        get {
            guard let raw = defaults.string(forKey: Keys.lastUsedPresetId) else { return nil }
            return UUID(uuidString: raw)
        }
        set { defaults.set(newValue?.uuidString, forKey: Keys.lastUsedPresetId) }
    }

    var repoSortOption: RepoSortOption {
        get {
            guard let raw = defaults.string(forKey: Keys.repoSortOption),
                  let option = RepoSortOption(rawValue: raw) else {
                return .lastCommit
            }
            return option
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.repoSortOption) }
    }

    var favoriteRepos: Set<String> {
        get {
            guard let paths = defaults.stringArray(forKey: Keys.favoriteRepos) else { return [] }
            return Set(paths)
        }
        set { defaults.set(Array(newValue), forKey: Keys.favoriteRepos) }
    }

    func isFavorite(_ repoPath: String) -> Bool {
        favoriteRepos.contains(repoPath)
    }

    func toggleFavorite(_ repoPath: String) {
        var favorites = favoriteRepos
        if favorites.contains(repoPath) {
            favorites.remove(repoPath)
        } else {
            favorites.insert(repoPath)
        }
        favoriteRepos = favorites
    }

    // MARK: - Commit Favorites

    var commitFavorites: [CommitFavorite] {
        get {
            guard let data = defaults.data(forKey: Keys.commitFavorites),
                  let decoded = try? JSONDecoder().decode([CommitFavorite].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                defaults.set(encoded, forKey: Keys.commitFavorites)
            }
        }
    }

    func isCommitFavorite(hash: String, repoPath: String) -> Bool {
        commitFavorites.contains { $0.commitHash == hash && $0.repoPath == repoPath }
    }

    func toggleCommitFavorite(hash: String, repoPath: String) {
        var favorites = commitFavorites
        if let index = favorites.firstIndex(where: { $0.commitHash == hash && $0.repoPath == repoPath }) {
            favorites.remove(at: index)
        } else {
            favorites.append(CommitFavorite(commitHash: hash, repoPath: repoPath, favoritedAt: Date()))
        }
        commitFavorites = favorites
    }

    // MARK: - Commit Notes

    var commitNotes: [String: CommitNote] {
        get {
            guard let data = defaults.data(forKey: Keys.commitNotes),
                  let decoded = try? JSONDecoder().decode([String: CommitNote].self, from: data) else {
                return [:]
            }
            return decoded
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                defaults.set(encoded, forKey: Keys.commitNotes)
            }
        }
    }

    func getCommitNote(hash: String, repoPath: String) -> CommitNote? {
        let key = hash + ":" + repoPath
        return commitNotes[key]
    }

    func saveCommitNote(hash: String, repoPath: String, note: String) {
        var notes = commitNotes
        let key = hash + ":" + repoPath
        if note.isEmpty {
            notes.removeValue(forKey: key)
        } else {
            if let existing = notes[key] {
                notes[key] = CommitNote(id: existing.id, note: note, createdAt: existing.createdAt, updatedAt: Date())
            } else {
                notes[key] = CommitNote(note: note)
            }
        }
        commitNotes = notes
    }

    func deleteCommitNote(hash: String, repoPath: String) {
        var notes = commitNotes
        let key = hash + ":" + repoPath
        notes.removeValue(forKey: key)
        commitNotes = notes
    }

    func addPreset(_ preset: ViewPreset) {
        var current = presets
        current.append(preset)
        presets = current
    }

    func removePreset(id: UUID) {
        var current = presets
        current.removeAll { $0.id == id }
        presets = current
    }

    func updatePreset(_ preset: ViewPreset) {
        var current = presets
        if let index = current.firstIndex(where: { $0.id == preset.id }) {
            current[index] = preset
            presets = current
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

    private init() {}
}
