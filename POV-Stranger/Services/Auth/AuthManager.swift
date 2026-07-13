import AuthenticationServices
import Foundation
import Observation

@Observable
@MainActor
final class AuthManager {
    private(set) var isSigningIn = false
    private(set) var lastError: String?

    private let appleSignIn: AppleSignInService
    private let atlasAuth: AtlasAuthClient

    init(
        appleSignIn: AppleSignInService? = nil,
        atlasAuth: AtlasAuthClient = AtlasAuthClient()
    ) {
        self.appleSignIn = appleSignIn ?? AppleSignInService()
        self.atlasAuth = atlasAuth
    }

    /// Mock mode skips auth; cloud mode requires Sign in with Apple.
    var requiresSignIn: Bool {
        AtlasConfig.requiresAuth && !AtlasAuthTokenStore.isSignedIn
    }

    var isAuthenticated: Bool {
        !requiresSignIn
    }

    var statusLabel: String {
        if !AtlasConfig.requiresAuth {
            return "Offline demo mode"
        }
        if AtlasAuthTokenStore.isSignedIn {
            return "Signed in anonymously"
        }
        return "Sign in required for cloud matching"
    }

    func restoreSessionIfNeeded() async {
        guard AtlasConfig.requiresAuth, let appleUserId = AtlasAuthTokenStore.appleUserId else { return }

        let state = await appleSignIn.credentialState(for: appleUserId)
        switch state {
        case .authorized:
            break
        case .revoked, .notFound, .transferred:
            signOut()
        @unknown default:
            break
        }
    }

    func signInWithApple() async {
        isSigningIn = true
        lastError = nil
        defer { isSigningIn = false }

        do {
            let apple = try await appleSignIn.signIn()

            if AtlasConfig.requiresAuth {
                guard AtlasConfig.appId != nil else {
                    lastError = "Set ATLAS_APP_ID in Secrets.xcconfig"
                    return
                }
                let auth = try await atlasAuth.loginWithApple(
                    idToken: apple.identityToken,
                    userId: apple.userId
                )
                AtlasAuthTokenStore.save(auth: auth, appleUserId: apple.userId)
            } else {
                AtlasAuthTokenStore.appleUserId = apple.userId
            }

            await DeviceTokenRegistrar.shared.registerPendingTokenIfNeeded()
        } catch AppleSignInError.cancelled {
            return
        } catch {
            lastError = error.localizedDescription
        }
    }

    func signOut() {
        AtlasAuthTokenStore.clear()
    }
}
