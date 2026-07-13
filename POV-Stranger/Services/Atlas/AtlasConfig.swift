import Foundation

enum AtlasConfig {
    static var endpointBase: String? {
        let value = Bundle.main.object(forInfoDictionaryKey: "ATLAS_ENDPOINT_BASE") as? String
        guard let value, !value.isEmpty, !value.hasPrefix("$(") else { return nil }
        return value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static var appId: String? {
        let value = Bundle.main.object(forInfoDictionaryKey: "ATLAS_APP_ID") as? String
        guard let value, !value.isEmpty, !value.hasPrefix("$(") else { return nil }
        return value
    }

    static var isConfigured: Bool {
        endpointBase != nil
    }

    /// Full cloud mode needs App ID (auth) + endpoint base (functions).
    static var requiresAuth: Bool {
        isConfigured && appId != nil
    }
}
