import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedStyle: SummaryStyle = AppSettings.shared.summaryStyle
    @State private var selectedLength: SummaryLength = AppSettings.shared.summaryLength

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(16)

            Divider()

            Form {
                Section("Ollama Configuration") {
                    HStack {
                        Text("Status")
                        Spacer()
                        if viewModel.ollamaAvailable {
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                        } else {
                            Label("Not Running", systemImage: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                        }
                    }

                    Picker("Model", selection: Binding(
                        get: { viewModel.selectedModel },
                        set: { viewModel.updateModel($0) }
                    )) {
                        if viewModel.availableModels.isEmpty {
                            Text(viewModel.selectedModel).tag(viewModel.selectedModel)
                        } else {
                            ForEach(viewModel.availableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                    }

                    Button("Refresh Models") {
                        Task { await viewModel.checkOllama() }
                    }
                    .font(.system(size: 12))
                }

                Section("Summary Options") {
                    Picker("Style", selection: $selectedStyle) {
                        ForEach(SummaryStyle.allCases) { style in
                            VStack(alignment: .leading) {
                                Text(style.label)
                                Text(style.description)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .tag(style)
                        }
                    }
                    .onChange(of: selectedStyle) { _, newValue in
                        AppSettings.shared.summaryStyle = newValue
                    }

                    Picker("Length", selection: $selectedLength) {
                        ForEach(SummaryLength.allCases) { length in
                            VStack(alignment: .leading) {
                                Text(length.label)
                                Text(length.description)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .tag(length)
                        }
                    }
                    .onChange(of: selectedLength) { _, newValue in
                        AppSettings.shared.summaryLength = newValue
                    }

                    Button("Regenerate with new options") {
                        Task { await viewModel.regenerateAllSummaries() }
                    }
                    .font(.system(size: 12))
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("2.0.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Summaries are cached locally and regenerated only when git changes are detected.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 420, height: 440)
        .onAppear {
            selectedStyle = AppSettings.shared.summaryStyle
            selectedLength = AppSettings.shared.summaryLength
        }
    }
}
