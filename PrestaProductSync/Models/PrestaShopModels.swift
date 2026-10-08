import Foundation

// MARK: - OAuth Token Response

struct OAuthTokenResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

// MARK: - Product List (GET /products)

struct PSProductListResponse: Decodable {
    let totalItems: Int
    let limit: Int
    let items: [PSProductList]
}

struct PSProductList: Decodable {
    let productId: Int
    let enabled: Bool
    let name: String
    let quantity: Int?
    let priceTaxExcluded: Double
    let priceTaxIncluded: Double
    let category: String?
}

// MARK: - Combination List (GET /products/{productId}/combinations)

struct PSCombinationListResponse: Decodable {
    let totalItems: Int
    let items: [PSCombinationList]
}

struct PSCombinationList: Decodable {
    let productId: Int
    let combinationId: Int
    let name: String
    let isDefault: Bool
    let reference: String?
    let impactOnPriceTaxExcluded: Double
    let ecoTax: Double?
    let quantity: Int?
    let imageUrl: String?
    let attributes: [PSCombinationAttribute]?

    enum CodingKeys: String, CodingKey {
        case productId, combinationId, name
        case isDefault = "default"
        case reference, impactOnPriceTaxExcluded, ecoTax
        case quantity, imageUrl, attributes
    }
}

struct PSCombinationAttribute: Decodable {
    let attributeGroupId: Int?
    let attributeGroupName: String
    let attributeId: Int?
    let attributeName: String
}

// MARK: - Product Detail (GET /products/{productId})

struct PSProductDetail: Decodable, Sendable {
    let productId: Int
    let names: [String: String]?
    let descriptions: [String: String]?
    let shortDescriptions: [String: String]?
}

// MARK: - Blog Post List (GET /blog-posts)

struct PSBlogPostListItem: Decodable {
    let id: String
}

// MARK: - Blog Post Detail (GET /blog-posts/{id})

struct PSBlogPostDetail: Decodable {
    let id: String
    let date: String
    let draft: Bool
    let translations: [String: PSBlogTranslation]
}

struct PSBlogTranslation: Decodable {
    let title: String
    let summary: String
    let content: String
}
