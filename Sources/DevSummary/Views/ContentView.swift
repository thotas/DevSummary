import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            if viewModel.isScanning || viewModel.isLoading {
                LoadingView(scanning: viewModel.isScanning)
            } else if let error = viewModel.error {
                EmptyStateView(message: error, isError: true)
            } else if let summary = viewModel.summary, summary.totalCommits > 0 {
                SummaryDetailView(summary: summary, commits: viewModel.commits)
            } else {
                EmptyStateView(
                    message: "No commits found for the selected period and repositories.",
                    isError: false
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView()
        }
        .focusedShortcutHandler(viewModel: viewModel)
    }
}
