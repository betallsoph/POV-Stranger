import Foundation

struct RemoteSessionDTO: Codable, Sendable {
    let id: String
    let startedAt: Date
    let expiresAt: Date
    let status: String
    let partnerCountryCode: String
    let partnerCountryName: String
    let partnerTimeZoneIdentifier: String
    let partnerWeatherSummary: String
    let partnerDistanceKm: Double
    let myFarewellText: String?
    let theirFarewellText: String?
}

struct GetActiveSessionResponse: Codable, Sendable {
    let session: RemoteSessionDTO?
    let error: String?
}

struct SubmitFarewellRequest: Encodable, Sendable {
    let sessionId: String
    let text: String
}

struct SubmitFarewellResponse: Decodable, Sendable {
    let ok: Bool?
    let text: String?
    let error: String?
}

struct MatchEnqueueResponse: Codable, Sendable {
    let status: String
    let session: RemoteSessionDTO?
    let error: String?
}

enum MatchResult: Sendable {
    case matched(RemoteSessionDTO)
    case waiting
}

enum SessionServiceError: LocalizedError {
    case notConfigured
    case unauthorized
    case server(String)
    case waitingForStranger

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Atlas backend is not configured."
        case .unauthorized:
            "Sign in required."
        case .server(let message):
            message
        case .waitingForStranger:
            "Still looking for a stranger on the other side of the world…"
        }
    }
}
