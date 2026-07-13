import SwiftUI

struct WaitingForMatchView: View {
    let isMatching: Bool
    let onFindStranger: () -> Void

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
            .disabled(isMatching)
        }
        .padding()
    }
}

#Preview {
    WaitingForMatchView(isMatching: false, onFindStranger: {})
}
