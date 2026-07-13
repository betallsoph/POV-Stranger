import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionManager.self) private var sessionManager
    @Query private var sessions: [StrangerSession]

    @State private var matchError: String?

    var body: some View {
        NavigationStack {
            Group {
                if let session = activeSession {
                    switch session.status {
                    case .ended:
                        SessionEndedView(session: session) {
                            purgeSession(session)
                        }
                    case .farewell, .active:
                        ActiveSessionView(session: session)
                    }
                } else {
                    WaitingForMatchView(
                        isMatching: sessionManager.isMatching,
                        onFindStranger: findStranger
                    )
                }
            }
        }
        .alert("Could not find a stranger", isPresented: .init(
            get: { matchError != nil },
            set: { if !$0 { matchError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(matchError ?? "")
        }
    }

    private var activeSession: StrangerSession? {
        sessionManager.activeSession(from: sessions)
    }

    private func findStranger() {
        Task {
            _ = await HourlyReminderScheduler.requestAuthorization()
            do {
                _ = try await sessionManager.findMatch(context: modelContext)
            } catch let error as SessionServiceError {
                matchError = error.errorDescription
            } catch {
                matchError = error.localizedDescription
            }
        }
    }

    private func purgeSession(_ session: StrangerSession) {
        try? sessionManager.endSession(session, context: modelContext)
    }
}

#Preview {
    RootView()
        .environment(SessionManager())
        .modelContainer(for: [StrangerSession.self, HourSlot.self], inMemory: true)
}
