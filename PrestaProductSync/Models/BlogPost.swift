import Foundation

// MARK: - App Models

struct BlogPost: Identifiable, Codable {
    let id: String
    var date: String
    var draft: Bool
    var translations: [String: BlogTranslation]
}

struct BlogTranslation: Codable, Equatable {
    var title: String
    var summary: String
    var content: String
}

// MARK: - Blog Image

struct BlogImage: Identifiable, Codable {
    let filename: String
    let contentType: String
    let size: Int
    let modified: String

    var id: String { filename }
}

// MARK: - Blog Cache

struct BlogCache: Codable {
    let fetchedAt: Date
    let posts: [BlogPost]
}
