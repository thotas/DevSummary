import SwiftUI
import AppKit

struct CommitDetailPopover: View {
    let commit: GitCommit
    let commitDetail: GitCommitDetail?
    let onRegenerate: (SummaryStyle) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: AppViewModel
    @State private var selectedStyle: SummaryStyle = .concise
    @State private var noteText: String = ""
    @State private var isEditingNote = false
    @FocusState private var isNoteFieldFocused: Bool

    private var shortHash: String {
        String(commit.hash.prefix(7))
    }

    private var existingNote: CommitNote? {
        viewModel.getCommitNote(commit)
    }

    private var isFavorite: Bool {
        viewModel.isCommitFavorite(commit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Commit Inspector")
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

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Commit info section
                    commitInfoSection

                    Divider()

                    // Note section
                    noteSection

                    Divider()

                    // Files changed section
                    if let detail = commitDetail, !detail.files.isEmpty {
                        filesChangedSection(detail: detail)
                        Divider()
                    }

                    // AI Explanation section
                    aiExplanationSection
                }
            }

            Divider()

            // Action buttons
            actionButtons
        }
        .padding(20)
        .frame(width: 480, height: 580)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var commitInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Hash and copy
            HStack(spacing: 8) {
                Label("Hash", systemImage: "number")
                    .font(.system(size: 11, weight: .medium))
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
                Label("Repo", systemImage: "folder")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)

                Text(commit.repo)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    openInTerminal()
                } label: {
                    Image(systemName: "terminal")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .help("Open in Terminal")
            }

            // Author
            HStack(spacing: 8) {
                Label("Author", systemImage: "person")
                    .font(.system(size: 11, weight: .medium))
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
                Label("Date", systemImage: "calendar")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)

                Text(commit.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
            }

            // Subject
            VStack(alignment: .leading, spacing: 4) {
                Text("SUBJECT")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                Text(commit.subject)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineSpacing(2)
            }

            // Body (if any)
            if !commit.body.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MESSAGE")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)

                    Text(commit.body)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .lineSpacing(3)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    // MARK: - Note Section

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("NOTE")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                Spacer()

                // Favorite button
                Button {
                    viewModel.toggleCommitFavorite(commit)
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 12))
                        .foregroundStyle(isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .help(isFavorite ? "Remove from favorites" : "Add to favorites")

                // Add/Edit note button
                Button {
                    if let note = existingNote {
                        noteText = note.note
                    } else {
                        noteText = ""
                    }
                    isEditingNote = true
                    isNoteFieldFocused = true
                } label: {
                    Image(systemName: existingNote != nil ? "note.text" : "plus.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(existingNote != nil ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .help(existingNote != nil ? "Edit note" : "Add note")
            }

            if isEditingNote {
                VStack(spacing: 8) {
                    TextEditor(text: $noteText)
                        .font(.system(size: 12))
                        .frame(height: 80)
                        .scrollContentBackground(.hidden)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(.quaternary, lineWidth: 1)
                        )
                        .focused($isNoteFieldFocused)

                    HStack(spacing: 8) {
                        if !noteText.isEmpty || existingNote != nil {
                            Button {
                                if !noteText.isEmpty {
                                    viewModel.saveCommitNote(commit, note: noteText)
                                } else if existingNote != nil {
                                    viewModel.deleteCommitNote(commit)
                                }
                                isEditingNote = false
                            } label: {
                                Text("Save")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }

                        Button {
                            isEditingNote = false
                            noteText = ""
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            } else if let note = existingNote {
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.note)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .lineSpacing(3)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))

                    HStack {
                        Text("Added \(note.createdAt.formatted(.dateTime.month().day().year()))")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)

                        if note.updatedAt != note.createdAt {
                            Text("· Updated \(note.updatedAt.formatted(.dateTime.month().day().year()))")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            } else {
                Text("No note added")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .italic()
                    .padding(.vertical, 8)
            }
        }
    }

    private func filesChangedSection(detail: GitCommitDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("FILES CHANGED")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                Spacer()

                HStack(spacing: 12) {
                    Label("\(detail.totalAdditions)", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.green)

                    Label("\(detail.totalDeletions)", systemImage: "minus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.red)

                    Text("\(detail.changedFilesCount) files")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 4) {
                ForEach(detail.files.prefix(15)) { file in
                    HStack {
                        statusIcon(for: file.status)

                        Text(file.path)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        HStack(spacing: 4) {
                            if file.additions > 0 {
                                Text("+\(file.additions)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.green)
                            }
                            if file.deletions > 0 {
                                Text("-\(file.deletions)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 6)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.3), in: RoundedRectangle(cornerRadius: 4))
                }

                if detail.files.count > 15 {
                    Text("... and \(detail.files.count - 15) more files")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
        }
    }

    private func statusIcon(for status: FileChangeStatus) -> some View {
        let (icon, color): (String, Color) = {
            switch status {
            case .added:
                return ("A", .green)
            case .deleted:
                return ("D", .red)
            case .modified:
                return ("M", .orange)
            case .renamed:
                return ("R", .blue)
            case .copied:
                return ("C", .purple)
            case .untracked:
                return ("?", .secondary)
            }
        }()

        return Text(icon)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .frame(width: 14)
    }

    private var aiExplanationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("AI EXPLANATION")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                Spacer()

                if let detail = commitDetail, detail.isGenerating {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                }
            }

            // Style selector
            HStack(spacing: 8) {
                Text("Style:")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Picker("", selection: $selectedStyle) {
                    ForEach(SummaryStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .onChange(of: selectedStyle) { _, newValue in
                    onRegenerate(newValue)
                }

                Spacer()

                if let detail = commitDetail {
                    Button {
                        onRegenerate(selectedStyle)
                    } label: {
                        Label("Regenerate", systemImage: "arrow.clockwise")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(detail.isGenerating)
                }
            }

            // Explanation content
            if let detail = commitDetail {
                if detail.isGenerating {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Analyzing commit...")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else if let explanation = detail.aiExplanation {
                    Text(explanation)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .lineSpacing(4)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.08), Color.purple.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                } else {
                    Text("No explanation available")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .italic()
                        .padding(.vertical, 20)
                }
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "brain")
                            .font(.system(size: 24))
                            .foregroundStyle(.tertiary)
                        Text("Click 'Regenerate' to get AI explanation")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                copyToClipboard(commit.hash)
            } label: {
                Label("Copy Hash", systemImage: "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                openInTerminal()
            } label: {
                Label("Open in Terminal", systemImage: "terminal")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if let detail = commitDetail, let diff = detail.diff, !diff.isEmpty {
                Button {
                    copyToClipboard(diff)
                } label: {
                    Label("Copy Diff", systemImage: "doc.on.clipboard")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Spacer()

            if let detail = commitDetail {
                Button {
                    let info = """
                    Commit: \(commit.hash)
                    Author: \(commit.author) <\(commit.email)>
                    Date: \(commit.date)
                    Repository: \(commit.repo)

                    Subject: \(commit.subject)

                    \(commit.body.isEmpty ? "" : "Message:\n\(commit.body)")

                    \(detail.aiExplanation.map { "AI Explanation:\n\($0)" } ?? "")
                    """
                    copyToClipboard(info)
                } label: {
                    Label("Copy All", systemImage: "doc.on.doc.fill")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func openInTerminal() {
        let script = "tell app \"Terminal\" to do script \"cd \(commit.repoPath) && git show \(commit.hash)\""
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}
