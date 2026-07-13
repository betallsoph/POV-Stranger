import Foundation

@MainActor
enum AtlasAuthTokenStore {
    private enum Key {
        static let accessToken = "atlas.accessToken"
        static let refreshToken = "atlas.refreshToken"
        static let atlasUserId = "atlas.userId"
        static let appleUserId = "atlas.appleUserId"
    }

    static var accessToken: String? {
        get { UserDefaults.standard.string(forKey: Key.accessToken) }
        set { UserDefaults.standard.set(newValue, forKey: Key.accessToken) }
    }

    static var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: Key.refreshToken) }
        set { UserDefaults.standard.set(newValue, forKey: Key.refreshToken) }
    }

    static var atlasUserId: String? {
        get { UserDefaults.standard.string(forKey: Key.atlasUserId) }
        set { UserDefaults.standard.set(newValue, forKey: Key.atlasUserId) }
    }

    static var appleUserId: String? {
        get { UserDefaults.standard.string(forKey: Key.appleUserId) }
        set { UserDefaults.standard.set(newValue, forKey: Key.appleUserId) }
    }

    static var isSignedIn: Bool {
        accessToken != nil
    }

    static func save(auth: AtlasAuthResponse, appleUserId: String) {
        accessToken = auth.accessToken
        refreshToken = auth.refreshToken
        atlasUserId = auth.userId
        self.appleUserId = appleUserId
    }

    static func clear() {
        accessToken = nil
        refreshToken = nil
        atlasUserId = nil
        appleUserId = nil
    }
}
