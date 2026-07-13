import Foundation

struct UploadPhotoRequest: Encodable, Sendable {
    let sessionId: String
    let hourIndex: Int
    let weatherSummary: String
    let imageBase64: String
}

struct UploadPhotoResponse: Decodable, Sendable {
    let ok: Bool?
    let hourIndex: Int?
    let gridfsFileId: String?
    let error: String?
}

struct GetPartnerPhotoRequest: Encodable, Sendable {
    let sessionId: String
    let hourIndex: Int
}

struct PartnerPhotoDTO: Decodable, Sendable {
    let imageBase64: String
    let hourIndex: Int
    let capturedAt: Date?
    let weatherSummary: String?
}

struct GetPartnerPhotoResponse: Decodable, Sendable {
    let photo: PartnerPhotoDTO?
    let error: String?
}
