import SwiftUI

struct HourTimelineView: View {
    let session: StrangerSession
    let currentHourIndex: Int

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's exchange")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(session.slots.sorted { $0.hourIndex < $1.hourIndex }, id: \.hourIndex) { slot in
                    HourSlotCell(slot: slot, isCurrent: slot.hourIndex == currentHourIndex)
                }
            }
        }
    }
}

private struct HourSlotCell: View {
    let slot: HourSlot
    let isCurrent: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(fillColor)
                    .frame(height: 44)

                if slot.theirPhotoData != nil {
                    Image(systemName: "eye.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                } else if slot.myPhotoData != nil {
                    Image(systemName: "camera.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                } else if isCurrent {
                    Image(systemName: "hourglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .overlay {
                if isCurrent {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.primary, lineWidth: 2)
                }
            }

            Text("\(slot.hourIndex + 1)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var fillColor: Color {
        if slot.theirPhotoData != nil {
            return .blue.opacity(0.5)
        }
        if slot.myPhotoData != nil {
            return .green.opacity(0.4)
        }
        if isCurrent {
            return .yellow.opacity(0.25)
        }
        return .gray.opacity(0.15)
    }
}

#Preview {
    HourTimelineView(
        session: StrangerSession(
            partnerDistanceKm: 12_400,
            partnerCountryCode: "IS",
            partnerCountryName: "Iceland",
            partnerWeatherSummary: "Snow · -2°C",
            partnerTimeZoneIdentifier: "Atlantic/Reykjavik"
        ),
        currentHourIndex: 3
    )
    .padding()
}
