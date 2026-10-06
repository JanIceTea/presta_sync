import Foundation
import Observation
import AppKit
import UniformTypeIdentifiers

@Observable
@MainActor
final class ProductListViewModel {
    var products: [Product] = []
    var isLoading = false
    var errorMessage: String?
    var searchText = ""

    private let apiService = PrestaShopAPIService()

    var filteredProducts: [Product] {
        if searchText.isEmpty {
            return products
        }
        return products.filter { product in
            product.name.localizedCaseInsensitiveContains(searchText)
            || product.combinations.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var productCount: Int {
        products.count
    }

    var combinationCount: Int {
        products.reduce(0) { $0 + $1.combinations.count }
    }

    func fetchProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            products = try await apiService.fetchAllProducts()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func removeProduct(id: Int) {
        products.removeAll { $0.id == id }
    }

    func removeCombination(productId: Int, combinationId: Int) {
        guard let index = products.firstIndex(where: { $0.id == productId }) else { return }
        products[index].combinations.removeAll { $0.id == combinationId }
    }

    func saveJSON() {
        let exportProducts = products.map { product in
            ExportProduct(
                name: product.name,
                price: product.price,
                combinations: product.combinations.map { combination in
                    ExportCombination(name: combination.name, price: combination.price)
                }
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let exportRoot = ExportRoot(products: exportProducts)

        guard let jsonData = try? encoder.encode(exportRoot) else {
            errorMessage = "Failed to encode products as JSON"
            return
        }

        let savePanel = NSSavePanel()
        savePanel.title = "Save Product List"
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "products.json"

        guard savePanel.runModal() == .OK, let url = savePanel.url else { return }

        do {
            try jsonData.write(to: url)
        } catch {
            errorMessage = "Failed to save file: \(error.localizedDescription)"
        }
    }
}
