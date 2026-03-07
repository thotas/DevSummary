import SwiftUI

struct CommitTypeDistributionChart: View {
    let commits: [GitCommit]
    @Binding var selectedTypes: Set<CommitType>

    private var typeDistribution: [(type: CommitType, count: Int, percentage: Double)] {
        let total = commits.count
        guard total > 0 else { return [] }

        var counts: [CommitType: Int] = [:]
        for commit in commits {
            let type = categorizeCommit(commit)
            counts[type, default: 0] += 1
        }

        return CommitType.allCases
            .compactMap { type in
                guard let count = counts[type], count > 0 else { return nil }
                let percentage = Double(count) / Double(total) * 100
                return (type: type, count: count, percentage: percentage)
            }
            .sorted { $0.count > $1.count }
    }

    private var totalCount: Int {
        commits.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Work Distribution")
                .font(.system(size: 17, weight: .semibold))

            if typeDistribution.isEmpty {
                emptyState
            } else {
                HStack(alignment: .top, spacing: 24) {
                    donutChart
                        .frame(width: 160, height: 160)

                    legend
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }

    private var emptyState: some View {
        HStack {
            Image(systemName: "chart.pie")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text("No commits to analyze")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var donutChart: some View {
        let isFiltered = !selectedTypes.isEmpty

        return ZStack {
            ForEach(Array(typeDistribution.enumerated()), id: \.element.type) { index, item in
                DonutSegment(
                    startAngle: startAngle(for: index),
                    endAngle: endAngle(for: index),
                    color: colorFor(type: item.type),
                    isSelected: selectedTypes.contains(item.type),
                    dimmed: isFiltered && !selectedTypes.contains(item.type)
                )
                .accessibilityLabel("\(item.type.label): \(item.count) commits (\(Int(item.percentage))%)")
            }

            VStack(spacing: 2) {
                Text("\(totalCount)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("commits")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: typeDistribution.map(\.count))
    }

    private func startAngle(for index: Int) -> Angle {
        let precedingTotal = typeDistribution.prefix(index).reduce(0) { $0 + $1.count }
        return Angle(degrees: Double(precedingTotal) / Double(totalCount) * 360 - 90)
    }

    private func endAngle(for index: Int) -> Angle {
        let includingTotal = typeDistribution.prefix(index + 1).reduce(0) { $0 + $1.count }
        return Angle(degrees: Double(includingTotal) / Double(totalCount) * 360 - 90)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(typeDistribution, id: \.type) { item in
                legendRow(for: item)
            }
        }
    }

    private func legendRow(for item: (type: CommitType, count: Int, percentage: Double)) -> some View {
        let isSelected = selectedTypes.contains(item.type)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isSelected {
                    selectedTypes.remove(item.type)
                } else {
                    selectedTypes.insert(item.type)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(colorFor(type: item.type))
                    .frame(width: 10, height: 10)

                Text(item.type.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer()

                Text("\(item.count)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? colorFor(type: item.type) : .secondary)

                Text("(\(Int(item.percentage))%)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(width: 40, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? colorFor(type: item.type).opacity(0.1)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isSelected ? "Click to remove filter" : "Click to filter by \(item.type.label)")
    }

    private func colorFor(type: CommitType) -> Color {
        switch type {
        case .feature: return .blue
        case .fix: return .red
        case .refactor: return .purple
        case .docs: return .teal
        case .test: return .green
        case .style: return .pink
        case .deps: return .orange
        case .config: return .yellow
        case .remove: return .indigo
        case .setup: return .cyan
        case .other: return .gray
        }
    }

    private func categorizeCommit(_ commit: GitCommit) -> CommitType {
        let subject = commit.subject.lowercased()
        let body = commit.body.lowercased()
        let combined = subject + " " + body

        if combined.contains("feat") || combined.contains("feature") || subject.hasPrefix("add") {
            return .feature
        } else if combined.contains("fix") || combined.contains("bug") || combined.contains("resolve") || subject.hasPrefix("fix") {
            return .fix
        } else if combined.contains("refactor") || combined.contains("improve") || combined.contains("optimize") || combined.contains("clean") {
            return .refactor
        } else if combined.contains("doc") || combined.contains("readme") || combined.contains("comment") {
            return .docs
        } else if combined.contains("test") || combined.contains("spec") || combined.contains("coverage") {
            return .test
        } else if combined.contains("style") || combined.contains("format") || combined.contains("lint") {
            return .style
        } else if combined.contains("depend") || combined.contains("package") || combined.contains("npm") || combined.contains("pip") || combined.contains("cargo") {
            return .deps
        } else if combined.contains("config") || combined.contains(".gitignore") || combined.contains("docker") || combined.contains("env") {
            return .config
        } else if combined.contains("remove") || combined.contains("delete") || combined.contains("deprecate") {
            return .remove
        } else if combined.contains("setup") || combined.contains("init") || combined.contains("install") {
            return .setup
        }
        return .other
    }
}

struct DonutSegment: View {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color
    let isSelected: Bool
    let dimmed: Bool

    var body: some View {
        Circle()
            .trim(from: trimStart, to: trimEnd)
            .stroke(
                color,
                style: StrokeStyle(lineWidth: isSelected ? 28 : 24, lineCap: .butt)
            )
            .frame(width: 140, height: 140)
            .rotationEffect(.degrees(-90))
            .opacity(dimmed ? 0.25 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
            .animation(.easeInOut(duration: 0.2), value: dimmed)
    }

    private var trimStart: CGFloat {
        let degrees = (startAngle.degrees + 90) / 360
        return CGFloat(max(0, min(1, degrees)))
    }

    private var trimEnd: CGFloat {
        let degrees = (endAngle.degrees + 90) / 360
        return CGFloat(max(0, min(1, degrees)))
    }
}

#Preview {
    let sampleCommits = [
        GitCommit(hash: "1", author: "A", email: "a@a.com", date: Date(), subject: "feat: add new feature", body: "", repo: "Test", repoPath: "/test"),
        GitCommit(hash: "2", author: "A", email: "a@a.com", date: Date(), subject: "fix: bug fix", body: "", repo: "Test", repoPath: "/test"),
        GitCommit(hash: "3", author: "A", email: "a@a.com", date: Date(), subject: "refactor: improve code", body: "", repo: "Test", repoPath: "/test"),
        GitCommit(hash: "4", author: "A", email: "a@a.com", date: Date(), subject: "docs: update readme", body: "", repo: "Test", repoPath: "/test"),
        GitCommit(hash: "5", author: "A", email: "a@a.com", date: Date(), subject: "test: add tests", body: "", repo: "Test", repoPath: "/test"),
    ]

    return CommitTypeDistributionChart(commits: sampleCommits, selectedTypes: .constant([]))
        .frame(width: 400)
        .padding()
}
