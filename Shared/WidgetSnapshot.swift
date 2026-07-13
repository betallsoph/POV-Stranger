import Foundation

enum AppGroupConstants {
    static let identifier = "group.antt.POV-Stranger"
    static let snapshotKey = "widget.snapshot"
    static let partnerPhotoFilename = "partner-latest.jpg"
}

struct WidgetSnapshot: Codable, Sendable {
    var hasActiveSession: Bool
    var theirPhotoFilename: String?
    var distanceKm: Double?
    var weatherSummary: String?
    var localTimeDescription: String?
    var countryName: String?
    var hourIndex: Int?
    var expiresAt: Date?
    var updatedAt: Date

    static var empty: WidgetSnapshot {
        WidgetSnapshot(
            hasActiveSession: false,
            theirPhotoFilename: nil,
            distanceKm: nil,
            weatherSummary: nil,
            localTimeDescription: nil,
            countryName: nil,
            hourIndex: nil,
            expiresAt: nil,
            updatedAt: .now
        )
    }
}
