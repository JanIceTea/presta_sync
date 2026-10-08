import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ProductDetailView: View {
    @Bindable var viewModel: ProductDetailViewModel

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading product details...")
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView(
                    "Failed to Load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if viewModel.detail != nil {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        localizedSection("Names", entries: $viewModel.editedNames)
                        localizedSection("Short Descriptions", entries: $viewModel.editedShortDescriptions, isMarkdown: true)
                        localizedSection("Descriptions", entries: $viewModel.editedDescriptions, isMarkdown: true)
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            if viewModel.detail != nil {
                if viewModel.isSaving {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    importFile()
                } label: {
                    Label("Import", systemImage: "arrow.down.doc")
                }
                .disabled(viewModel.isSaving)

                Menu {
                    Button("JSON (.json)") { exportFile(format: .json) }
                    Button("Markdown (.md)") { exportFile(format: .markdown) }
                } label: {
                    Label("Export", systemImage: "arrow.up.doc")
                }
                .disabled(viewModel.isSaving)

                Button {
                    Task { await viewModel.save() }
                } label: {
                    Label("Save to Server", systemImage: "arrow.up.circle")
                }
                .disabled(viewModel.isSaving)

                Button {
                    if viewModel.isEditing {
                        viewModel.stopEditing()
                    } else {
                        viewModel.startEditing()
                    }
                } label: {
                    Label(
                        viewModel.isEditing ? "Done" : "Edit",
                        systemImage: viewModel.isEditing ? "checkmark.circle" : "pencil"
                    )
                }
                .disabled(viewModel.isSaving)
            }
        }
    }

    @ViewBuilder
    private func localizedSection(_ title: String, entries: Binding<[String: String]>, isMarkdown: Bool = false) -> some View {
        let dict = entries.wrappedValue
        if !dict.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.title2.bold())

                ForEach(dict.keys.sorted(), id: \.self) { locale in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(locale)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        if viewModel.isEditing {
                            TextEditor(text: Binding(
                                get: { entries.wrappedValue[locale] ?? "" },
                                set: { entries.wrappedValue[locale] = $0 }
                            ))
                            .font(.body.monospaced())
                            .frame(minHeight: 60)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            Group {
                                if isMarkdown {
                                    Text(markdownToAttributedString(dict[locale] ?? ""))
                                } else {
                                    Text(dict[locale] ?? "")
                                }
                            }
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }
        }
    }

    private func markdownToAttributedString(_ markdown: String) -> AttributedString {
        guard !markdown.isEmpty else { return AttributedString() }
        return (try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(markdown)
    }

    // MARK: - Export / Import

    private enum ExportFormat {
        case json, markdown

        var contentType: UTType { self == .json ? .json : UTType(filenameExtension: "md") ?? .plainText }
        var fileExtension: String { self == .json ? "json" : "md" }
    }

    private func exportFile(format: ExportFormat) {
        let panel = NSSavePanel()
        panel.title = "Export Product Details"
        panel.allowedContentTypes = [format.contentType]
        panel.nameFieldStringValue = "\(viewModel.productName.sanitizedForFilename()).\(format.fileExtension)"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            switch format {
            case .json:
                let data = try viewModel.exportJSON()
                try data.write(to: url)
            case .markdown:
                let text = viewModel.exportMarkdown()
                try text.write(to: url, atomically: true, encoding: .utf8)
            }
        } catch {
            viewModel.errorMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func importFile() {
        let panel = NSOpenPanel()
        panel.title = "Import Product Details"
        panel.allowedContentTypes = [.json, UTType(filenameExtension: "md") ?? .plainText]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try viewModel.importFile(from: url)
        } catch {
            viewModel.errorMessage = "Import failed: \(error.localizedDescription)"
        }
    }
}
