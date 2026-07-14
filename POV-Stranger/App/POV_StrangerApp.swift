import SwiftData
import SwiftUI

@main
struct POV_StrangerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var authManager = AuthManager()
    @State private var sessionManager = SessionManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            StrangerSession.self,
            HourSlot.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(sessionManager)
                .environment(authManager)
                .onAppear {
                    RemoteNotificationHandler.shared.configure(modelContainer: sharedModelContainer)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
