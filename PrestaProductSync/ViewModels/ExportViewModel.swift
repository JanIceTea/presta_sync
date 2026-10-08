import Foundation
import Observation
import AppKit

@Observable
@MainActor
final class ExportViewModel {
    var selectedProductIds: Set<Int> = []
    var isExporting = false
    var exportProgress: (current: Int, total: Int)?
    var errorMessage: String?

    private let apiService = PrestaShopAPIService()

    func selectAll(from products: [Product]) {
        selectedProductIds = Set(products.map(\.id))
    }

    func deselectAll() {
        selectedProductIds.removeAll()
    }

    func isSelected(_ product: Product) -> Bool {
        selectedProductIds.contains(product.id)
    }

    func toggle(_ product: Product) {
        if selectedProductIds.contains(product.id) {
            selectedProductIds.remove(product.id)
        } else {
            selectedProductIds.insert(product.id)
        }
    }

    func exportMarkdown(products: [Product]) async {
        let selectedProducts = products.filter { selectedProductIds.contains($0.id) }
        guard !selectedProducts.isEmpty else { return }

        // Pick folder
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        panel.message = "Choose a folder to export \(selectedProducts.count) product(s)"

        guard panel.runModal() == .OK, let folderURL = panel.url else { return }

        isExporting = true
        exportProgress = (current: 0, total: selectedProducts.count)
        errorMessage = nil

        do {
            for (index, product) in selectedProducts.enumerated() {
                exportProgress = (current: index, total: selectedProducts.count)

                // Fetch full product detail from API
                let detail = try await apiService.fetchProductDetail(id: product.id)

                // Convert HTML descriptions to markdown
                let names = detail.names
                let descriptions = detail.descriptions.mapValues { ProductDetailViewModel.htmlToMarkdown($0) }
                let shortDescriptions = detail.shortDescriptions.mapValues { ProductDetailViewModel.htmlToMarkdown($0) }

                // Build markdown content
                let markdown = ProductDetailViewModel.buildMarkdownExport(
                    productId: detail.productId,
                    names: names,
                    descriptions: descriptions,
                    shortDescriptions: shortDescriptions
                )

                // Write file
                let safeName = product.name.sanitizedForFilename()
                let fileURL = folderURL.appendingPathComponent("\(safeName).md")
                try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
            }

            exportProgress = (current: selectedProducts.count, total: selectedProducts.count)
        } catch {
            errorMessage = error.localizedDescription
        }

        isExporting = false
    }
}
