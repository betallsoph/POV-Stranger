import Foundation

struct AtlasHTTPClient: Sendable {
    enum ClientError: LocalizedError {
        case notConfigured
        case invalidURL
        case http(Int)
        case decoding(Error)

        var errorDescription: String? {
            switch self {
            case .notConfigured: "Atlas endpoint is not configured."
            case .invalidURL: "Invalid Atlas endpoint URL."
            case .http(let code): "Atlas request failed (\(code))."
            case .decoding(let error): "Atlas response error: \(error.localizedDescription)"
            }
        }
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func post<Body: Encodable, Response: Decodable>(
        function name: String,
        body: Body
    ) async throws -> Response {
        guard let base = AtlasConfig.endpointBase else {
            throw ClientError.notConfigured
        }

        guard let url = URL(string: "\(base)/\(name)") else {
            throw ClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = await MainActor.run(body: { AtlasAuthTokenStore.accessToken }) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONEncoder.atlas.encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClientError.http(-1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ClientError.http(http.statusCode)
        }

        do {
            return try JSONDecoder.atlas.decode(Response.self, from: data)
        } catch {
            throw ClientError.decoding(error)
        }
    }
}

private extension JSONEncoder {
    static let atlas: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

private extension JSONDecoder {
    static let atlas: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
