import WidgetKit
import SwiftUI

struct POVStrangerWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let partnerPhoto: UIImage?
}

struct POVStrangerWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> POVStrangerWidgetEntry {
        POVStrangerWidgetEntry(
            date: .now,
            snapshot: WidgetSnapshot(
                hasActiveSession: true,
                theirPhotoFilename: nil,
                distanceKm: 12_400,
                weatherSummary: "Snow · -2°C",
                localTimeDescription: "2:14 AM · Iceland",
                countryName: "Iceland",
                hourIndex: 6,
                expiresAt: .now.addingTimeInterval(12 * 3600),
                updatedAt: .now
            ),
            partnerPhoto: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (POVStrangerWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<POVStrangerWidgetEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> POVStrangerWidgetEntry {
        let snapshot = WidgetDataReader.loadSnapshot()
        let photoData = WidgetDataReader.loadPartnerPhoto()
        let image = photoData.flatMap { UIImage(data: $0) }
        return POVStrangerWidgetEntry(date: .now, snapshot: snapshot, partnerPhoto: image)
    }
}

struct POVStrangerWidgetEntryView: View {
    var entry: POVStrangerWidgetProvider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            background

            if entry.snapshot.hasActiveSession {
                metadataOverlay
            } else {
                emptyOverlay
            }
        }
        .containerBackground(for: .widget) {
            background
        }
    }

    @ViewBuilder
    private var background: some View {
        if let partnerPhoto = entry.partnerPhoto {
            Image(uiImage: partnerPhoto)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [.blue.opacity(0.5), .purple.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var metadataOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let distance = entry.snapshot.distanceKm {
                Text(formattedDistance(distance))
                    .font(family == .systemSmall ? .caption2.bold() : .caption.bold())
            }

            if let weather = entry.snapshot.weatherSummary {
                Text(weather)
                    .font(.caption2)
            }

            if let time = entry.snapshot.localTimeDescription {
                Text(time)
                    .font(.caption2)
                    .lineLimit(1)
            }

            if let hour = entry.snapshot.hourIndex {
                Text("Hour \(hour + 1) of 24")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(10)
    }

    private var emptyOverlay: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("POV: Stranger")
                .font(.caption.bold())
            Text("Find a stranger to begin.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .background(.ultraThinMaterial.opacity(0.85))
    }

    private func formattedDistance(_ km: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let value = formatter.string(from: NSNumber(value: km)) ?? "\(Int(km))"
        return "\(value) km away"
    }
}

struct POVStrangerWidget: Widget {
    let kind = "POVStrangerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: POVStrangerWidgetProvider()) { entry in
            POVStrangerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("POV: Stranger")
        .description("See your anonymous stranger's latest hour.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    POVStrangerWidget()
} timeline: {
    POVStrangerWidgetEntry(
        date: .now,
        snapshot: WidgetSnapshot(
            hasActiveSession: true,
            theirPhotoFilename: nil,
            distanceKm: 12_400,
            weatherSummary: "Snow · -2°C",
            localTimeDescription: "2:14 AM · Iceland",
            countryName: "Iceland",
            hourIndex: 6,
            expiresAt: .now.addingTimeInterval(12 * 3600),
            updatedAt: .now
        ),
        partnerPhoto: nil
    )
}
