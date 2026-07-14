import UIKit
import SensitiveContentAnalysis

enum ContentSafetyChecker {
    enum CheckError: LocalizedError {
        case sensitiveContent
        case analysisFailed

        var errorDescription: String? {
            switch self {
            case .sensitiveContent:
                "This photo can't be shared. Choose a different image."
            case .analysisFailed:
                "Couldn't verify this photo. Try again."
            }
        }
    }

    static func validate(_ image: UIImage) async throws {
        guard let cgImage = image.cgImage else {
            throw CheckError.analysisFailed
        }

        let analyzer = SCSensitivityAnalyzer()
        guard analyzer.analysisPolicy != .disabled else {
            // User disabled Sensitive Content Warning in Settings — cannot analyze on device.
            return
        }

        let response = try await analyzer.analyzeImage(cgImage)
        if response.isSensitive {
            throw CheckError.sensitiveContent
        }
    }
}
