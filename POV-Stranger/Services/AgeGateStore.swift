import Foundation

enum AgeGateStore {
    private static let key = "ageGateConfirmed"

    static var isConfirmed: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func confirm() {
        UserDefaults.standard.set(true, forKey: key)
    }
}
