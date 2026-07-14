import Foundation
import SwiftData

struct MockSessionService: SessionServiceProtocol {
    var isCloudBacked: Bool { false }

    func findMatch(context: ModelContext) async throws -> MatchResult {
        let partner = MockPartner.random()
        let startedAt = Date.now

        let dto = RemoteSessionDTO(
            id: UUID().uuidString,
            startedAt: startedAt,
            expiresAt: startedAt.addingTimeInterval(24 * 60 * 60),
            status: SessionStatus.active.rawValue,
            partnerCountryCode: partner.countryCode,
            partnerCountryName: partner.countryName,
            partnerTimeZoneIdentifier: partner.timeZoneIdentifier,
            partnerWeatherSummary: partner.weatherSummary,
            partnerDistanceKm: partner.distanceKm,
            myFarewellText: nil,
            theirFarewellText: nil
        )
        return .matched(dto)
    }

    func submitPhoto(
        _ imageData: Data,
        weatherSummary: String,
        for session: StrangerSession,
        context: ModelContext
    ) async throws {
        let hourIndex = session.currentHourIndex
        guard let slot = session.slot(for: hourIndex) else { return }

        slot.myPhotoData = imageData
        slot.myCapturedAt = .now

        if slot.theirPhotoData == nil {
            let partner = MockPartner(
                countryCode: session.partnerCountryCode,
                countryName: session.partnerCountryName,
                distanceKm: session.partnerDistanceKm,
                weatherSummary: session.partnerWeatherSummary,
                timeZoneIdentifier: session.partnerTimeZoneIdentifier
            )
            slot.theirPhotoData = partner.placeholderPhotoData(for: hourIndex)
            slot.theirCapturedAt = .now.addingTimeInterval(5)
        }

        try context.save()
    }

    func submitFarewell(
        _ text: String,
        for session: StrangerSession,
        context: ModelContext
    ) async throws {
        let trimmed = String(text.prefix(280))
        guard !trimmed.isEmpty, session.myFarewellText == nil else { return }
        session.myFarewellText = trimmed
        session.theirFarewellText = "Thank you for sharing your world today."
        try context.save()
    }

    func syncSession(for session: StrangerSession, context: ModelContext) async throws {
        if session.isExpired {
            session.status = .ended
        } else if session.isInFarewellWindow {
            session.status = .farewell
        } else {
            session.status = .active
        }
        try context.save()
    }
}
