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
    var lastFetchedAt: Date?

    private let apiService = PrestaShopAPIService()

    private static var cacheDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("PrestaProductSync", isDirectory: true)
    }

    private static var cacheFileURL: URL {
        cacheDirectory.appendingPathComponent("products-cache.json")
    }

    init() {
        loadFromCache()
    }

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
            lastFetchedAt = Date()
            saveToCache()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Cache

    private func loadFromCache() {
        let url = Self.cacheFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let data = try Data(contentsOf: url)
            let cache = try JSONDecoder.withISO8601.decode(ProductCache.self, from: data)
            products = cache.products
            lastFetchedAt = cache.fetchedAt
        } catch {
            // Cache is corrupt — ignore and let user fetch fresh
        }
    }

    private func saveToCache() {
        let cache = ProductCache(fetchedAt: lastFetchedAt ?? Date(), products: products)
        do {
            let dir = Self.cacheDirectory
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder.withISO8601.encode(cache)
            try data.write(to: Self.cacheFileURL, options: .atomic)
        } catch {
            // Non-critical — just skip caching
        }
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

// MARK: - JSON Coder helpers

private extension JSONEncoder {
    static let withISO8601: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

private extension JSONDecoder {
    static let withISO8601: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
