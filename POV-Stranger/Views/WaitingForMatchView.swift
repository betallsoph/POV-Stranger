import SwiftUI

struct WaitingForMatchView: View {
    let isMatching: Bool
    let requiresSignIn: Bool
    let isSigningIn: Bool
    let authStatusLabel: String
    let authError: String?
    let isSignedInForCloud: Bool
    let onSignIn: () -> Void
    let onSignOut: () -> Void
    let onFindStranger: () -> Void

    private var canFindStranger: Bool {
        !isMatching && (!requiresSignIn || isSignedInForCloud)
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "globe.americas.fill")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 12) {
                Text("POV: Stranger")
                    .font(.largeTitle.bold())

                Text("See a life you'll never know.\nFor one day only.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Paired with someone far away", systemImage: "person.2.fill")
                Label("Exchange one photo each hour", systemImage: "camera.fill")
                Label("No names. No chat. Gone in 24h.", systemImage: "hourglass")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            if requiresSignIn || AtlasConfig.requiresAuth {
                SignInWithAppleCard(
                    isSigningIn: isSigningIn,
                    statusLabel: authStatusLabel,
                    errorMessage: authError,
                    onSignIn: onSignIn,
                    onSignOut: onSignOut,
                    showSignOut: isSignedInForCloud
                )
            }

            Spacer()

            Button(action: onFindStranger) {
                Group {
                    if isMatching {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Find a stranger")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canFindStranger)
        }
        .padding()
    }
}

#Preview {
    WaitingForMatchView(
        isMatching: false,
        requiresSignIn: false,
        isSigningIn: false,
        authStatusLabel: "Offline demo mode",
        authError: nil,
        isSignedInForCloud: false,
        onSignIn: {},
        onSignOut: {},
        onFindStranger: {}
    )
}
