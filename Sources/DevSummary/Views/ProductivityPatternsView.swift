import SwiftUI

struct ProductivityPatternsView: View {
    let commits: [GitCommit]

    private var hourlyDistribution: [Int: Int] {
        var counts: [Int: Int] = [:]
        for commit in commits {
            let hour = Calendar.current.component(.hour, from: commit.date)
            counts[hour, default: 0] += 1
        }
        return counts
    }

    private var dayOfWeekDistribution: [Int: Int] {
        var counts: [Int: Int] = [:]
        let calendar = Calendar.current
        for commit in commits {
            let weekday = calendar.component(.weekday, from: commit.date)
            counts[weekday, default: 0] += 1
        }
        return counts
    }

    private var peakHour: Int? {
        hourlyDistribution.max(by: { $0.value < $1.value })?.key
    }

    private var peakDay: Int? {
        dayOfWeekDistribution.max(by: { $0.value < $1.value })?.key
    }

    private var weekdayCommits: Int {
        let calendar = Calendar.current
        return commits.filter { commit in
            let weekday = calendar.component(.weekday, from: commit.date)
            return weekday >= 2 && weekday <= 6 // Monday = 2, Saturday = 7
        }.count
    }

    private var weekendCommits: Int {
        commits.count - weekdayCommits
    }

    private var averageCommitsPerDay: Double {
        guard !commits.isEmpty else { return 0 }
        let calendar = Calendar.current
        let dates = commits.map { calendar.startOfDay(for: $0.date) }
        let uniqueDays = Set(dates).count
        return uniqueDays > 0 ? Double(commits.count) / Double(uniqueDays) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Productivity Patterns")
                        .font(.system(size: 17, weight: .semibold))
                    Text("When you work most")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
            }

            // Insights cards
            HStack(spacing: 12) {
                InsightCard(
                    icon: "sunrise.fill",
                    title: "Peak Hour",
                    value: peakHour.map { formatHour($0) } ?? "N/A",
                    subtitle: "Most commits",
                    color: .orange
                )

                InsightCard(
                    icon: "calendar",
                    title: "Peak Day",
                    value: peakDay.map { weekdayName($0) } ?? "N/A",
                    subtitle: "Most active",
                    color: .purple
                )

                InsightCard(
                    icon: "chart.bar.fill",
                    title: "Daily Avg",
                    value: String(format: "%.1f", averageCommitsPerDay),
                    subtitle: "commits/day",
                    color: .blue
                )
            }

            // Hourly chart
            VStack(alignment: .leading, spacing: 10) {
                Text("Hourly Activity")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                HourlyChartView(distribution: hourlyDistribution)
            }

            // Weekly distribution
            VStack(alignment: .leading, spacing: 10) {
                Text("Weekly Distribution")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                WeeklyChartView(distribution: dayOfWeekDistribution)
            }

            // Work pattern summary
            if commits.count > 0 {
                WorkPatternSummary(
                    weekdayCommits: weekdayCommits,
                    weekendCommits: weekendCommits,
                    peakHour: peakHour
                )
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

    private func formatHour(_ hour: Int) -> String {
        switch hour {
        case 0: return "12am"
        case 1...11: return "\(hour)am"
        case 12: return "12pm"
        default: return "\(hour - 12)pm"
        }
    }

    private func weekdayName(_ day: Int) -> String {
        switch day {
        case 1: return "Sun"
        case 2: return "Mon"
        case 3: return "Tue"
        case 4: return "Wed"
        case 5: return "Thu"
        case 6: return "Fri"
        case 7: return "Sat"
        default: return "N/A"
        }
    }
}

// MARK: - Insight Card

struct InsightCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Hourly Chart

struct HourlyChartView: View {
    let distribution: [Int: Int]

    private var sortedHours: [Int] {
        (0..<24).sorted()
    }

