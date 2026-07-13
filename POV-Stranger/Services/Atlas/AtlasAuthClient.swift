import Foundation

struct AtlasAuthResponse: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let userId: String
    let deviceId: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case userId = "user_id"
        case deviceId = "device_id"
    }
}

enum AtlasAuthError: LocalizedError {
    case notConfigured
    case invalidURL
    case http(Int, String?)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Atlas App ID is not configured."
        case .invalidURL:
            "Invalid Atlas auth URL."
        case .http(let code, let body):
            "Atlas auth failed (\(code)): \(body ?? "unknown error")"
        case .decoding(let error):
            "Atlas auth response error: \(error.localizedDescription)"
        }
    }
}

struct AtlasAuthClient: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func loginWithApple(idToken: String, userId: String) async throws -> AtlasAuthResponse {
        guard let appId = AtlasConfig.appId else {
            throw AtlasAuthError.notConfigured
        }

        guard let url = URL(string: AtlasConfig.appleAuthURL(appId: appId)) else {
            throw AtlasAuthError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/ejson", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "idToken": idToken,
            "userId": userId,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AtlasAuthError.http(-1, nil)
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw AtlasAuthError.http(http.statusCode, message)
        }

        do {
            return try JSONDecoder().decode(AtlasAuthResponse.self, from: data)
        } catch {
            throw AtlasAuthError.decoding(error)
        }
    }
}

private extension AtlasConfig {
    static func appleAuthURL(appId: String) -> String {
        "https://services.cloud.mongodb.com/api/client/v2.0/app/\(appId)/auth/providers/apple/login"
    }
}
