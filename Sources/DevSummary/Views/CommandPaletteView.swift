import SwiftUI

struct CommandPaletteView: View {
    @ObservedObject var viewModel: AppViewModel
    @FocusState private var isSearchFocused: Bool
    @State private var hoveredIndex: Int? = nil

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.closeCommandPalette()
                }

            // Command palette panel
            VStack(spacing: 0) {
                // Search field
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)

                    TextField("Search commands, commits, repos...", text: $viewModel.commandPaletteQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, weight: .medium))
                        .focused($isSearchFocused)
                        .onSubmit {
                            viewModel.executeSelectedCommand()
                        }

                    if !viewModel.commandPaletteQuery.isEmpty {
                        Button(action: { viewModel.commandPaletteQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("esc to close")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                // Results
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.commandPaletteResults.enumerated()), id: \.element.id) { index, item in
                                CommandPaletteRow(
                                    item: item,
                                    isSelected: index == viewModel.selectedCommandIndex,
                                    isHovered: hoveredIndex == index
                                )
                                .id(index)
                                .onTapGesture {
                                    viewModel.selectedCommandIndex = index
                                    viewModel.executeSelectedCommand()
                                }
                                .onHover { hovering in
                                    hoveredIndex = hovering ? index : nil
                                }

                                if index < viewModel.commandPaletteResults.count - 1 {
                                    Divider()
                                        .padding(.leading, 56)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 400)
                    .onChange(of: viewModel.selectedCommandIndex) { _, newValue in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }

                // Footer with keyboard hints
                HStack(spacing: 20) {
                    HStack(spacing: 4) {
                        KeyboardHint(key: "↵")
                        Text("select")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        KeyboardHint(key: "↑↓")
                        Text("navigate")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        KeyboardHint(key: "esc")
                        Text("close")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.9))
            }
            .frame(width: 600)
            .background(Color(nsColor: .windowBackgroundColor))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .onAppear {
            isSearchFocused = true
        }
        .onKeyPress(.upArrow) {
            viewModel.selectPreviousCommand()
            return .handled
        }
        .onKeyPress(.downArrow) {
            viewModel.selectNextCommand()
            return .handled
        }
        .onKeyPress(.escape) {
            viewModel.closeCommandPalette()
            return .handled
        }
    }
}

struct KeyboardHint: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.2))
            .cornerRadius(4)
    }
}

struct CommandPaletteRow: View {
    let item: CommandPaletteItem
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                    .frame(width: 32, height: 32)

                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(item.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSelected ? Color.accentColor.opacity(0.1) : (isHovered ? Color.secondary.opacity(0.05) : Color.clear))
        .contentShape(Rectangle())
    }
}
