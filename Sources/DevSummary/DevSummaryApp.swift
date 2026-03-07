import SwiftUI

@main
struct DevSummaryApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 900, minHeight: 600)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1100, height: 750)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandMenu("View") {
                Button("Refresh Summaries") {
                    Task { await viewModel.regenerateAllSummaries() }
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Last 24 Hours") {
                    viewModel.changePeriod(.oneDay)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Last Week") {
                    viewModel.changePeriod(.oneWeek)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Last Month") {
                    viewModel.changePeriod(.oneMonth)
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Last 3 Months") {
                    viewModel.changePeriod(.threeMonths)
                }
                .keyboardShortcut("4", modifiers: .command)

                Divider()

                Button(viewModel.searchText.isEmpty ? "Focus Search" : "Clear Search") {
                    viewModel.toggleSearchFocus()
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Clear Search") {
                    viewModel.clearSearch()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(viewModel.searchText.isEmpty)
            }

            CommandMenu("Summary") {
                Button("Export to Clipboard") {
                    viewModel.exportSummaryToClipboard()
                }
                .keyboardShortcut("e", modifiers: .command)

                Divider()

                Button("Settings...") {
                    viewModel.showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
