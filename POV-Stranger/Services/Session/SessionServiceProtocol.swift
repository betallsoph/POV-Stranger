import Foundation
import SwiftData

@MainActor
protocol SessionServiceProtocol {
    var isCloudBacked: Bool { get }

    func findMatch(context: ModelContext) async throws -> MatchResult
    func submitPhoto(
        _ imageData: Data,
        weatherSummary: String,
        for session: StrangerSession,
        context: ModelContext
    ) async throws
    func submitFarewell(
        _ text: String,
        for session: StrangerSession,
        context: ModelContext
    ) async throws
}
