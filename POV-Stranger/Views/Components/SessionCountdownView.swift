import SwiftUI

struct SessionCountdownView: View {
    let session: StrangerSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                        .modifier(CountdownTransition(disabled: reduceMotion))
                }

                Text("Hour \(session.currentHourIndex + 1) of 24")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    private var accessibilityLabel: String {
        if session.isExpired {
            return "Session ended"
        }
        return "Time remaining \(formatRemaining(session.remaining)), hour \(session.currentHourIndex + 1) of 24"
    }

    private func formatRemaining(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

private struct CountdownTransition: ViewModifier {
    let disabled: Bool

    func body(content: Content) -> some View {
        if disabled {
            content
        } else {
            content.contentTransition(.numericText())
        }
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
