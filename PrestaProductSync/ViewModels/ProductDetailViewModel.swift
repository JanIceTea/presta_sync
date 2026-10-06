import Foundation
import Observation

enum ImportError: LocalizedError {
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            return "File is not valid UTF-8 text"
        }
    }
}

@Observable
@MainActor
final class ProductDetailViewModel {
    let productId: Int
    let productName: String

    var detail: ProductDetail?
    var isLoading = false
    var errorMessage: String?

    var isEditing = false
    var editedNames: [String: String] = [:]
    var editedDescriptions: [String: String] = [:]
    var editedShortDescriptions: [String: String] = [:]

    private let apiService = PrestaShopAPIService()

    init(productId: Int, productName: String) {
        self.productId = productId
        self.productName = productName
    }

    func loadDetail() async {
        guard detail == nil else { return }
        isLoading = true
        errorMessage = nil

        do {
            detail = try await apiService.fetchProductDetail(id: productId)
            if let detail {
                editedNames = detail.names
                editedDescriptions = detail.descriptions.mapValues { Self.htmlToMarkdown($0) }
                editedShortDescriptions = detail.shortDescriptions.mapValues { Self.htmlToMarkdown($0) }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func startEditing() {
        isEditing = true
    }

    func stopEditing() {
        isEditing = false
        if detail != nil {
            detail?.names = editedNames
            detail?.descriptions = editedDescriptions
            detail?.shortDescriptions = editedShortDescriptions
        }
    }

    var isSaving = false

    func save() async {
        guard let detail else { return }
        stopEditing()

        isSaving = true
        errorMessage = nil

        do {
            try await apiService.updateProduct(
                id: detail.productId,
                names: editedNames,
                descriptions: editedDescriptions.mapValues { Self.markdownToHtml($0) },
                shortDescriptions: editedShortDescriptions.mapValues { Self.markdownToHtml($0) }
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    // MARK: - Export

    func exportJSON() throws -> Data {
        let export = ProductExport(
            productId: productId,
            names: editedNames,
            descriptions: editedDescriptions,
            shortDescriptions: editedShortDescriptions
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }

    func exportMarkdown() -> String {
        var lines: [String] = []
        lines.append("---")
        lines.append("productId: \(productId)")
        lines.append("---")

        func appendSection(_ title: String, entries: [String: String]) {
            lines.append("")
            lines.append("# \(title)")
            for locale in entries.keys.sorted() {
                lines.append("")
                lines.append("## \(locale)")
                lines.append(entries[locale] ?? "")
            }
        }

        appendSection("Names", entries: editedNames)
        appendSection("Short Descriptions", entries: editedShortDescriptions)
        appendSection("Descriptions", entries: editedDescriptions)

        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Import

    func importFile(from url: URL) throws {
        let data = try Data(contentsOf: url)

        if url.pathExtension.lowercased() == "json" {
            let export = try JSONDecoder().decode(ProductExport.self, from: data)
            editedNames = export.names
            editedDescriptions = export.descriptions
            editedShortDescriptions = export.shortDescriptions
        } else {
            guard let text = String(data: data, encoding: .utf8) else {
                throw ImportError.invalidEncoding
            }
            try parseMarkdown(text)
        }
    }

    private func parseMarkdown(_ text: String) throws {
        // Strip frontmatter
        let body: String
        if text.hasPrefix("---") {
            let parts = text.components(separatedBy: "---")
            // parts[0] is empty, parts[1] is frontmatter, parts[2...] is body
            if parts.count >= 3 {
                body = parts.dropFirst(2).joined(separator: "---")
            } else {
                body = text
            }
        } else {
            body = text
        }

        // Split by "# " headers into sections
        let rawSections = ("\n" + body).components(separatedBy: "\n# ")

        for section in rawSections.dropFirst() {
            let sectionLines = section.components(separatedBy: "\n")
            guard let title = sectionLines.first?.trimmingCharacters(in: .whitespaces) else { continue }

            var entries: [String: String] = [:]
            var currentLocale: String?
            var currentContent: [String] = []

            for line in sectionLines.dropFirst() {
                if line.hasPrefix("## ") {
                    // Save previous locale
                    if let locale = currentLocale {
                        entries[locale] = currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    currentLocale = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    currentContent = []
                } else {
                    currentContent.append(line)
                }
            }
            // Save last locale
            if let locale = currentLocale {
                entries[locale] = currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            }

            switch title {
            case "Names":
                editedNames = entries
            case "Descriptions":
                editedDescriptions = entries
            case "Short Descriptions":
                editedShortDescriptions = entries
            default:
                break
            }
        }
    }

    // MARK: - HTML → Markdown

    static func htmlToMarkdown(_ html: String) -> String {
        guard !html.isEmpty else { return "" }

        var md = html
        // Bold
        md = md.replacingOccurrences(of: "<b>", with: "**", options: .caseInsensitive)
        md = md.replacingOccurrences(of: "</b>", with: "**", options: .caseInsensitive)
        md = md.replacingOccurrences(of: "<strong>", with: "**", options: .caseInsensitive)
        md = md.replacingOccurrences(of: "</strong>", with: "**", options: .caseInsensitive)
        // Italic
        md = md.replacingOccurrences(of: "<i>", with: "*", options: .caseInsensitive)
        md = md.replacingOccurrences(of: "</i>", with: "*", options: .caseInsensitive)
        md = md.replacingOccurrences(of: "<em>", with: "*", options: .caseInsensitive)
        md = md.replacingOccurrences(of: "</em>", with: "*", options: .caseInsensitive)
        // Headers → bold
        for i in 1...6 {
            md = md.replacingOccurrences(of: "<h\(i)>", with: "\n**", options: .caseInsensitive)
            md = md.replacingOccurrences(of: "</h\(i)>", with: "**\n", options: .caseInsensitive)
        }
        // Paragraphs and line breaks
        md = md.replacingOccurrences(of: "</p>", with: "\n", options: .caseInsensitive)
        md = md.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
        // Strip remaining tags
        md = md.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // Clean up excessive newlines
        md = md.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        md = md.trimmingCharacters(in: .whitespacesAndNewlines)

        return md
    }

    // MARK: - Markdown → HTML

    static func markdownToHtml(_ markdown: String) -> String {
        guard !markdown.isEmpty else { return "" }

        let paragraphs = markdown.components(separatedBy: "\n\n")

        let htmlParagraphs = paragraphs.map { paragraph -> String in
            var text = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return "" }

            // Bold **text** → <b>text</b>
            text = text.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<b>$1</b>", options: .regularExpression)
            // Italic *text* → <i>text</i>
            text = text.replacingOccurrences(of: "(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)", with: "<i>$1</i>", options: .regularExpression)

            let lines = text.components(separatedBy: "\n")
            return lines.map { "<p>\($0)</p>" }.joined(separator: "\n")
        }

        return htmlParagraphs.filter { !$0.isEmpty }.joined(separator: "\n")
    }
}