    private var maxCount: Int {
        distribution.values.max() ?? 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(sortedHours, id: \.self) { hour in
                let count = distribution[hour] ?? 0
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(for: hour, count: count))
                        .frame(width: 16, height: max(4, CGFloat(count) / CGFloat(maxCount) * 60))

                    if hour % 4 == 0 {
                        Text("\(hour)")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("")
                            .font(.system(size: 8))
                    }
                }
            }
        }
        .frame(height: 90)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private func barColor(for hour: Int, count: Int) -> Color {
        guard count > 0 else { return Color.secondary.opacity(0.2) }

        // Highlight typical work hours (9am-6pm)
        if hour >= 9 && hour <= 18 {
            return Color.blue.opacity(0.6 + 0.4 * Double(count) / Double(maxCount))
        }
        // Early morning (5am-9am)
        else if hour >= 5 && hour < 9 {
            return Color.orange.opacity(0.4 + 0.4 * Double(count) / Double(maxCount))
        }
        // Evening (6pm-10pm)
        else if hour > 18 && hour <= 22 {
            return Color.purple.opacity(0.4 + 0.4 * Double(count) / Double(maxCount))
        }
        // Night
        else {
            return Color.gray.opacity(0.3 + 0.3 * Double(count) / Double(maxCount))
        }
    }
}

// MARK: - Weekly Chart

struct WeeklyChartView: View {
    let distribution: [Int: Int]

    private let days = ["S", "M", "T", "W", "T", "F", "S"]

    private var maxCount: Int {
        distribution.values.max() ?? 1
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...7, id: \.self) { dayIndex in
                let count = distribution[dayIndex] ?? 0
                let isWeekend = dayIndex == 1 || dayIndex == 7

                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isWeekend ? Color.purple.opacity(0.3 + 0.5 * Double(count) / Double(maxCount)) : Color.green.opacity(0.3 + 0.5 * Double(count) / Double(maxCount)))
                        .frame(height: max(8, CGFloat(count) / CGFloat(maxCount) * 50))

                    Text(days[dayIndex - 1])
                        .font(.system(size: 11, weight: isWeekend ? .medium : .regular))
                        .foregroundStyle(isWeekend ? .secondary : .primary)

                    Text("\(count)")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Work Pattern Summary

struct WorkPatternSummary: View {
    let weekdayCommits: Int
    let weekendCommits: Int
    let peakHour: Int?

    private var weekdayPercentage: Int {
        let total = weekdayCommits + weekendCommits
        guard total > 0 else { return 0 }
        return Int((Double(weekdayCommits) / Double(total)) * 100)
    }

    private var workStyle: String {
        guard let hour = peakHour else { return "Analyzing..." }

        switch hour {
        case 5...8:
            return "Early Bird"
        case 9...11:
            return "Morning Pro"
        case 12...14:
            return "Lunch Worker"
        case 15...17:
            return "Afternoon Star"
        case 18...20:
            return "Evening Owl"
        default:
            return "Night Owl"
        }
    }

    private var workStyleIcon: String {
        guard let hour = peakHour else { return "questionmark.circle" }

        switch hour {
        case 5...8:
            return "sunrise.fill"
        case 9...11:
            return "sun.max.fill"
        case 12...14:
            return "sun.min.fill"
        case 15...17:
            return "sunset.fill"
        case 18...20:
            return "moon.stars.fill"
        default:
            return "moon.fill"
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Work style badge
            HStack(spacing: 8) {
                Image(systemName: workStyleIcon)
                    .foregroundStyle(.blue)
                Text(workStyle)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1), in: Capsule())

            Divider()
                .frame(height: 20)

            // Weekday distribution
            HStack(spacing: 6) {
                Image(systemName: "building.2")
                    .foregroundStyle(.green)
                Text("\(weekdayPercentage)%")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                Text("weekday")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Weekend indicator
            if weekendCommits > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "leaf")
                        .foregroundStyle(.purple)
                    Text("\(100 - weekdayPercentage)% weekend")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }
}
