import Foundation

actor PrestaShopAPIService {

    private var cachedToken: String?
    private var tokenExpiry: Date?

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()

    // MARK: - Configuration

    private func baseURL() throws -> URL {
        guard var urlString = KeychainService.retrieve(for: .shopURL),
              !urlString.isEmpty else {
            throw APIError.missingConfiguration("Shop URL not configured")
        }

        // Ensure scheme is present
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://" + urlString
        }

        // Remove trailing slash for consistent path building
        while urlString.hasSuffix("/") {
            urlString.removeLast()
        }

        guard let url = URL(string: urlString) else {
            throw APIError.missingConfiguration("Invalid Shop URL")
        }
        return url
    }

    private func clientCredentials() throws -> (id: String, secret: String) {
        guard let clientID = KeychainService.retrieve(for: .clientID),
              let clientSecret = KeychainService.retrieve(for: .clientSecret) else {
            throw APIError.missingConfiguration("Client credentials not configured")
        }
        return (clientID, clientSecret)
    }

    // MARK: - OAuth Token

    private func getAccessToken() async throws -> String {
        // Return cached token if still valid
        if let token = cachedToken, let expiry = tokenExpiry, Date() < expiry {
            return token
        }

        let base = try baseURL()
        let credentials = try clientCredentials()
        let tokenURL = base.appendingPathComponent("admin-api/access_token")

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParts = [
            "grant_type=client_credentials",
            "client_id=\(credentials.id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? credentials.id)",
            "client_secret=\(credentials.secret.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? credentials.secret)",
            "scope=product_read+product_write+blog_post_read+blog_post_write"
        ]
        let body = bodyParts.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        let tokenResponse: OAuthTokenResponse
        do {
            tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "non-UTF8 data"
            throw APIError.decodingFailed("Token response: \(raw)")
        }
        cachedToken = tokenResponse.accessToken
        // Expire 60 seconds early to avoid edge cases
        tokenExpiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn - 60))

        return tokenResponse.accessToken
    }

    // MARK: - Test Connection

    func testConnection() async throws {
        _ = try await getAccessToken()
    }

    // MARK: - Fetch Products

    func fetchAllProducts() async throws -> [Product] {
        var allProducts: [PSProductList] = []
        var page = 1

        // Fetch all pages of products
        while true {
            let response = try await fetchProductsPage(page: page)
            allProducts.append(contentsOf: response.items)
            // Check if we've fetched all items
            if allProducts.count >= response.totalItems { break }
            page += 1
        }

        // Build Product models, try fetching combinations for each
        var products: [Product] = []
        for psProduct in allProducts {
            let psCombinations = try await fetchCombinations(for: psProduct.productId)

            var combinations: [Combination] = []
            if !psCombinations.isEmpty {
                let taxMultiplier: Double = psProduct.priceTaxExcluded > 0
                    ? psProduct.priceTaxIncluded / psProduct.priceTaxExcluded
                    : 1.0

                combinations = psCombinations.map { psComb in
                    let combinationName = buildCombinationName(from: psComb)
                    let finalPrice = (psProduct.priceTaxExcluded + psComb.impactOnPriceTaxExcluded) * taxMultiplier
                    return Combination(
                        id: psComb.combinationId,
                        name: combinationName,
                        price: (finalPrice * 100).rounded() / 100,
                        reference: psComb.reference
                    )
                }
            }

            let product = Product(
                id: psProduct.productId,
                name: psProduct.name,
                price: psProduct.priceTaxIncluded,
                combinations: combinations
            )
            products.append(product)
        }

        return products
    }

    // MARK: - Fetch Product Detail

    func fetchProductDetail(id: Int) async throws -> ProductDetail {
        let base = try baseURL()
        let url = base.appendingPathComponent("admin-api/products/\(id)")

        let token = try await getAccessToken()
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        let psDetail: PSProductDetail
        do {
            psDetail = try JSONDecoder().decode(PSProductDetail.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "non-UTF8 data"
            throw APIError.decodingFailed("Product detail response: \(raw.prefix(500))")
        }

        return ProductDetail(
            productId: psDetail.productId,
            names: psDetail.names ?? [:],
            descriptions: psDetail.descriptions ?? [:],
            shortDescriptions: psDetail.shortDescriptions ?? [:]
        )
    }

    // MARK: - Update Product

    func updateProduct(
        id: Int,
        names: [String: String],
        descriptions: [String: String],
        shortDescriptions: [String: String]
    ) async throws {
        let base = try baseURL()
        let url = base.appendingPathComponent("admin-api/products/\(id)")

        let token = try await getAccessToken()
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "names": names,
            "descriptions": descriptions,
            "shortDescriptions": shortDescriptions
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
    }

    // MARK: - Blog Posts

    func fetchBlogPostIds() async throws -> [String] {
        let base = try baseURL()
        let url = base.appendingPathComponent("admin-api/blog-posts")

        let token = try await getAccessToken()
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        do {
            let items = try JSONDecoder().decode([PSBlogPostListItem].self, from: data)
            return items.map(\.id)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "non-UTF8 data"
            throw APIError.decodingFailed("Blog post list: \(raw.prefix(500))")
        }
    }

    func fetchBlogPost(id: String) async throws -> BlogPost {
        let base = try baseURL()
        let url = base.appendingPathComponent("admin-api/blog-posts/\(id)")

        let token = try await getAccessToken()
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        do {
            let psDetail = try JSONDecoder().decode(PSBlogPostDetail.self, from: data)
            return BlogPost(
                id: psDetail.id,
                date: psDetail.date,
                draft: psDetail.draft,
                translations: psDetail.translations.mapValues {
                    BlogTranslation(title: $0.title, summary: $0.summary, content: $0.content)
                }
            )
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "non-UTF8 data"
            throw APIError.decodingFailed("Blog post detail: \(raw.prefix(500))")
        }
    }

    func fetchAllBlogPosts() async throws -> [BlogPost] {
        let ids = try await fetchBlogPostIds()
        var posts: [BlogPost] = []
        for id in ids {
            let post = try await fetchBlogPost(id: id)
            posts.append(post)
        }
        return posts
    }

    func saveBlogPost(_ post: BlogPost) async throws {
        let base = try baseURL()
        let url = base.appendingPathComponent("admin-api/blog-posts/\(post.id)")

        let token = try await getAccessToken()
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "id": post.id,
            "date": post.date,
            "draft": post.draft,
            "translations": post.translations.mapValues { translation -> [String: String] in
                [
                    "title": translation.title,
                    "summary": translation.summary,
                    "content": translation.content
                ]
            }
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
    }

    func deleteBlogPost(id: String) async throws {
        let base = try baseURL()
        let url = base.appendingPathComponent("admin-api/blog-posts/\(id)")

        let token = try await getAccessToken()
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
    }

    // MARK: - Blog Post Images

    func fetchBlogImages(postId: String) async throws -> [BlogImage] {
        let base = try baseURL()
        let url = base.appendingPathComponent("admin-api/blog-posts/\(postId)/images")

        let token = try await getAccessToken()
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        do {
            return try JSONDecoder().decode([BlogImage].self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "non-UTF8 data"
            throw APIError.decodingFailed("Blog images: \(raw.prefix(500))")
        }
    }

    func fetchBlogImageData(postId: String, filename: String) async throws -> Data {
        let base = try baseURL()
        let url = base.appendingPathComponent("admin-api/blog-posts/\(postId)/images/\(filename)")

        let token = try await getAccessToken()
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        return data
    }

    func uploadBlogImage(postId: String, filename: String, imageData: Data, contentType: String) async throws -> BlogImage {
        let base = try baseURL()
        let url = base.appendingPathComponent("admin-api/blog-posts/\(postId)/images/\(filename)")

        let token = try await getAccessToken()
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        do {
            return try JSONDecoder().decode(BlogImage.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "non-UTF8 data"
            throw APIError.decodingFailed("Blog image upload: \(raw.prefix(500))")
        }
    }

    func deleteBlogImage(postId: String, filename: String) async throws {
        let base = try baseURL()
        let url = base.appendingPathComponent("admin-api/blog-posts/\(postId)/images/\(filename)")

        let token = try await getAccessToken()
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
    }

    // MARK: - Private Helpers

    private func fetchProductsPage(page: Int) async throws -> PSProductListResponse {
        let base = try baseURL()
        var components = URLComponents(url: base.appendingPathComponent("admin-api/products"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "limit", value: "50")]

        let token = try await getAccessToken()
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        do {
            return try JSONDecoder().decode(PSProductListResponse.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "non-UTF8 data"
            throw APIError.decodingFailed("Products response: \(raw.prefix(500))")
        }
    }

    private func fetchCombinations(for productId: Int) async throws -> [PSCombinationList] {
        let base = try baseURL()
        let url = base.appendingPathComponent("admin-api/products/\(productId)/combinations")

        let token = try await getAccessToken()
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        do {
            let envelope = try JSONDecoder().decode(PSCombinationListResponse.self, from: data)
            return envelope.items
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "non-UTF8 data"
            throw APIError.decodingFailed("Combinations response: \(raw.prefix(500))")
        }
    }

    private func buildCombinationName(from combination: PSCombinationList) -> String {
        guard let attributes = combination.attributes, !attributes.isEmpty else {
            return combination.name
        }
        return attributes
            .map { "\($0.attributeGroupName) - \($0.attributeName)" }
            .joined(separator: " / ")
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        let body = String(data: data, encoding: .utf8) ?? ""
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            cachedToken = nil
            tokenExpiry = nil
            throw APIError.unauthorized
        case 403:
            throw APIError.httpError(403, detail: body.prefix(1000).description)
        case 404:
            throw APIError.notFound
        default:
            throw APIError.httpError(httpResponse.statusCode, detail: body.prefix(1000).description)
        }
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case missingConfiguration(String)
    case invalidResponse
    case unauthorized
    case notFound
    case httpError(Int, detail: String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration(let detail):
            return "Configuration missing: \(detail)"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Authentication failed. Check your Client ID and Secret."
        case .notFound:
            return "Resource not found"
        case .httpError(let code, let detail):
            return "HTTP \(code): \(detail)"
        case .decodingFailed(let detail):
            return "Failed to parse response: \(detail)"
        }
    }
}
