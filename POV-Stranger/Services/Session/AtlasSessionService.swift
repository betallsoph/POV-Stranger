import Foundation
import SwiftData

struct AtlasSessionService: SessionServiceProtocol {
    private let client: AtlasHTTPClient

    var isCloudBacked: Bool { true }

    init(client: AtlasHTTPClient = AtlasHTTPClient()) {
        self.client = client
    }

    func findMatch(context: ModelContext) async throws -> MatchResult {
        struct Body: Encodable {
            let countryCode: String
            let timezoneId: String
        }

        let body = Body(
            countryCode: Locale.current.region?.identifier ?? "XX",
            timezoneId: TimeZone.current.identifier
        )

        let response: MatchEnqueueResponse = try await client.post(function: "matchEnqueue", body: body)

        if let error = response.error {
            if error == "Unauthorized" { throw SessionServiceError.unauthorized }
            throw SessionServiceError.server(error)
        }

        switch response.status {
        case "matched":
            guard let session = response.session else {
                throw SessionServiceError.server("Missing session payload.")
            }
            return .matched(session)
        case "waiting":
            return .waiting
        default:
            throw SessionServiceError.server("Unexpected status: \(response.status)")
        }
    }

    func submitPhoto(
        _ imageData: Data,
        weatherSummary: String,
        for session: StrangerSession,
        context: ModelContext
    ) async throws {
        throw SessionServiceError.server("Photo upload (GridFS) — Phase 4c.")
    }

    func submitFarewell(
        _ text: String,
        for session: StrangerSession,
        context: ModelContext
    ) async throws {
        throw SessionServiceError.server("Farewell sync not implemented yet.")
    }
}
