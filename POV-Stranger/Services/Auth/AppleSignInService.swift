import AuthenticationServices
import Foundation
import UIKit

struct AppleSignInResult: Sendable {
    let userId: String
    let identityToken: String
    let email: String?
}

enum AppleSignInError: LocalizedError {
    case missingCredential
    case missingIdentityToken
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .missingCredential: "Apple Sign In did not return a credential."
        case .missingIdentityToken: "Apple Sign In did not return an identity token."
        case .cancelled: "Sign in was cancelled."
        case .failed(let message): message
        }
    }
}

@MainActor
final class AppleSignInService: NSObject {
    private var continuation: CheckedContinuation<AppleSignInResult, Error>?

    func signIn() async throws -> AppleSignInResult {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func credentialState(for userId: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userId) { state, _ in
                continuation.resume(returning: state)
            }
        }
    }
}

extension AppleSignInService: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: AppleSignInError.missingCredential)
            continuation = nil
            return
        }

        guard
            let tokenData = credential.identityToken,
            let identityToken = String(data: tokenData, encoding: .utf8)
        else {
            continuation?.resume(throwing: AppleSignInError.missingIdentityToken)
            continuation = nil
            return
        }

        let result = AppleSignInResult(
            userId: credential.user,
            identityToken: identityToken,
            email: credential.email
        )
        continuation?.resume(returning: result)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            continuation?.resume(throwing: AppleSignInError.cancelled)
        } else {
            continuation?.resume(throwing: AppleSignInError.failed(error.localizedDescription))
        }
        continuation = nil
    }
}

extension AppleSignInService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = scene.windows.first(where: \.isKeyWindow)
        else {
            return ASPresentationAnchor()
        }
        return window
    }
}
