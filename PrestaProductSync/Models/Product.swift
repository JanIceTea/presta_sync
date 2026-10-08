import Foundation

// MARK: - App Models

struct Product: Identifiable, Codable {
    let id: Int
    let name: String
    let price: Double // tax included
    var combinations: [Combination]
}

struct Combination: Identifiable, Codable {
    let id: Int
    let name: String // e.g. "Size - M / Color - Red"
    let price: Double // final price tax included
    let reference: String?
}

// MARK: - Product Cache

struct ProductCache: Codable {
    let fetchedAt: Date
    let products: [Product]
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

// MARK: - Filename Helpers

extension String {
    /// Replaces characters unsafe for filenames with hyphens and trims.
    func sanitizedForFilename() -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let parts = unicodeScalars.map { forbidden.contains($0) ? "-" : String($0) }
        return parts.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
