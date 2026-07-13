import Foundation

@MainActor
enum AtlasAuthTokenStore {
    private static let key = "atlas.accessToken"

    static var accessToken: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
