import Foundation

enum SessionServiceFactory {
    @MainActor
    static func make() -> SessionServiceProtocol {
        if AtlasConfig.isConfigured {
            return AtlasSessionService()
        }
        return MockSessionService()
    }
}
