import SwiftUI
import Textual
import ImageIO

/// A custom `Attachment` that renders a cached blog image inline in StructuredText.
struct BlogImageAttachment: Attachment, @unchecked Sendable {
    let filename: String
    let cgImage: CGImage
    let imageSize: CGSize

    var description: String { filename }

    var body: some View {
        SwiftUI.Image(decorative: cgImage, scale: 1.0)
            .resizable()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, in _: TextEnvironmentValues) -> CGSize {
        guard let proposedWidth = proposal.width else {
            return imageSize
        }
        guard imageSize.height > 0 else { return .zero }
        let aspect = imageSize.width / imageSize.height
        let width = min(proposedWidth, imageSize.width)
        let height = width / aspect
        return CGSize(width: width, height: height)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.filename == rhs.filename
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(filename)
    }
}

/// An `AttachmentLoader` that resolves `images/filename` URLs from an in-memory data cache.
///
/// Blog post markdown references images as `![](images/hero.jpg)`. This loader intercepts
/// those URLs and creates attachments from the cached image data, avoiding extra network requests.
struct BlogImageAttachmentLoader: AttachmentLoader {
    let imageData: [String: Data]

    func attachment(
        for url: URL,
        text: String,
        environment: ColorEnvironmentValues
    ) async throws -> BlogImageAttachment {
        let filename = url.lastPathComponent

        guard let data = imageData[filename] else {
            throw URLError(.fileDoesNotExist)
        }

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw URLError(.cannotDecodeContentData)
        }

        let size = CGSize(width: cgImage.width, height: cgImage.height)
        return BlogImageAttachment(filename: filename, cgImage: cgImage, imageSize: size)
    }
}
