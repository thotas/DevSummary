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

        // Check for Command + Shift (Command Palette)
        if modifiers.contains(.command) && modifiers.contains(.shift) {
            switch event.keyCode {
            case 35: // P - Command Palette
                viewModel.toggleCommandPalette()
                return true
            default:
                break
            }
        }

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
            case 29: // 1 - Last 24 hours (or preset 1 if available)
                if !viewModel.presets.isEmpty {
                    viewModel.quickSwitchToPreset(index: 0)
                    return true
                }
                viewModel.changePeriod(.oneDay)
                return true
            case 18: // 2 - Last week (or preset 2 if available)
                if viewModel.presets.count > 1 {
                    viewModel.quickSwitchToPreset(index: 1)
                    return true
                }
                viewModel.changePeriod(.oneWeek)
                return true
            case 19: // 3 - Last month (or preset 3 if available)
                if viewModel.presets.count > 2 {
                    viewModel.quickSwitchToPreset(index: 2)
                    return true
                }
                viewModel.changePeriod(.oneMonth)
                return true
            case 20: // 4 - Last 3 months (or preset 4 if available)
                if viewModel.presets.count > 3 {
                    viewModel.quickSwitchToPreset(index: 3)
                    return true
                }
                viewModel.changePeriod(.threeMonths)
                return true
            case 21: // 5 - Preset 5
                if viewModel.presets.count > 4 {
                    viewModel.quickSwitchToPreset(index: 4)
                    return true
                }
                return false
            case 23: // 6 - Preset 6
                if viewModel.presets.count > 5 {
                    viewModel.quickSwitchToPreset(index: 5)
                    return true
                }
                return false
            case 26: // 7 - Preset 7
                if viewModel.presets.count > 6 {
                    viewModel.quickSwitchToPreset(index: 6)
                    return true
                }
                return false
            case 28: // 8 - Preset 8
                if viewModel.presets.count > 7 {
                    viewModel.quickSwitchToPreset(index: 7)
                    return true
                }
                return false
            case 25: // 9 - Preset 9
                if viewModel.presets.count > 8 {
                    viewModel.quickSwitchToPreset(index: 8)
                    return true
                }
                return false
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
