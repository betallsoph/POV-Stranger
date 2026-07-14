import SwiftUI

struct AgeGateView: View {
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("17+ only")
                .font(.largeTitle.bold())

            Text(
                "POV-Stranger connects you with anonymous strangers for photo exchange. "
                    + "You must be 17 or older to use this app."
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Label("No names or profiles", systemImage: "eye.slash")
                Label("Report inappropriate content", systemImage: "flag")
                Label("Photos disappear after 24 hours", systemImage: "hourglass")
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            Spacer()

            Button("I'm 17 or older", action: onConfirm)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)

            Text("By continuing you agree to our Terms and Privacy Policy.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    AgeGateView(onConfirm: {})
}
