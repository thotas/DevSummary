import SwiftUI
import AppKit

struct SidebarView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        List {
            // Quick Actions Toolbar
            Section {
                QuickActionsToolbar()
            } header: {
                Text("Quick Actions")
            }

            // Presets Section
            Section {
                if !viewModel.presets.isEmpty {
                    ForEach(Array(viewModel.presets.enumerated()), id: \.element.id) { index, preset in
                        PresetRow(preset: preset, index: index) {
                            viewModel.applyPreset(preset)
                        } onDelete: {
                            viewModel.deletePreset(preset)
                        }
                    }
                }

                Button {
                    viewModel.showSavePresetSheet = true
                } label: {
                    Label("Save Current View...", systemImage: "plus.circle")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .disabled(viewModel.selectedRepoPaths.isEmpty)
            } header: {
                Text("Quick Presets")
            }

            Section {
                Picker("Time Range", selection: Binding(
                    get: { viewModel.period },
                    set: { viewModel.changePeriod($0) }
                )) {
                    ForEach(TimePeriod.allCases) { period in
                        Text(period.label).tag(period)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Time Range")
            }

            // Favorites Section
            if !viewModel.sortedFavoriteRepos.isEmpty {
                Section {
                    ForEach(viewModel.sortedFavoriteRepos) { repo in
                        RepoRow(
                            repo: repo,
                            isSelected: viewModel.selectedRepoPaths.contains(repo.path),
                            isFavorite: true
                        ) {
                            viewModel.toggleRepo(repo.path)
                        } onToggleFavorite: {
                            viewModel.toggleFavorite(repo.path)
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.system(size: 10))
                        Text("Favorites")
                        Spacer()
                        Text("\(viewModel.sortedFavoriteRepos.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // All Repositories Section
            Section {
                ForEach(viewModel.sortedNonFavoriteRepos) { repo in
                    RepoRow(
                        repo: repo,
                        isSelected: viewModel.selectedRepoPaths.contains(repo.path),
                        isFavorite: false
                    ) {
                        viewModel.toggleRepo(repo.path)
                    } onToggleFavorite: {
                        viewModel.toggleFavorite(repo.path)
                    }
                }

                // Sort picker at bottom of repos section
                HStack {
                    Text("Sort by:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: Binding(
                        get: { viewModel.repoSortOption },
                        set: { viewModel.setRepoSortOption($0) }
                    )) {
                        ForEach(RepoSortOption.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .padding(.top, 4)
            } header: {
                HStack {
                    Text("Repositories (\(viewModel.selectedRepoPaths.count)/\(viewModel.repos.count))")
                    Spacer()
                    if viewModel.selectedRepoPaths.count == viewModel.repos.count {
                        Button("None") { viewModel.deselectAll() }
                            .font(.caption)
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.accentColor)
                    } else {
                        Button("All") { viewModel.selectAll() }
                            .font(.caption)
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("DevSummary")
        .overlay {
            if viewModel.isScanning {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Scanning for repos...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial)
            }
        }
        .sheet(isPresented: $viewModel.showSavePresetSheet) {
            SavePresetSheet()
        }
    }
}

struct PresetRow: View {
    let preset: ViewPreset
    let index: Int
    let onApply: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onApply) {
            HStack(spacing: 8) {
                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(preset.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                    Text("\(preset.repoPaths.count) repos · \(preset.period.label)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if isHovering {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .help("Press Cmd+\(index + 1) to quick switch")
    }
}

struct SavePresetSheet: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var presetName = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Save Current View as Preset")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Preset Name")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("e.g., Daily Standup, Weekly Review", text: $presetName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Configuration")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("\(viewModel.selectedRepoPaths.count) repositories")
                    Text("·")
                    Text(viewModel.period.label)
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Save") {
                    viewModel.saveCurrentAsPreset(name: presetName)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}

struct RepoRow: View {
    let repo: GitRepo
    let isSelected: Bool
    let isFavorite: Bool
    let onToggle: () -> Void
    let onToggleFavorite: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .font(.system(size: 16))
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(repo.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)

                        // Health indicator badge
                        if let date = repo.latestCommitDate {
                            HealthBadge(date: date)
                        }
                    }
                    Text(shortenPath(repo.path))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()

                // Favorite star button
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 12))
                        .foregroundStyle(isFavorite ? Color.yellow : Color.secondary)
                }
                .buttonStyle(.plain)
                .opacity(isHovering || isFavorite ? 1 : 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            Button {
                onToggleFavorite()
            } label: {
                Label(isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: isFavorite ? "star.slash" : "star")
            }

            Divider()

            Button {
                openInFinder(repo.path)
            } label: {
                Label("Open in Finder", systemImage: "folder")
            }

            Button {
                openInTerminal(repo.path)
            } label: {
                Label("Open in Terminal", systemImage: "terminal")
            }

            Button {
                openInVSCode(repo.path)
            } label: {
                Label("Open in VS Code", systemImage: "chevron.left.forwardslash.chevron.right")
            }

            Divider()

            Button {
                copyPathToClipboard(repo.path)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }

            Button {
                copyNameToClipboard(repo.name)
            } label: {
                Label("Copy Repo Name", systemImage: "textformat")
            }

            Divider()

            Button {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: repo.path)
            } label: {
                Label("Reveal in Finder", systemImage: "arrow.right.circle")
            }
        }
    }

    private func shortenPath(_ path: String) -> String {
        path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
    }
}

// MARK: - Health Badge

struct HealthBadge: View {
    let date: Date
    private let calendar = Calendar.current

    private var daysSinceCommit: Int {
        calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
    }

    private var healthStatus: (color: Color, label: String) {
        switch daysSinceCommit {
        case 0:
            return (.green, "Today")
        case 1:
            return (.green, "Yesterday")
        case 2...3:
            return (.mint, "Recent")
        case 4...7:
            return (.yellow, "This week")
        case 8...14:
            return (.orange, "Stale")
        default:
            return (.red, "Old")
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(healthStatus.color)
                .frame(width: 6, height: 6)
            Text(healthStatus.label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(healthStatus.color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(healthStatus.color.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Quick Actions Toolbar

struct QuickActionsToolbar: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 8) {
            ToolbarButton(
                icon: "arrow.clockwise",
                label: "Refresh",
                action: {
                    Task {
                        // Force a full rescan to find new repos
                        await viewModel.scanRepos()
                    }
                }
            )
            .disabled(viewModel.isScanning)

            ToolbarButton(
                icon: "doc.on.clipboard",
                label: "Copy All",
                action: copyAllPaths
            )
            .disabled(viewModel.selectedRepoPaths.isEmpty)

            ToolbarButton(
                icon: "square.and.arrow.up",
                label: "Export",
                action: { viewModel.exportSummaryToClipboard() }
            )
            .disabled(viewModel.selectedRepoPaths.isEmpty)
        }
    }

    private func copyAllPaths() {
        let paths = viewModel.selectedRepoPaths.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(paths, forType: .string)
    }
}

struct ToolbarButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 9))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isHovering ? Color.accentColor.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isHovering ? Color.accentColor : Color.secondary)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Context Menu Actions

private func openInFinder(_ path: String) {
    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
}

private func openInTerminal(_ path: String) {
    let script = """
    tell application "Terminal"
        activate
        do script "cd '\(path)'"
    end tell
    """
    if let appleScript = NSAppleScript(source: script) {
        var error: NSDictionary?
        appleScript.executeAndReturnError(&error)
    }
}

private func openInVSCode(_ path: String) {
    let script = """
    tell application "Visual Studio Code"
        activate
        open "\(path)"
    end tell
    """
    if let appleScript = NSAppleScript(source: script) {
        var error: NSDictionary?
        appleScript.executeAndReturnError(&error)
    }
}

private func copyPathToClipboard(_ path: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(path, forType: .string)
}

private func copyNameToClipboard(_ name: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(name, forType: .string)
}
