import Foundation
import Observation
import AppKit
import UniformTypeIdentifiers

@Observable
@MainActor
final class BlogDetailViewModel {
    var postId: String
    var isNewPost: Bool

    var post: BlogPost?
    var isLoading = false
    var errorMessage: String?

    var isEditing = false
    var isSaving = false

    var editedDate: String = ""
    var editedDraft: Bool = true
    var editedTranslations: [String: BlogTranslation] = [:]

    // Image management
    var images: [BlogImage] = []
    var imageCache: [String: NSImage] = [:]
    var imageDataCache: [String: Data] = [:]
    var isLoadingImages = false

    /// Called after a new post is successfully saved.
    var onPostCreated: ((BlogPost) -> Void)?

    private let apiService = PrestaShopAPIService()

    init(postId: String) {
        self.postId = postId
        self.isNewPost = false
    }

    static func newPost() -> BlogDetailViewModel {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())

        let vm = BlogDetailViewModel(postId: "\(dateString)-new-post")
        vm.isNewPost = true

        let emptyTranslation = BlogTranslation(title: "", summary: "", content: "")
        let newBlogPost = BlogPost(
            id: vm.postId,
            date: "\(dateString) 00:00:00",
            draft: true,
            translations: ["de": emptyTranslation, "en": emptyTranslation]
        )

        vm.post = newBlogPost
        vm.editedDate = newBlogPost.date
        vm.editedDraft = newBlogPost.draft
        vm.editedTranslations = newBlogPost.translations
        vm.isEditing = true

        return vm
    }

    func loadDetail() async {
        guard post == nil else { return }
        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await apiService.fetchBlogPost(id: postId)
            post = fetched
            editedDate = fetched.date
            editedDraft = fetched.draft
            editedTranslations = fetched.translations
            await loadImages()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Populate from a cached BlogPost instead of fetching.
    func loadFromCached(_ cached: BlogPost) {
        post = cached
        editedDate = cached.date
        editedDraft = cached.draft
        editedTranslations = cached.translations
        Task { await loadImages() }
    }

    func startEditing() {
        isEditing = true
    }

    func stopEditing() {
        isEditing = false
        if post != nil {
            post?.date = editedDate
            post?.draft = editedDraft
            post?.translations = editedTranslations
        }
    }

    func save() async {
        guard var updatedPost = post else { return }

        // Validation
        let trimmedId = postId.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedId.isEmpty {
            errorMessage = "Post ID must not be empty."
            return
        }
        if trimmedId.contains(" ") {
            errorMessage = "Post ID must not contain spaces."
            return
        }
        if editedDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Date must not be empty."
            return
        }
        let hasTitle = editedTranslations.values.contains { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !hasTitle {
            errorMessage = "At least one translation must have a title."
            return
        }

        stopEditing()

        // For new posts, the user may have edited the slug
        if isNewPost {
            updatedPost = BlogPost(
                id: trimmedId,
                date: editedDate,
                draft: editedDraft,
                translations: editedTranslations
            )
            postId = trimmedId
        } else {
            updatedPost.date = editedDate
            updatedPost.draft = editedDraft
            updatedPost.translations = editedTranslations
        }

        isSaving = true
        errorMessage = nil

        do {
            try await apiService.saveBlogPost(updatedPost)
            post = updatedPost

            if isNewPost {
                isNewPost = false
                onPostCreated?(updatedPost)
            }
        } catch {
            errorMessage = error.localizedDescription
            // Return to editing so the user can fix and retry
            isEditing = true
        }

        isSaving = false
    }

    // MARK: - Images

    func loadImages() async {
        guard !isNewPost else { return }
        isLoadingImages = true

        do {
            images = try await apiService.fetchBlogImages(postId: postId)
            for image in images {
                await loadThumbnail(for: image)
            }
        } catch {
            // Non-critical — images section just stays empty
        }

        isLoadingImages = false
    }

    private func loadThumbnail(for image: BlogImage) async {
        guard imageCache[image.filename] == nil else { return }
        do {
            let data = try await apiService.fetchBlogImageData(postId: postId, filename: image.filename)
            if let nsImage = NSImage(data: data) {
                imageCache[image.filename] = nsImage
                imageDataCache[image.filename] = data
            }
        } catch {
            // Skip failed thumbnails
        }
    }

    func uploadImage() async {
        let panel = NSOpenPanel()
        panel.title = "Upload Image"
        panel.allowedContentTypes = [.jpeg, .png, .gif, .image]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let filename = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let contentType: String
        switch ext {
        case "jpg", "jpeg": contentType = "image/jpeg"
        case "png": contentType = "image/png"
        case "gif": contentType = "image/gif"
        case "webp": contentType = "image/webp"
        case "avif": contentType = "image/avif"
        default: contentType = "application/octet-stream"
        }

        do {
            let imageData = try Data(contentsOf: url)
            let uploaded = try await apiService.uploadBlogImage(
                postId: postId,
                filename: filename,
                imageData: imageData,
                contentType: contentType
            )

            // Replace if filename already exists, otherwise append
            if let index = images.firstIndex(where: { $0.filename == uploaded.filename }) {
                images[index] = uploaded
            } else {
                images.append(uploaded)
            }

            // Load thumbnail
            if let nsImage = NSImage(data: imageData) {
                imageCache[uploaded.filename] = nsImage
                imageDataCache[uploaded.filename] = imageData
            }
        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
        }
    }

    func deleteImage(_ image: BlogImage) async {
        do {
            try await apiService.deleteBlogImage(postId: postId, filename: image.filename)
            images.removeAll { $0.filename == image.filename }
            imageCache.removeValue(forKey: image.filename)
            imageDataCache.removeValue(forKey: image.filename)
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
        }
    }

    func markdownReference(for image: BlogImage) -> String {
        "![](images/\(image.filename))"
    }

    var imageAttachmentLoader: BlogImageAttachmentLoader {
        BlogImageAttachmentLoader(imageData: imageDataCache)
    }

    var displayTitle: String {
        let translations = post?.translations ?? editedTranslations
        if let en = translations["en"], !en.title.isEmpty { return en.title }
        if let de = translations["de"], !de.title.isEmpty { return de.title }
        if let first = translations.values.first, !first.title.isEmpty { return first.title }
        return postId
    }
}
