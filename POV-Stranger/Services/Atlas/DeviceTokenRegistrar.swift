import Foundation
import UIKit

@MainActor
final class DeviceTokenRegistrar {
    static let shared = DeviceTokenRegistrar()

    private var pendingToken: String?
    private let client = AtlasHTTPClient()

    private init() {}

    func updateDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        pendingToken = token
        Task { await registerPendingTokenIfNeeded() }
    }

    func registerPendingTokenIfNeeded() async {
        guard AtlasConfig.isConfigured, AtlasAuthTokenStore.isSignedIn else { return }
        guard let token = pendingToken else { return }

        struct Body: Encodable {
            let token: String
        }

        struct Response: Decodable {
            let ok: Bool?
            let error: String?
        }

        do {
            let response: Response = try await client.post(function: "registerDeviceToken", body: Body(token: token))
            if let error = response.error {
                print("Device token registration failed: \(error)")
            }
        } catch {
            print("Device token registration failed: \(error.localizedDescription)")
        }
    }
}
