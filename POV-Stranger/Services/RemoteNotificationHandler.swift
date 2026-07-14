import Foundation
import SwiftData
import UIKit
import WidgetKit

@MainActor
final class RemoteNotificationHandler {
    static let shared = RemoteNotificationHandler()

    private var modelContainer: ModelContainer?
    private let client = AtlasHTTPClient()

    private init() {}

    func configure(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func handleRemoteNotification(
        _ userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        guard let type = userInfo["type"] as? String else {
            return .noData
        }

        switch type {
        case "partner.photo":
            return await handlePartnerPhoto(userInfo)
        case "session.farewell", "session.ended":
            return await handleSessionSync(userInfo)
        default:
            return .noData
        }
    }

    private func handlePartnerPhoto(_ userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        guard let sessionId = userInfo["sessionId"] as? String else {
            return .noData
        }

        guard let hourIndex = parseHourIndex(from: userInfo) else {
            return .noData
        }

        guard let modelContainer else {
            return .failed
        }

        let context = ModelContext(modelContainer)
        let targetId = sessionId
        let descriptor = FetchDescriptor<StrangerSession>(
            predicate: #Predicate { $0.remoteSessionId == targetId }
        )

        guard
            let session = try? context.fetch(descriptor).first,
            let slot = session.slot(for: hourIndex)
        else {
            return .noData
        }

        let body = GetPartnerPhotoRequest(sessionId: sessionId, hourIndex: hourIndex)

        do {
            let response: GetPartnerPhotoResponse = try await client.post(
                function: "getPartnerPhoto",
                body: body
            )

            if let error = response.error {
                #if DEBUG
                print("Partner photo fetch failed: \(error)")
                #endif
                return .failed
            }

            guard
                let photo = response.photo,
                let data = Data(base64Encoded: photo.imageBase64)
            else {
                return .noData
            }

            slot.theirPhotoData = data
            slot.theirCapturedAt = photo.capturedAt ?? .now
            try context.save()
            WidgetDataStore.update(from: session)
            return .newData
        } catch {
            #if DEBUG
            print("Partner photo push handler failed: \(error.localizedDescription)")
            #endif
            return .failed
        }
    }

    private func handleSessionSync(_ userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        guard AtlasConfig.isConfigured, AtlasAuthTokenStore.isSignedIn else {
            return .noData
        }

        guard let modelContainer else {
            return .failed
        }

        let context = ModelContext(modelContainer)

        if let sessionId = userInfo["sessionId"] as? String {
            let targetId = sessionId
            let descriptor = FetchDescriptor<StrangerSession>(
                predicate: #Predicate { $0.remoteSessionId == targetId }
            )
            if let session = try? context.fetch(descriptor).first {
                return await syncSession(session, context: context)
            }
        }

        let descriptor = FetchDescriptor<StrangerSession>()
        guard let session = try? context.fetch(descriptor).first(where: { $0.status != .ended }) else {
            return .noData
        }

        return await syncSession(session, context: context)
    }

    private func syncSession(
        _ session: StrangerSession,
        context: ModelContext
    ) async -> UIBackgroundFetchResult {
        struct EmptyBody: Encodable {}

        do {
            let response: GetActiveSessionResponse = try await client.post(
                function: "getActiveSession",
                body: EmptyBody()
            )

            if let remote = response.session {
                session.applyRemoteSync(remote)
            } else if session.status != .ended {
                session.status = .ended
            }

            try context.save()

            if session.status == .ended {
                WidgetDataStore.clear()
            } else {
                WidgetDataStore.update(from: session)
            }

            return .newData
        } catch {
            #if DEBUG
            print("Session sync failed: \(error.localizedDescription)")
            #endif
            return .failed
        }
    }

    private func parseHourIndex(from userInfo: [AnyHashable: Any]) -> Int? {
        if let hourIndex = userInfo["hourIndex"] as? Int {
            return hourIndex
        }
        if let number = userInfo["hourIndex"] as? NSNumber {
            return number.intValue
        }
        return nil
    }
}
