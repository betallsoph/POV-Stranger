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
        guard let remoteId = session.remoteSessionId else {
            throw SessionServiceError.server("Session has no remote id.")
        }

        let hourIndex = session.currentHourIndex
        guard let slot = session.slot(for: hourIndex) else { return }

        let uploadBody = UploadPhotoRequest(
            sessionId: remoteId,
            hourIndex: hourIndex,
            weatherSummary: weatherSummary,
            imageBase64: imageData.base64EncodedString()
        )

        let uploadResponse: UploadPhotoResponse = try await client.post(
            function: "uploadPhoto",
            body: uploadBody
        )

        if let error = uploadResponse.error {
            if error == "Unauthorized" { throw SessionServiceError.unauthorized }
            throw SessionServiceError.server(error)
        }
        guard uploadResponse.ok == true else {
            throw SessionServiceError.server("Photo upload failed.")
        }

        slot.myPhotoData = imageData
        slot.myCapturedAt = .now

        let partnerBody = GetPartnerPhotoRequest(sessionId: remoteId, hourIndex: hourIndex)
        let partnerResponse: GetPartnerPhotoResponse = try await client.post(
            function: "getPartnerPhoto",
            body: partnerBody
        )

        if let error = partnerResponse.error {
            throw SessionServiceError.server(error)
        }

        if let photo = partnerResponse.photo,
           let partnerData = Data(base64Encoded: photo.imageBase64) {
            slot.theirPhotoData = partnerData
            slot.theirCapturedAt = photo.capturedAt ?? .now
        }

        try context.save()
    }

    func submitFarewell(
        _ text: String,
        for session: StrangerSession,
        context: ModelContext
    ) async throws {
        throw SessionServiceError.server("Farewell sync not implemented yet.")
    }
}
