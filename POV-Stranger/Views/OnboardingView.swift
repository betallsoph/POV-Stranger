import AVFoundation
import SwiftUI

struct OnboardingView: View {
    @State private var page = 0
    @State private var cameraGranted = CameraPermission.authorizationStatus() == .authorized
    @State private var notificationsGranted = false

    let onComplete: () -> Void

    var body: some View {
        TabView(selection: $page) {
            conceptPage.tag(0)
            permissionsPage.tag(1)
            readyPage.tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .task {
            notificationsGranted = await HourlyReminderScheduler.authorizationStatus() == .authorized
        }
    }

    private var conceptPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "globe.americas.fill")
                .font(.largeTitle)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("onboarding.concept.title", tableName: "Localizable")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("onboarding.concept.subtitle", tableName: "Localizable")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("onboarding.concept.pair", tableName: "Localizable")
                } icon: {
                    Image(systemName: "person.2.fill")
                }
                Label {
                    Text("onboarding.concept.hourly", tableName: "Localizable")
                } icon: {
                    Image(systemName: "camera.fill")
                }
                Label {
                    Text("onboarding.concept.ephemeral", tableName: "Localizable")
                } icon: {
                    Image(systemName: "hourglass")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .povGlassCard()

            Spacer()

            Button { page = 1 } label: {
                Text("onboarding.next", tableName: "Localizable")
                    .povGlassProminentButton()
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    private var permissionsPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("onboarding.permissions.title", tableName: "Localizable")
                .font(.title.bold())

            Text("onboarding.permissions.subtitle", tableName: "Localizable")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                permissionRow(
                    title: String(localized: "onboarding.permissions.camera", table: "Localizable"),
                    granted: cameraGranted,
                    systemImage: "camera.fill"
                ) {
                    Task { cameraGranted = await CameraPermission.requestIfNeeded() }
                }

                permissionRow(
                    title: String(localized: "onboarding.permissions.notifications", table: "Localizable"),
                    granted: notificationsGranted,
                    systemImage: "bell.fill"
                ) {
                    Task { notificationsGranted = await HourlyReminderScheduler.requestAuthorization() }
                }
            }
            .povGlassCard()

            Spacer()

            Button { page = 2 } label: {
                Text("onboarding.next", tableName: "Localizable")
                    .povGlassProminentButton()
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    private var readyPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("onboarding.ready.title", tableName: "Localizable")
                .font(.title.bold())

            Text("onboarding.ready.subtitle", tableName: "Localizable")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: onComplete) {
                Text("onboarding.ready.cta", tableName: "Localizable")
                    .povGlassProminentButton()
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    private func permissionRow(
        title: String,
        granted: Bool,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
            Spacer()
            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel(String(localized: "onboarding.permission.granted", table: "Localizable"))
            } else {
                Button(String(localized: "onboarding.permission.enable", table: "Localizable"), action: action)
                    .font(.caption.bold())
            }
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
