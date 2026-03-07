import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        List {
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

            Section {
                ForEach(viewModel.repos) { repo in
                    RepoRow(
                        repo: repo,
                        isSelected: viewModel.selectedRepoPaths.contains(repo.path)
                    ) {
                        viewModel.toggleRepo(repo.path)
                    }
                }
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
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .font(.system(size: 16))
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: 1) {
                    Text(repo.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(shortenPath(repo.path))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func shortenPath(_ path: String) -> String {
        path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
    }
}
