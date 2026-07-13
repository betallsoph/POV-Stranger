import UIKit

enum PhotoCompressor {
    private static let maxDimension: CGFloat = 800
    private static let targetMaxBytes = 80_000

    static func compress(_ image: UIImage) -> Data? {
        let resized = resize(image, maxDimension: maxDimension)
        var quality: CGFloat = 0.7
        var data = resized.jpegData(compressionQuality: quality)

        while let current = data, current.count > targetMaxBytes, quality > 0.2 {
            quality -= 0.1
            data = resized.jpegData(compressionQuality: quality)
        }

        return data
    }

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
