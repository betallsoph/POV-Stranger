import Foundation
import WidgetKit

enum WidgetDataStore {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupConstants.identifier)
    }

    private static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupConstants.identifier
        )
    }

    static func update(from session: StrangerSession) {
        let latestSlot = session.slots
            .filter { $0.theirPhotoData != nil }
            .sorted { ($0.theirCapturedAt ?? .distantPast) > ($1.theirCapturedAt ?? .distantPast) }
            .first

        var photoFilename: String?
        if let photoData = latestSlot?.theirPhotoData {
            photoFilename = savePhoto(photoData)
        }

        let snapshot = WidgetSnapshot(
            hasActiveSession: !session.isExpired,
            theirPhotoFilename: photoFilename,
            distanceKm: session.partnerDistanceKm,
            weatherSummary: session.partnerWeatherSummary,
            localTimeDescription: "\(session.partnerLocalTime) · \(session.partnerCountryName)",
            countryName: session.partnerCountryName,
            hourIndex: latestSlot?.hourIndex ?? session.currentHourIndex,
            expiresAt: session.expiresAt,
            updatedAt: .now
        )

        saveSnapshot(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func clear() {
        saveSnapshot(.empty)
        removePartnerPhoto()
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func loadSnapshot() -> WidgetSnapshot {
        guard
            let defaults,
            let data = defaults.data(forKey: AppGroupConstants.snapshotKey),
            let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else {
            return .empty
        }
        return snapshot
    }

    static func loadPartnerPhoto() -> Data? {
        guard
            let url = partnerPhotoURL,
            FileManager.default.fileExists(atPath: url.path)
        else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    // MARK: - Private

    private static var partnerPhotoURL: URL? {
        containerURL?.appendingPathComponent(AppGroupConstants.partnerPhotoFilename)
    }

    @discardableResult
    private static func savePhoto(_ data: Data) -> String? {
        guard let url = partnerPhotoURL else { return nil }
        try? data.write(to: url, options: .atomic)
        return AppGroupConstants.partnerPhotoFilename
    }

    private static func removePartnerPhoto() {
        guard let url = partnerPhotoURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func saveSnapshot(_ snapshot: WidgetSnapshot) {
        guard
            let defaults,
            let data = try? JSONEncoder().encode(snapshot)
        else {
            return
        }
        defaults.set(data, forKey: AppGroupConstants.snapshotKey)
    }
}
