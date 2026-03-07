import SwiftUI

struct SummaryDetailView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @FocusState private var isSearchFocused: Bool
    let summary: Summary
    let commits: [GitCommit]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                headerSection
                overallSummaryCard
                statsRow
                distributionSection
                contributionSection
                activitySection
                projectsSection
                recentCommitsSection
            }
            .padding(36)
            .frame(maxWidth: 880, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $viewModel.selectedCommit) { commit in
            CommitDetailPopover(
                commit: commit,
                commitDetail: viewModel.selectedCommitDetail,
                onRegenerate: { style in
                    Task {
                        await viewModel.regenerateCommitExplanation(style: style)
                    }
                }
            )
            .onAppear {
                Task {
                    await viewModel.loadCommitDetail(for: commit)
                }
            }
        }
        .onChange(of: viewModel.isSearchFocused) { _, newValue in
            isSearchFocused = newValue
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dev Summary")
                    .font(.system(size: 28, weight: .bold))

                Text("Generated \(Date().formatted(.dateTime.weekday(.wide).month(.wide).day().year()))")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            HStack(spacing: 8) {
                if viewModel.ollamaAvailable {
                    Label("Ollama", systemImage: "brain")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.green.opacity(0.1), in: Capsule())
                }

                Button {
                    Task { await viewModel.regenerateAllSummaries() }
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    viewModel.showSettings.toggle()
                } label: {
                    Image(systemName: "gear")
                        .font(.system(size: 13))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Overall AI Summary

    @ViewBuilder
    private var overallSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if summary.isGeneratingOverall {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Generating overall summary with \(viewModel.selectedModel)...")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            } else if let aiSummary = summary.overallAISummary {
                VStack(alignment: .leading, spacing: 8) {
                    Label("AI Summary", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.purple)

                    Text(aiSummary)
                        .font(.system(size: 15))
                        .lineSpacing(5)
                        .foregroundStyle(.primary)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.05), Color.blue.opacity(0.03)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.purple.opacity(0.15), lineWidth: 1)
                )
            } else if !viewModel.ollamaAvailable {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("Ollama is not running. Start it to get AI-powered summaries.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.orange.opacity(0.15), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 16) {
            StatCard(value: summary.totalCommits, label: "Commits", color: .blue)
            StatCard(value: summary.activeRepos, label: "Active Repos", color: .green)
            StatCard(value: summary.activeDays, label: "Active Days", color: .purple)
        }
    }

    // MARK: - Work Distribution Chart

    @ViewBuilder
    private var distributionSection: some View {
        if !commits.isEmpty {
            CommitTypeDistributionChart(
                commits: commits,
                selectedTypes: $viewModel.selectedCommitTypes
            )
        }
    }

    // MARK: - Contribution Calendar

    @ViewBuilder
    private var contributionSection: some View {
        if !commits.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                ContributionCalendar(commits: commits)
                StreakInfoView(commits: commits)
            }
        }
    }

    // MARK: - Activity

    @ViewBuilder
    private var activitySection: some View {
        if !summary.dailyActivity.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Daily Activity")
                    .font(.system(size: 17, weight: .semibold))
                ActivityChart(activity: Array(summary.dailyActivity.prefix(14).reversed()))
            }
        }
    }

    // MARK: - Projects

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Projects")
                    .font(.system(size: 17, weight: .semibold))

                if !viewModel.searchText.isEmpty && viewModel.searchMode != .body {
                    Text("(\(viewModel.filteredProjects.count) matching)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            let projectsToShow = viewModel.searchText.isEmpty || viewModel.searchMode == .body
                ? summary.projectSummaries
                : viewModel.filteredProjects

            if projectsToShow.isEmpty && !viewModel.searchText.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text("No projects match your search")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(projectsToShow) { project in
                    ProjectCard(
                        project: project,
                        onRegenerate: {
                            Task { await viewModel.regenerateProjectSummary(project.repoPath) }
                        },
                        onGenerateWithOptions: { options in
                            Task { await viewModel.regenerateProjectSummaryWithOptions(project.repoPath, options: options) }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Recent Commits

    private var recentCommitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Commits")
                    .font(.system(size: 17, weight: .semibold))

                Spacer()

                // Search bar with mode selector
                HStack(spacing: 8) {
                    // Search mode picker
                    Picker("Search Mode", selection: $viewModel.searchMode) {
                        ForEach(SearchMode.allCases) { mode in
                            Label(mode.label, systemImage: mode.icon)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                    .help("Search mode")

                    // Search field
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)

                        TextField("Search commits...", text: $viewModel.searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .frame(width: 150)
                            .focused($isSearchFocused)

                        if !viewModel.searchText.isEmpty {
                            Button {
                                viewModel.clearSearch()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                            .help("Clear search")
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    )

                    // Sort option picker
                    Picker("Sort", selection: $viewModel.sortOption) {
                        ForEach(CommitSortOption.allCases) { option in
                            Label(option.label, systemImage: option.icon)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                    .help("Sort by")
                }

                // Commit type filter
                if !viewModel.availableCommitTypes.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(CommitType.allCases), id: \.self) { type in
                            if viewModel.availableCommitTypes.contains(type) {
                                CommitTypeFilterChip(
                                    type: type,
                                    isSelected: viewModel.selectedCommitTypes.contains(type)
                                ) {
                                    viewModel.toggleCommitTypeFilter(type)
                                }
                            }
                        }

                        if !viewModel.selectedCommitTypes.isEmpty || !viewModel.searchText.isEmpty {
                            Button {
                                viewModel.clearAllFilters()
                            } label: {
                                Text("Clear")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Clear all filters")
                        }
                    }
                }

                Spacer()

                // Export button with menu
                Menu {
                    Button {
                        viewModel.exportSummaryToClipboard()
                    } label: {
                        Label("Copy to Clipboard", systemImage: "doc.on.clipboard")
                    }

                    Button {
                        viewModel.exportSummaryToFile()
                    } label: {
                        Label("Save to File...", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .font(.system(size: 11, weight: .medium))
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Export summary")
            }

            // Search results info
            if !viewModel.searchText.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                    Text(viewModel.searchResultsInfo)
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
            }

            let filteredCommits = viewModel.filteredCommits

            if filteredCommits.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text("No commits match the selected filters")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(filteredCommits.prefix(50))) { commit in
                        CommitRow(commit: commit) {
                            viewModel.selectCommit(commit)
                        }
                        if commit.id != filteredCommits.prefix(50).last?.id {
                            Divider().padding(.leading, 28)
                        }
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )

                if filteredCommits.count > 50 {
                    Text("Showing 50 of \(filteredCommits.count) commits")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
            }
        }
    }
}

// MARK: - Project Card

struct ProjectCard: View {
    let project: ProjectSummary
    let onRegenerate: () -> Void
    let onGenerateWithOptions: (SummaryOptions) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Image(systemName: "folder.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.blue)

                Text(project.repo)
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                if project.commitCount > 0 {
                    Text("\(project.commitCount) commit\(project.commitCount != 1 ? "s" : "")")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())
                }

                SummaryOptionsButton(project: project, onGenerate: onGenerateWithOptions)

                Button(action: onRegenerate) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Regenerate with default settings")
            }

            // AI Summary
            if project.isGenerating {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Generating summary...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            } else if let aiSummary = project.aiSummary {
                Text(aiSummary)
                    .font(.system(size: 13, weight: .regular))
                    .lineSpacing(3)
                    .foregroundStyle(.primary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            }

            // Type tags
            if !project.types.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(project.types.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { type in
                        if let count = project.types[type] {
                            CommitTypeTag(type: type, count: count)
                        }
                    }
                }
            }

            // Commit summary lines
            if !project.commitLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(project.commitLines, id: \.self) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(.tertiary)
                                .frame(width: 5, height: 5)
                                .padding(.top, 6)
                            Text(line)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }
}

// MARK: - Activity Chart

struct ActivityChart: View {
    let activity: [DailyActivity]

    private var maxCount: Int {
        max(activity.map(\.count).max() ?? 1, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(activity) { day in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.2 + 0.8 * Double(day.count) / Double(maxCount)))
                        .frame(width: 36, height: max(8, CGFloat(day.count) / CGFloat(maxCount) * 80))
                        .help("\(day.count) commits on \(day.date.formatted(.dateTime.month(.abbreviated).day()))")
                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }
}

// MARK: - Commit Type Tag

struct CommitTypeTag: View {
    let type: CommitType
    let count: Int

    private var tagColor: Color {
        switch type {
        case .feature: return .blue
        case .fix: return .red
        case .refactor: return .purple
        case .docs: return .teal
        case .test: return .green
        case .style: return .pink
        case .deps: return .orange
        case .config: return .yellow
        case .remove: return .red
        case .setup: return .green
        case .other: return .gray
        }
    }

    var body: some View {
        Text("\(type.label) (\(count))")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(tagColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(tagColor.opacity(0.12), in: Capsule())
    }
}

// MARK: - Commit Type Filter Chip

struct CommitTypeFilterChip: View {
    let type: CommitType
    let isSelected: Bool
    let onTap: () -> Void

    private var tagColor: Color {
        switch type {
        case .feature: return .blue
        case .fix: return .red
        case .refactor: return .purple
        case .docs: return .teal
        case .test: return .green
        case .style: return .pink
        case .deps: return .orange
        case .config: return .yellow
        case .remove: return .red
        case .setup: return .green
        case .other: return .gray
        }
    }

    var body: some View {
        Button(action: onTap) {
            Text(type.label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isSelected ? .white : tagColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? tagColor : tagColor.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .help("Filter by \(type.label)")
    }
}

// MARK: - Commit Row

struct CommitRow: View {
    let commit: GitCommit
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)
                VStack(alignment: .leading, spacing: 2) {
                    Text(commit.subject)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        Text(commit.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                        Text(commit.date.formatted(.dateTime.hour().minute()))
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Text(commit.repo)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1), in: Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Click to view commit details")
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layoutSubviews(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layoutSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
