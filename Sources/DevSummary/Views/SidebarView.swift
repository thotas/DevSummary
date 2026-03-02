import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        List {
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
