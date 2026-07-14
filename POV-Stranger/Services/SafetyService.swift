import Foundation
import SwiftData

struct SafetyService {
    private let client: AtlasHTTPClient

    init(client: AtlasHTTPClient = AtlasHTTPClient()) {
        self.client = client
    }

    func reportAndBlock(
        session: StrangerSession,
        reason: String,
        context: ModelContext
    ) async throws {
        if session.usesCloudRelay, let remoteId = session.remoteSessionId {
            struct Body: Encodable {
                let sessionId: String
                let reason: String
            }

            struct Response: Decodable {
                let ok: Bool?
                let error: String?
            }

            let response: Response = try await client.post(
                function: "reportAndBlock",
                body: Body(sessionId: remoteId, reason: reason)
            )

            if let error = response.error {
                throw SessionServiceError.server(error)
            }
            guard response.ok == true else {
                throw SessionServiceError.server("Report failed.")
            }
        }

        session.status = .ended
        session.expiresAt = .now
        try context.save()
    }
}
