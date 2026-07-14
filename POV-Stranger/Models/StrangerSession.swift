import Foundation
import SwiftData

@Model
final class StrangerSession {
    var id: UUID
    var startedAt: Date
    var expiresAt: Date
    var statusRaw: String
    var partnerDistanceKm: Double
    var partnerCountryCode: String
    var partnerCountryName: String
    var partnerWeatherSummary: String
    var partnerTimeZoneIdentifier: String
    var myFarewellText: String?
    var theirFarewellText: String?
    /// MongoDB Atlas session id when using cloud relay.
    var remoteSessionId: String?

    @Relationship(deleteRule: .cascade, inverse: \HourSlot.session)
    var slots: [HourSlot]

    var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    init(
        startedAt: Date = .now,
        partnerDistanceKm: Double,
        partnerCountryCode: String,
        partnerCountryName: String,
        partnerWeatherSummary: String,
        partnerTimeZoneIdentifier: String
    ) {
        self.id = UUID()
        self.startedAt = startedAt
        self.expiresAt = startedAt.addingTimeInterval(24 * 60 * 60)
        self.statusRaw = SessionStatus.active.rawValue
        self.partnerDistanceKm = partnerDistanceKm
        self.partnerCountryCode = partnerCountryCode
        self.partnerCountryName = partnerCountryName
        self.partnerWeatherSummary = partnerWeatherSummary
        self.partnerTimeZoneIdentifier = partnerTimeZoneIdentifier
        self.slots = (0..<24).map { HourSlot(hourIndex: $0) }
    }

    /// Create or update a local session from an Atlas response payload.
    static func upsert(from remote: RemoteSessionDTO, in context: ModelContext) throws -> StrangerSession {
        let remoteId = remote.id
        let descriptor = FetchDescriptor<StrangerSession>(
            predicate: #Predicate { $0.remoteSessionId == remoteId }
        )
        let existing = try context.fetch(descriptor).first

        let session: StrangerSession
        if let existing {
            session = existing
        } else {
            session = StrangerSession(
                startedAt: remote.startedAt,
                partnerDistanceKm: remote.partnerDistanceKm,
                partnerCountryCode: remote.partnerCountryCode,
                partnerCountryName: remote.partnerCountryName,
                partnerWeatherSummary: remote.partnerWeatherSummary,
                partnerTimeZoneIdentifier: remote.partnerTimeZoneIdentifier
            )
            session.remoteSessionId = remoteId
            session.slots = (0..<24).map { HourSlot(hourIndex: $0) }
            context.insert(session)
        }

        session.startedAt = remote.startedAt
        session.expiresAt = remote.expiresAt
        session.status = SessionStatus(rawValue: remote.status) ?? .active
        session.partnerDistanceKm = remote.partnerDistanceKm
        session.partnerCountryCode = remote.partnerCountryCode
        session.partnerCountryName = remote.partnerCountryName
        session.partnerWeatherSummary = remote.partnerWeatherSummary
        session.partnerTimeZoneIdentifier = remote.partnerTimeZoneIdentifier
        session.remoteSessionId = remoteId

        if let myFarewellText = remote.myFarewellText {
            session.myFarewellText = myFarewellText
        }
        if let theirFarewellText = remote.theirFarewellText {
            session.theirFarewellText = theirFarewellText
        }

        try context.save()
        return session
    }

    func applyRemoteSync(_ remote: RemoteSessionDTO) {
        startedAt = remote.startedAt
        expiresAt = remote.expiresAt
        status = SessionStatus(rawValue: remote.status) ?? status
        partnerDistanceKm = remote.partnerDistanceKm
        partnerCountryCode = remote.partnerCountryCode
        partnerCountryName = remote.partnerCountryName
        partnerWeatherSummary = remote.partnerWeatherSummary
        partnerTimeZoneIdentifier = remote.partnerTimeZoneIdentifier

        if let myFarewellText = remote.myFarewellText {
            self.myFarewellText = myFarewellText
        }
        if let theirFarewellText = remote.theirFarewellText {
            self.theirFarewellText = theirFarewellText
        }
    }

    var usesCloudRelay: Bool {
        remoteSessionId != nil
    }

    var elapsed: TimeInterval {
        Date.now.timeIntervalSince(startedAt)
    }

    var remaining: TimeInterval {
        max(0, expiresAt.timeIntervalSinceNow)
    }

    var currentHourIndex: Int {
        min(23, max(0, Int(elapsed / 3600)))
    }

    var isInFarewellWindow: Bool {
        remaining <= 2 * 60 * 60 && remaining > 0
    }

    var isExpired: Bool {
        Date.now >= expiresAt
    }

    func slot(for hourIndex: Int) -> HourSlot? {
        slots.first { $0.hourIndex == hourIndex }
    }

    var partnerLocalTime: String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: partnerTimeZoneIdentifier)
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: .now)
    }

    var formattedDistance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let value = formatter.string(from: NSNumber(value: partnerDistanceKm)) ?? "\(Int(partnerDistanceKm))"
        return "\(value) km away"
    }
}
