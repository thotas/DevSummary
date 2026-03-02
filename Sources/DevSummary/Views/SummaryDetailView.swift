import SwiftUI

struct SummaryDetailView: View {
    let summary: Summary
    let commits: [GitCommit]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                overviewCard
                statsRow
                activitySection
                repoSummariesSection
                recentCommitsSection
            }
            .padding(32)
            .frame(maxWidth: 860, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your Dev Summary")
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundStyle(.primary)

            Text("Generated \(Date().formatted(.dateTime.weekday(.wide).month(.wide).day().year()))")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Overview Card

    private var overviewCard: some View {
        Text(summary.overview)
            .font(.system(size: 15, weight: .regular))
            .lineSpacing(4)
            .foregroundStyle(.primary)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 16) {
            StatCard(value: summary.totalCommits, label: "Commits", color: .blue)
            StatCard(value: summary.activeRepos, label: "Active Repos", color: .green)
            StatCard(value: summary.activeDays, label: "Active Days", color: .purple)
        }
    }

    // MARK: - Activity Chart

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

    // MARK: - Repo Summaries

    private var repoSummariesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Project")
                .font(.system(size: 17, weight: .semibold))

            ForEach(summary.repoSummaries) { repo in
                RepoSummaryCard(repo: repo)
            }
        }
    }

    // MARK: - Recent Commits

    private var recentCommitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Commits")
                .font(.system(size: 17, weight: .semibold))

            VStack(spacing: 0) {
                ForEach(Array(commits.prefix(50))) { commit in
                    CommitRow(commit: commit)
                    if commit.id != commits.prefix(50).last?.id {
                        Divider()
                            .padding(.leading, 28)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
        }
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

// MARK: - Repo Summary Card

struct RepoSummaryCard: View {
    let repo: RepoSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(repo.repo)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(repo.commitCount) commit\(repo.commitCount != 1 ? "s" : "")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }

            // Type tags
            FlowLayout(spacing: 6) {
                ForEach(Array(repo.types.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { type in
                    if let count = repo.types[type] {
                        CommitTypeTag(type: type, count: count)
                    }
                }
            }

            // Summary lines
            VStack(alignment: .leading, spacing: 4) {
                ForEach(repo.summaryLines, id: \.self) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(.tertiary)
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(line)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
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

// MARK: - Commit Row

struct CommitRow: View {
    let commit: GitCommit

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(commit.subject)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

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
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        return result.size
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
