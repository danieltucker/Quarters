import SwiftUI
import SwiftData

// MARK: - LedgerView (was HistoryView)

struct LedgerView: View {
    @Query(filter: #Predicate<Session> { $0.statusRaw == "completed" },
           sort: \Session.startedAt, order: .reverse) private var sessions: [Session]
    @Query(sort: \LedgerEntry.timestamp, order: .reverse) private var ledger: [LedgerEntry]
    @Query private var dailyLogs: [DailyLog]

    // MARK: - Computed stats

    private var thisWeekQuarters: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        return sessions
            .filter { $0.startedAt >= cutoff }
            .reduce(0) { $0 + ($1.wasEndedEarly ? $1.completedBlocksAtEnd : $1.blockCount) }
    }

    private var mintedTotal: Int {
        ledger.filter { $0.delta > 0 }.reduce(0) { $0 + $1.delta }
    }

    private var streakDays: Int { AppConfig.streak(from: dailyLogs) }

    // MARK: - Day grouping

    private var groupedEntries: [(label: String, entries: [LedgerEntry])] {
        let calendar = Calendar.current
        var groups: [(String, [LedgerEntry])] = []
        var currentLabel = ""
        var batch: [LedgerEntry] = []

        for entry in ledger {
            let label = dayLabel(for: entry.timestamp, calendar: calendar)
            if label != currentLabel {
                if !batch.isEmpty { groups.append((currentLabel, batch)) }
                currentLabel = label
                batch = [entry]
            } else {
                batch.append(entry)
            }
        }
        if !batch.isEmpty { groups.append((currentLabel, batch)) }
        return groups
    }

    private func dayLabel(for date: Date, calendar: Calendar) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        if calendar.isDateInToday(date)     { return "Today · \(fmt.string(from: date))" }
        if calendar.isDateInYesterday(date) { return "Yesterday · \(fmt.string(from: date))" }
        fmt.dateFormat = "EEEE · MMM d"
        return fmt.string(from: date)
    }

    // MARK: - Body

    var body: some View {
        if ledger.isEmpty && sessions.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    statTiles
                        .padding(.bottom, 18)

                    if groupedEntries.isEmpty {
                        Text("No entries yet.")
                            .font(.qText(13))
                            .foregroundStyle(Theme.ink3)
                    } else {
                        ForEach(groupedEntries, id: \.label) { group in
                            // Day header
                            Text(group.label)
                                .font(.qText(11, weight: .bold))
                                .kerning(0.5)
                                .foregroundStyle(Theme.ink2)
                                .padding(.bottom, 8)

                            VStack(spacing: 7) {
                                ForEach(group.entries) { entry in
                                    LedgerRow(entry: entry)
                                }
                            }
                            .padding(.bottom, 18)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Stat tiles

    private var statTiles: some View {
        HStack(spacing: 8) {
            StatTile(label: "This week",
                     value: "\(thisWeekQuarters)",
                     unit: "quarter\(thisWeekQuarters == 1 ? "" : "s")")
            StatTile(label: "Minted",
                     value: "+\(mintedTotal)",
                     unit: "coins")
            StatTile(label: "Streak",
                     value: "\(streakDays)",
                     unit: "day\(streakDays == 1 ? "" : "s")")
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            QMark(size: 40, ringColor: Theme.ink3, wedgeColor: Theme.accent.opacity(0.5))
            Text("No history yet")
                .font(.qText(15, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Completed sessions appear here.")
                .font(.qText(13))
                .foregroundStyle(Theme.ink2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Stat tile

private struct StatTile: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.qText(10, weight: .bold))
                .kerning(0.8)
                .foregroundStyle(Theme.ink2)
            Text(value)
                .font(.qDisplay(22))
                .foregroundStyle(Theme.ink)
            Text(unit)
                .font(.qText(11))
                .foregroundStyle(Theme.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
    }
}

// MARK: - Ledger row

private struct LedgerRow: View {
    let entry: LedgerEntry

    private var isEarn: Bool { entry.delta > 0 }

    private var iconName: String { isEarn ? "bolt" : "gift" }

    private var formattedAmount: String {
        isEarn ? "+\(entry.delta)" : "−\(abs(entry.delta))"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon tile
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isEarn ? Theme.greenSoft : Theme.accentSoft)
                QIcon(name: iconName, size: 15,
                      color: isEarn ? Theme.green : Theme.accent)
            }
            .frame(width: 36, height: 36)

            // Label + subtext
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.reason)
                    .font(.qText(13))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(entry.timestamp, format: .dateTime.hour().minute())
                    .font(.qText(11))
                    .foregroundStyle(Theme.ink2)
            }

            Spacer()

            // Amount
            Text(formattedAmount)
                .font(.qMono(13, weight: .semibold))
                .foregroundStyle(isEarn ? Theme.green : Theme.accent)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line, lineWidth: 1))
    }
}
