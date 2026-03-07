import SwiftUI
import AppKit

struct FocusedShortcutHandler: ViewModifier {
    @ObservedObject var viewModel: AppViewModel

    func body(content: Content) -> some View {
        content
            .focusedSceneValue(\.appViewModel, viewModel)
            .onAppear {
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    if handleKeyEvent(event) {
                        return nil  // Suppress the event
                    }
                    return event
                }
            }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Check for Command key
        if modifiers.contains(.command) {
            switch event.keyCode {
            case 15: // R - Refresh
                Task { await viewModel.regenerateAllSummaries() }
                return true
            case 14: // E - Export
                viewModel.exportSummaryToClipboard()
                return true
            case 3: // F - Focus search
                viewModel.toggleSearchFocus()
                return true
            case 29: // 1 - Last 24 hours
                viewModel.changePeriod(.oneDay)
                return true
            case 18: // 2 - Last week
                viewModel.changePeriod(.oneWeek)
                return true
            case 19: // 3 - Last month
                viewModel.changePeriod(.oneMonth)
                return true
            case 20: // 4 - Last 3 months
                viewModel.changePeriod(.threeMonths)
                return true
            case 50: // Escape - Clear search / dismiss
                if !viewModel.searchText.isEmpty {
                    viewModel.clearSearch()
                    return true
                }
                return false
            default:
                return false
            }
        }

        return false
    }
}

extension View {
    func focusedShortcutHandler(viewModel: AppViewModel) -> some View {
        modifier(FocusedShortcutHandler(viewModel: viewModel))
    }
}

// Focus state for search field
struct SearchFocusKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var isSearchFocused: Binding<Bool>? {
        get { self[SearchFocusKey.self] }
        set { self[SearchFocusKey.self] = newValue }
    }
}

// App ViewModel focus value for global access
struct AppViewModelKey: FocusedValueKey {
    typealias Value = AppViewModel
}

extension FocusedValues {
    var appViewModel: AppViewModel? {
        get { self[AppViewModelKey.self] }
        set { self[AppViewModelKey.self] = newValue }
    }
}
