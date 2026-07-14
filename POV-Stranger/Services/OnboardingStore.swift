import Foundation

enum OnboardingStore {
    private static let key = "onboardingCompleted"

    static var isComplete: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func markComplete() {
        UserDefaults.standard.set(true, forKey: key)
    }
}
