import SwiftUI

struct PartnerMetadataCard: View {
    let session: StrangerSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(session.formattedDistance, systemImage: "globe.europe.africa.fill")
                .font(.headline)

            Label(session.partnerWeatherSummary, systemImage: "cloud.sun.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label("\(session.partnerLocalTime) in \(session.partnerCountryName)", systemImage: "clock.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("You know nothing else about them.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    PartnerMetadataCard(
        session: StrangerSession(
            partnerDistanceKm: 12_400,
            partnerCountryCode: "IS",
            partnerCountryName: "Iceland",
            partnerWeatherSummary: "Snow · -2°C",
            partnerTimeZoneIdentifier: "Atlantic/Reykjavik"
        )
    )
    .padding()
}
