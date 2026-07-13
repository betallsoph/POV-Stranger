import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class SessionManager {
    private(set) var isMatching = false

    func findMatch(context: ModelContext) throws -> StrangerSession {
        isMatching = true
        defer { isMatching = false }

        let partner = MockPartner.random()
        let session = StrangerSession(
            partnerDistanceKm: partner.distanceKm,
            partnerCountryCode: partner.countryCode,
            partnerCountryName: partner.countryName,
            partnerWeatherSummary: partner.weatherSummary,
            partnerTimeZoneIdentifier: partner.timeZoneIdentifier
        )

        context.insert(session)
        try context.save()
        WidgetDataStore.update(from: session)
        Task { await HourlyReminderScheduler.schedule(for: session) }
        return session
    }

    func refreshSessionStatus(_ session: StrangerSession, context: ModelContext) throws {
        if session.isExpired {
            session.status = .ended
        } else if session.isInFarewellWindow {
            session.status = .farewell
        } else {
            session.status = .active
        }
        try context.save()
    }

    func submitPhoto(
        _ imageData: Data,
        for session: StrangerSession,
        context: ModelContext
    ) throws {
        let hourIndex = session.currentHourIndex
        guard let slot = session.slot(for: hourIndex) else { return }

        slot.myPhotoData = imageData
        slot.myCapturedAt = .now

        // Simulate partner response in development.
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
        WidgetDataStore.update(from: session)
    }

    func submitFarewell(_ text: String, for session: StrangerSession, context: ModelContext) throws {
        let trimmed = String(text.prefix(280))
        guard !trimmed.isEmpty, session.myFarewellText == nil else { return }
        session.myFarewellText = trimmed
        session.theirFarewellText = "Thank you for sharing your world today."
        try context.save()
    }

    func endSession(_ session: StrangerSession, context: ModelContext) throws {
        context.delete(session)
        try context.save()
        WidgetDataStore.clear()
        Task { await HourlyReminderScheduler.cancelAll() }
    }

    #if DEBUG
    func debugEnterFarewellWindow(_ session: StrangerSession, context: ModelContext) throws {
        session.expiresAt = Date.now.addingTimeInterval(90 * 60)
        session.status = .farewell
        try context.save()
    }

    func debugExpireSession(_ session: StrangerSession, context: ModelContext) throws {
        session.expiresAt = Date.now.addingTimeInterval(-1)
        session.status = .ended
        try context.save()
    }

    func debugAdvanceHour(_ session: StrangerSession, context: ModelContext) throws {
        let hoursElapsed = session.currentHourIndex + 1
        session.startedAt = Date.now.addingTimeInterval(-Double(hoursElapsed) * 3600)
        try refreshSessionStatus(session, context: context)
    }
    #endif

    func activeSession(from sessions: [StrangerSession]) -> StrangerSession? {
        sessions
            .filter { $0.status != .ended }
            .sorted { $0.startedAt > $1.startedAt }
            .first
    }
}
