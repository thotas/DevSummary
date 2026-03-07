import SwiftUI

struct SummaryOptionsPopover: View {
    @Binding var selectedStyle: SummaryStyle
    @Binding var selectedLength: SummaryLength
    let onGenerate: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Summary Options")
                .font(.system(size: 14, weight: .semibold))

            VStack(alignment: .leading, spacing: 8) {
                Text("Style")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Picker("Style", selection: $selectedStyle) {
                    ForEach(SummaryStyle.allCases) { style in
                        VStack(alignment: .leading) {
                            Text(style.label)
                        }
                        .tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(selectedStyle.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Length")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Picker("Length", selection: $selectedLength) {
                    ForEach(SummaryLength.allCases) { length in
                        Text(length.label)
                            .tag(length)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(selectedLength.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button {
                    onGenerate()
                    dismiss()
                } label: {
                    Label("Generate", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}

struct SummaryOptionsButton: View {
    let project: ProjectSummary
    let onGenerate: (SummaryOptions) -> Void

    @State private var showingPopover = false
    @State private var selectedStyle: SummaryStyle
    @State private var selectedLength: SummaryLength

    init(project: ProjectSummary, onGenerate: @escaping (SummaryOptions) -> Void) {
        self.project = project
        self.onGenerate = onGenerate
        _selectedStyle = State(initialValue: project.summaryOptions?.style ?? AppSettings.shared.summaryStyle)
        _selectedLength = State(initialValue: project.summaryOptions?.length ?? AppSettings.shared.summaryLength)
    }

    var body: some View {
        Button {
            showingPopover = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                Text("Generate")
                    .font(.system(size: 11, weight: .medium))
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .popover(isPresented: $showingPopover) {
            SummaryOptionsPopover(
                selectedStyle: $selectedStyle,
                selectedLength: $selectedLength,
                onGenerate: {
                    let options = SummaryOptions(style: selectedStyle, length: selectedLength)
                    onGenerate(options)
                }
            )
        }
        .help("Generate summary with custom options")
    }
}
