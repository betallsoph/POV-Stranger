import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class SessionManager {
    private let sessionService: SessionServiceProtocol
    private(set) var isMatching = false

    var isCloudBacked: Bool { sessionService.isCloudBacked }

    init(sessionService: SessionServiceProtocol? = nil) {
        self.sessionService = sessionService ?? SessionServiceFactory.make()
    }

    func findMatch(context: ModelContext) async throws -> StrangerSession {
        isMatching = true
        defer { isMatching = false }

        switch try await sessionService.findMatch(context: context) {
        case .matched(let remote):
            let session = try StrangerSession.upsert(from: remote, in: context)
            WidgetDataStore.update(from: session)
            await HourlyReminderScheduler.schedule(for: session)
            return session
        case .waiting:
            throw SessionServiceError.waitingForStranger
        }
    }

    func refreshSessionStatus(_ session: StrangerSession, context: ModelContext) async throws {
        if sessionService.isCloudBacked {
            try await sessionService.syncSession(for: session, context: context)
        } else {
            if session.isExpired {
                session.status = .ended
            } else if session.isInFarewellWindow {
                session.status = .farewell
            } else {
                session.status = .active
            }
            try context.save()
        }

        if session.status == .ended {
            WidgetDataStore.clear()
            await HourlyReminderScheduler.cancelAll()
        } else {
            WidgetDataStore.update(from: session)
        }
    }

    func submitPhoto(
        _ imageData: Data,
        weatherSummary: String,
        for session: StrangerSession,
        context: ModelContext
    ) async throws {
        try await sessionService.submitPhoto(
            imageData,
            weatherSummary: weatherSummary,
            for: session,
            context: context
        )
        WidgetDataStore.update(from: session)
    }

    func submitFarewell(_ text: String, for session: StrangerSession, context: ModelContext) async throws {
        try await sessionService.submitFarewell(text, for: session, context: context)
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

    func debugAdvanceHour(_ session: StrangerSession, context: ModelContext) async throws {
        let hoursElapsed = session.currentHourIndex + 1
        session.startedAt = Date.now.addingTimeInterval(-Double(hoursElapsed) * 3600)
        try await refreshSessionStatus(session, context: context)
    }

    func debugSimulatePartnerPhoto(_ session: StrangerSession, context: ModelContext) async throws {
        let data = Data([0x01, 0x02, 0x03])
        try await submitPhoto(data, weatherSummary: session.partnerWeatherSummary, for: session, context: context)
    }
    #endif

    func activeSession(from sessions: [StrangerSession]) -> StrangerSession? {
        sessions
            .sorted { $0.startedAt > $1.startedAt }
            .first
    }
}
