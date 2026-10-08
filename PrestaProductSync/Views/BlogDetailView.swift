import SwiftUI
import AppKit
import Textual

struct BlogDetailView: View {
    @Bindable var viewModel: BlogDetailViewModel

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading blog post...")
            } else if viewModel.post == nil {
                ContentUnavailableView(
                    "Failed to Load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(viewModel.errorMessage ?? "Unknown error")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if let error = viewModel.errorMessage {
                            errorBanner(error)
                        }
                        metadataSection
                        if !viewModel.isNewPost {
                            imagesSection
                        }
                        translationSections
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            if viewModel.post != nil {
                if viewModel.isSaving {
                    ProgressView()
                        .controlSize(.small)
                }

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

    // MARK: - Error Banner

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.callout)
            Spacer()
            Button {
                viewModel.errorMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(10)
        .background(.red.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Metadata

    @ViewBuilder
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Post Info")
                .font(.title2.bold())

            LabeledContent("ID") {
                if viewModel.isNewPost && viewModel.isEditing {
                    TextField("post-slug", text: $viewModel.postId)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                } else {
                    Text(viewModel.postId)
                        .textSelection(.enabled)
                }
            }

            if viewModel.isEditing {
                LabeledContent("Date") {
                    TextField("Date", text: $viewModel.editedDate)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                }
                Toggle("Draft", isOn: $viewModel.editedDraft)
            } else {
                LabeledContent("Date") {
                    Text(viewModel.editedDate)
                }
                LabeledContent("Status") {
                    Text(viewModel.editedDraft ? "Draft" : "Published")
                        .foregroundStyle(viewModel.editedDraft ? .orange : .green)
                }
            }
        }
    }

    // MARK: - Images

    @ViewBuilder
    private var imagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Images")
                    .font(.title2.bold())
                Spacer()
                if viewModel.isLoadingImages {
                    ProgressView()
                        .controlSize(.small)
                }
                if viewModel.isEditing {
                    Button {
                        Task { await viewModel.uploadImage() }
                    } label: {
                        Label("Add Image", systemImage: "plus.circle")
                    }
                }
            }

            if viewModel.images.isEmpty && !viewModel.isLoadingImages {
                Text("No images")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(viewModel.images) { image in
                        imageCard(image)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func imageCard(_ image: BlogImage) -> some View {
        VStack(spacing: 4) {
            if let nsImage = viewModel.imageCache[image.filename] {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 130, height: 90)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
                    .frame(width: 130, height: 90)
                    .overlay { ProgressView().controlSize(.small) }
            }

            Text(image.filename)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)

            Text(ByteCountFormatter.string(fromByteCount: Int64(image.size), countStyle: .file))
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    let ref = viewModel.markdownReference(for: image)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(ref, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Copy markdown reference")

                if viewModel.isEditing {
                    Button(role: .destructive) {
                        Task { await viewModel.deleteImage(image) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .frame(width: 140)
    }

    // MARK: - Translations

    @ViewBuilder
    private var translationSections: some View {
        let locales = viewModel.editedTranslations.keys.sorted()
        ForEach(locales, id: \.self) { locale in
            translationSection(locale: locale)
        }
    }

    @ViewBuilder
    private func translationSection(locale: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(locale.uppercased())
                .font(.title2.bold())

            fieldRow("Title", locale: locale, keyPath: \.title, multiline: false)
            fieldRow("Summary", locale: locale, keyPath: \.summary, multiline: true)
            fieldRow("Content", locale: locale, keyPath: \.content, multiline: true)
        }
    }

    @ViewBuilder
    private func fieldRow(
        _ label: String,
        locale: String,
        keyPath: WritableKeyPath<BlogTranslation, String>,
        multiline: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if viewModel.isEditing {
                if multiline {
                    TextEditor(text: Binding(
                        get: { viewModel.editedTranslations[locale]?[keyPath: keyPath] ?? "" },
                        set: { viewModel.editedTranslations[locale]?[keyPath: keyPath] = $0 }
                    ))
                    .font(.body.monospaced())
                    .frame(minHeight: label == "Content" ? 200 : 80)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    TextField(label, text: Binding(
                        get: { viewModel.editedTranslations[locale]?[keyPath: keyPath] ?? "" },
                        set: { viewModel.editedTranslations[locale]?[keyPath: keyPath] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            } else {
                let value = viewModel.editedTranslations[locale]?[keyPath: keyPath] ?? ""
                if multiline && label == "Content" {
                    StructuredText(markdown: value)
                        .font(.body)
                        .textual.imageAttachmentLoader(viewModel.imageAttachmentLoader)
                        .id(viewModel.imageDataCache.count)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else if multiline {
                    Text(markdownToAttributedString(value))
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Text(value)
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

    private func markdownToAttributedString(_ markdown: String) -> AttributedString {
        guard !markdown.isEmpty else { return AttributedString() }
        return (try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(markdown)
    }
}
