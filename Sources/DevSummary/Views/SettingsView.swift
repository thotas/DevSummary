import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

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
        .frame(width: 420, height: 340)
    }
}
