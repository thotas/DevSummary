import SwiftUI
import AppKit

struct CommitDetailPopover: View {
    let commit: GitCommit
    @Environment(\.dismiss) private var dismiss

    private var shortHash: String {
        String(commit.hash.prefix(7))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Commit Details")
                    .font(.system(size: 15, weight: .semibold))

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }

            Divider()

            // Commit hash
            HStack(spacing: 8) {
                Text("Hash:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)

                Text(shortHash)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.blue)

                Button {
                    copyToClipboard(commit.hash)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .help("Copy full hash")
            }

            // Repository
            HStack(spacing: 8) {
                Text("Repository:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)

                Text(commit.repo)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
            }

            // Author
            HStack(spacing: 8) {
                Text("Author:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)

                Text(commit.author)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)

                Text("<\(commit.email)>")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            // Date
            HStack(spacing: 8) {
                Text("Date:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)

                Text(commit.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year().hour().minute()))
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
            }

            Divider()

            // Subject
            VStack(alignment: .leading, spacing: 6) {
                Text("Subject")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(commit.subject)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineSpacing(2)
            }

            // Body (if any)
            if !commit.body.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Message")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text(commit.body)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .lineSpacing(3)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            Spacer()

            // Copy button
            Button {
                copyToClipboard(commit.hash)
            } label: {
                Label("Copy Commit Hash", systemImage: "doc.on.doc")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(20)
        .frame(width: 420, height: 380)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
