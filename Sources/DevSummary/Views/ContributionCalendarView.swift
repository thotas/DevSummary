import SwiftUI

// MARK: - Contribution Calendar

struct ContributionCalendar: View {
    let commits: [GitCommit]

    // Calculate weeks of activity for the past year
    private var weeks: [[DayActivity?]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Group commits by day
        let commitsByDay = Dictionary(grouping: commits) { calendar.startOfDay(for: $0.date) }

        // Build 52 weeks (1 year) of data
        var weeks: [[DayActivity?]] = []
        guard var currentDate = calendar.date(byAdding: .day, value: -364, to: today) else {
            return []
        }

        // Adjust to start from the first Sunday
        let weekday = calendar.component(.weekday, from: currentDate)
        let daysToSunday = (weekday - 1) % 7
        guard let adjustedDate = calendar.date(byAdding: .day, value: -daysToSunday, to: currentDate) else {
            return []
        }
        currentDate = adjustedDate

        for _ in 0..<52 {
            var week: [DayActivity?] = []
            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: currentDate) else {
                    continue
                }
                let dayCommits = commitsByDay[calendar.startOfDay(for: date)] ?? []
                let activity = DayActivity(
                    date: date,
                    count: dayCommits.count,
                    repos: Array(Set(dayCommits.map(\.repo)))
                )
                week.append(activity)
            }
            weeks.append(week)
            guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: currentDate) else {
                break
            }
            currentDate = nextWeek
        }

        return weeks
    }

    private var maxCount: Int {
        weeks.flatMap { $0 }.compactMap { $0?.count }.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Contribution Activity")
                    .font(.system(size: 17, weight: .semibold))

                Spacer()

                Text("\(commits.count) commits in the past year")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            // Calendar grid
            HStack(alignment: .top, spacing: 3) {
                // Day labels
                VStack(alignment: .trailing, spacing: 2) {
                    ForEach(["", "Mon", "", "Wed", "", "Fri", ""], id: \.self) { day in
                        if !day.isEmpty {
                            Text(day)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                                .frame(height: 12)
                        } else {
                            Color.clear.frame(height: 12)
                        }
                    }
                }
                .frame(width: 24)

                // Contribution grid
                HStack(alignment: .top, spacing: 3) {
                    ForEach(weeks.indices, id: \.self) { weekIndex in
                        VStack(spacing: 2) {
                            ForEach(weeks[weekIndex].indices, id: \.self) { dayIndex in
                                if let activity = weeks[weekIndex][dayIndex] {
                                    DayCell(activity: activity, maxCount: maxCount)
                                } else {
                                    Color.clear.frame(width: 11, height: 11)
                                }
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )

            // Legend
            HStack(spacing: 4) {
                Text("Less")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(legendColor(level: level, maxCount: maxCount))
                        .frame(width: 11, height: 11)
                }

                Text("More")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func legendColor(level: Int, maxCount: Int) -> Color {
        // Use ratio-based coloring for consistency with DayCell
        if level == 0 || maxCount == 0 {
            return Color.gray.opacity(0.15)
        }

        let thresholds: [Double] = [0.25, 0.5, 0.75, 1.0]
        let levelIndex = level - 1

        if levelIndex < thresholds.count {
            return Color.green.opacity(0.3 + Double(levelIndex) * 0.2)
        }
        return Color.green
    }
}

struct DayActivity: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
    let repos: [String]
}

struct DayCell: View {
    let activity: DayActivity
    let maxCount: Int

    private var color: Color {
        if activity.count == 0 {
            return Color.gray.opacity(0.15)
        }

        let ratio = Double(activity.count) / Double(max(maxCount, 1))

        if ratio < 0.25 {
            return Color.green.opacity(0.4)
        } else if ratio < 0.5 {
            return Color.green.opacity(0.6)
        } else if ratio < 0.75 {
            return Color.green.opacity(0.8)
        } else {
            return Color.green
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 11, height: 11)
            .help("\(activity.count) commits on \(activity.date.formatted(.dateTime.month(.abbreviated).day().year()))")
    }
}

// MARK: - Streak Info View

struct StreakInfoView: View {
    let commits: [GitCommit]

    // Cache commitsByDay to avoid recomputation
    private var commitsByDay: [Date: [GitCommit]] {
        let calendar = Calendar.current
        return Dictionary(grouping: commits) { calendar.startOfDay(for: $0.date) }
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var streak = 0
        var checkDate = today

        // Check if there's activity today or yesterday to start counting
        let hasToday = commitsByDay[calendar.startOfDay(for: today)] != nil
        if !hasToday {
            // Check yesterday - if no activity yesterday, streak is 0
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
                return 0
            }
            if commitsByDay[calendar.startOfDay(for: yesterday)] == nil {
                return 0
            }
            checkDate = yesterday
        }

        // Count consecutive days
        while commitsByDay[calendar.startOfDay(for: checkDate)] != nil {
            streak += 1
            guard let prevDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                break
            }
            checkDate = prevDay
        }

        return streak
    }

    private var longestStreak: Int {
        let calendar = Calendar.current
        let sortedDays = commitsByDay.keys.sorted()

        guard !sortedDays.isEmpty else { return 0 }

        var longest = 1
        var current = 1

        for i in 1..<sortedDays.count {
            let prevDay = sortedDays[i - 1]
            let currDay = sortedDays[i]

            let daysDiff = calendar.dateComponents([.day], from: prevDay, to: currDay).day ?? 0

            if daysDiff == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }

        return longest
    }

    var body: some View {
        HStack(spacing: 24) {
            StreakBadge(label: "Current Streak", value: currentStreak, unit: "days", color: .orange)
            StreakBadge(label: "Longest Streak", value: longestStreak, unit: "days", color: .purple)
        }
    }
}

struct StreakBadge: View {
    let label: String
    let value: Int
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 16))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}
