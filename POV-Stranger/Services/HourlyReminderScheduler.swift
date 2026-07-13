import Foundation
import UserNotifications

enum HourlyReminderScheduler {
    private static let center = UNUserNotificationCenter.current()
    private static let categoryIdentifier = "hourly.capture"

    static func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    static func schedule(for session: StrangerSession) async {
        await cancelAll()

        let granted = await authorizationStatus() == .authorized
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.categoryIdentifier = categoryIdentifier
        content.sound = .default

        for hour in session.currentHourIndex..<24 {
            let fireDate = session.startedAt.addingTimeInterval(Double(hour + 1) * 3600)
            guard fireDate > .now, fireDate < session.expiresAt else { continue }

            let hourNumber = hour + 1
            content.title = "Hour \(hourNumber) — your stranger is watching"
            content.body = "Share one photo from your world before this hour passes."

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: notificationID(sessionID: session.id, hour: hour),
                content: content,
                trigger: trigger
            )

            try? await center.add(request)
        }

        await scheduleFarewellReminder(for: session)
    }

    static func cancelAll() async {
        center.removeAllPendingNotificationRequests()
    }

    private static func scheduleFarewellReminder(for session: StrangerSession) async {
        let farewellDate = session.expiresAt.addingTimeInterval(-2 * 60 * 60)
        guard farewellDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Almost gone"
        content.body = "You have one message left for your stranger. Then you both disappear."
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: farewellDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "farewell.\(session.id.uuidString)",
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    private static func notificationID(sessionID: UUID, hour: Int) -> String {
        "hour.\(sessionID.uuidString).\(hour)"
    }
}
