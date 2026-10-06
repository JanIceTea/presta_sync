import Foundation

// MARK: - App Models

struct Product: Identifiable {
    let id: Int
    let name: String
    let price: Double // tax included
    var combinations: [Combination]
}

struct Combination: Identifiable {
    let id: Int
    let name: String // e.g. "Size - M / Color - Red"
    let price: Double // final price tax included
    let reference: String?
}

// MARK: - Product Detail

struct ProductDetail {
    let productId: Int
    var names: [String: String]
    var descriptions: [String: String]
    var shortDescriptions: [String: String]
}

// MARK: - Product Detail Export/Import

struct ProductExport: Codable {
    let productId: Int
    var names: [String: String]
    var descriptions: [String: String]
    var shortDescriptions: [String: String]
}

// MARK: - Export Models (JSON output)

struct ExportRoot: Codable {
    let products: [ExportProduct]
}

struct ExportProduct: Codable {
    let name: String
    let price: Double
    let combinations: [ExportCombination]
}

struct ExportCombination: Codable {
    let name: String
    let price: Double
}
