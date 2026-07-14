import SwiftUI

struct SignInWithAppleCard: View {
    let isSigningIn: Bool
    let statusLabel: String
    let errorMessage: String?
    let onSignIn: () -> Void
    let onSignOut: () -> Void
    let showSignOut: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(statusLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            if showSignOut {
                HStack {
                    Label("Ready for cloud matching", systemImage: "checkmark.shield.fill")
                        .font(.subheadline)
                    Spacer()
                    Button("Sign out", action: onSignOut)
                        .font(.caption)
                }
            } else {
                Button(action: onSignIn) {
                    Label("Sign in with Apple", systemImage: "apple.logo")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.black)
                .disabled(isSigningIn)

                if isSigningIn {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .povGlassCard()
    }
}

#Preview {
    SignInWithAppleCard(
        isSigningIn: false,
        statusLabel: "Sign in required",
        errorMessage: nil,
        onSignIn: {},
        onSignOut: {},
        showSignOut: false
    )
    .padding()
}
