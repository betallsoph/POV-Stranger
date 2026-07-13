import SwiftUI

struct SessionEndedView: View {
    let session: StrangerSession
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "wind")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("They're gone")
                .font(.largeTitle.bold())

            Text("Your stranger from \(session.partnerCountryName) has vanished.\nAll photos from today are gone.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if let theirMessage = session.theirFarewellText {
                VStack(alignment: .leading, spacing: 8) {
                    Text("A message in a bottle")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\"\(theirMessage)\"")
                        .font(.body.italic())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }

            if let myMessage = session.myFarewellText {
                Text("You wrote: \"\(myMessage)\"")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button("Close", action: onDismiss)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
        .padding()
    }
}

#Preview {
    let session = StrangerSession(
        partnerDistanceKm: 12_400,
        partnerCountryCode: "IS",
        partnerCountryName: "Iceland",
        partnerWeatherSummary: "Snow · -2°C",
        partnerTimeZoneIdentifier: "Atlantic/Reykjavik"
    )
    session.theirFarewellText = "Thank you for sharing your world today."
    session.myFarewellText = "Chúc mày một đời bình an."

    return SessionEndedView(session: session, onDismiss: {})
}
