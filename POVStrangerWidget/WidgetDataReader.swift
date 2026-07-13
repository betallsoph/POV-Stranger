import Foundation
import UIKit

enum WidgetDataReader {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupConstants.identifier)
    }

    private static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupConstants.identifier
        )
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
        guard let url = containerURL?.appendingPathComponent(AppGroupConstants.partnerPhotoFilename) else {
            return nil
        }
        return try? Data(contentsOf: url)
    }
}
