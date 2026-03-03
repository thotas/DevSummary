import Foundation

final class AppSettings: @unchecked Sendable {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let ollamaModel = "ollamaModel"
        static let ollamaHost = "ollamaHost"
        static let ollamaPort = "ollamaPort"
        static let scanPaths = "scanPaths"
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
