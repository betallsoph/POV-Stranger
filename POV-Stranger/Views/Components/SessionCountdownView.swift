import SwiftUI

struct SessionCountdownView: View {
    let session: StrangerSession

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(spacing: 4) {
                Text(session.isExpired ? "Session ended" : "Time remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if session.isExpired {
                    Text("00:00:00")
                        .font(.title2.monospacedDigit().bold())
                } else {
                    Text(formatRemaining(session.remaining))
                        .font(.title2.monospacedDigit().bold())
                        .contentTransition(.numericText())
                }

                Text("Hour \(session.currentHourIndex + 1) of 24")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func formatRemaining(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

#Preview {
    SessionCountdownView(
        session: StrangerSession(
            partnerDistanceKm: 12_400,
            partnerCountryCode: "IS",
            partnerCountryName: "Iceland",
            partnerWeatherSummary: "Snow · -2°C",
            partnerTimeZoneIdentifier: "Atlantic/Reykjavik"
        )
    )
}
