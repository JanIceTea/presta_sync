import Foundation
import Observation

@Observable
@MainActor
final class BlogListViewModel {
    var posts: [BlogPost] = []
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
        cacheDirectory.appendingPathComponent("blog-cache.json")
    }

    init() {
        loadFromCache()
    }

    var filteredPosts: [BlogPost] {
        if searchText.isEmpty { return posts }
        return posts.filter { post in
            post.id.localizedCaseInsensitiveContains(searchText)
            || post.translations.values.contains {
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    func fetchPosts() async {
        isLoading = true
        errorMessage = nil

        do {
            posts = try await apiService.fetchAllBlogPosts()
            lastFetchedAt = Date()
            saveToCache()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func deletePost(id: String) async {
        do {
            try await apiService.deleteBlogPost(id: id)
            posts.removeAll { $0.id == id }
            saveToCache()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addPost(_ post: BlogPost) {
        // Avoid duplicates
        if !posts.contains(where: { $0.id == post.id }) {
            posts.insert(post, at: 0)
        }
        saveToCache()
    }

    // MARK: - Cache

    private func loadFromCache() {
        let url = Self.cacheFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cache = try decoder.decode(BlogCache.self, from: data)
            posts = cache.posts
            lastFetchedAt = cache.fetchedAt
        } catch {
            // Ignore corrupt cache
        }
    }

    private func saveToCache() {
        let cache = BlogCache(fetchedAt: lastFetchedAt ?? Date(), posts: posts)
        do {
            let dir = Self.cacheDirectory
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cache)
            try data.write(to: Self.cacheFileURL, options: .atomic)
        } catch {
            // Non-critical
        }
    }
}
