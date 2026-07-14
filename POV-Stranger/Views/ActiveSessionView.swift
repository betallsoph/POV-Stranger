import SwiftUI
import SwiftData
import Combine
import UIKit

struct ActiveSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionManager.self) private var sessionManager

    @Bindable var session: StrangerSession
    @State private var showingCapture = false
    @State private var farewellText = ""
    @State private var showingReportConfirm = false
    @State private var reportError: String?

    private let safetyService = SafetyService()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SessionCountdownView(session: session)

                if let latestSlot = latestPartnerSlot, latestSlot.theirPhotoData != nil {
                    PartnerPhotoCard(
                        slot: latestSlot,
                        session: session,
                        onReport: { showingReportConfirm = true }
                    )
                } else {
                    ContentUnavailableView(
                        "Waiting for their world",
                        systemImage: "eye.trianglebadge.exclamationmark",
                        description: Text("Your stranger hasn't shared this hour yet.")
                    )
                    .frame(height: 180)
                }

                PartnerMetadataCard(session: session)

                HourTimelineView(
                    session: session,
                    currentHourIndex: session.currentHourIndex
                )

                if session.status == .farewell {
                    FarewellComposeView(
                        text: $farewellText,
                        hasSent: session.myFarewellText != nil
                    ) {
                        Task { await sendFarewell() }
                    }
                }

                #if DEBUG
                debugControls
                #endif
            }
            .padding()
        }
        .navigationTitle("Your stranger")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCapture = true
                } label: {
                    Label("Capture", systemImage: "camera.fill")
                }
                .disabled(session.isExpired)
            }
        }
        .sheet(isPresented: $showingCapture) {
            CapturePhotoView { imageData in
                Task {
                    try? await sessionManager.submitPhoto(
                        imageData,
                        weatherSummary: session.partnerWeatherSummary,
                        for: session,
                        context: modelContext
                    )
                }
            }
        }
        .onAppear {
            Task { await refreshStatus() }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            Task { await refreshStatus() }
        }
        .confirmationDialog(
            "Report this photo?",
            isPresented: $showingReportConfirm,
            titleVisibility: .visible
        ) {
            Button("Report & block", role: .destructive) {
                Task { await reportPartner() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They'll be blocked and this session will end immediately.")
        }
        .alert("Couldn't submit report", isPresented: .init(
            get: { reportError != nil },
            set: { if !$0 { reportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(reportError ?? "")
        }
    }

    private var latestPartnerSlot: HourSlot? {
        session.slots
            .filter { $0.theirPhotoData != nil }
            .sorted { ($0.theirCapturedAt ?? .distantPast) > ($1.theirCapturedAt ?? .distantPast) }
            .first
    }

    private func refreshStatus() async {
        try? await sessionManager.refreshSessionStatus(session, context: modelContext)
    }

    private func sendFarewell() async {
        try? await sessionManager.submitFarewell(farewellText, for: session, context: modelContext)
        farewellText = ""
    }

    private func reportPartner() async {
        do {
            try await safetyService.reportAndBlock(
                session: session,
                reason: "inappropriate_content",
                context: modelContext
            )
            WidgetDataStore.clear()
            await HourlyReminderScheduler.cancelAll()
        } catch {
            reportError = error.localizedDescription
        }
    }

    #if DEBUG
    @ViewBuilder
    private var debugControls: some View {
        VStack(spacing: 8) {
            Text("Debug")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Simulate partner photo") {
                Task {
                    try? await sessionManager.debugSimulatePartnerPhoto(session, context: modelContext)
                }
            }
            .buttonStyle(.bordered)

            Button("Advance 1 hour") {
                Task {
                    try? await sessionManager.debugAdvanceHour(session, context: modelContext)
                }
            }
            .buttonStyle(.bordered)

            Button("Enter farewell window") {
                try? sessionManager.debugEnterFarewellWindow(session, context: modelContext)
            }
            .buttonStyle(.bordered)

            Button("End session now") {
                try? sessionManager.debugExpireSession(session, context: modelContext)
            }
            .buttonStyle(.bordered)
        }
    }
    #endif
}

private struct PartnerPhotoCard: View {
    let slot: HourSlot
    let session: StrangerSession
    let onReport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Through their eyes · Hour \(slot.hourIndex + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: onReport) {
                    Label("Report", systemImage: "flag")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
            }

            ZStack(alignment: .bottomLeading) {
                Group {
                    if let data = slot.theirPhotoData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        LinearGradient(
                            colors: [.blue.opacity(0.6), .purple.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.formattedDistance)
                        .font(.caption.bold())
                    Text("\(session.partnerWeatherSummary) · \(session.partnerLocalTime)")
                        .font(.caption2)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .padding(12)
            }
        }
    }
}

#Preview {
    let session = StrangerSession(
        partnerDistanceKm: 12_400,
        partnerCountryCode: "IS",
        partnerCountryName: "Iceland",
        partnerWeatherSummary: "Snow · -2°C",
        partnerTimeZoneIdentifier: "Atlantic/Reykjavik"
    )

    return NavigationStack {
        ActiveSessionView(session: session)
            .environment(SessionManager())
    }
    .modelContainer(for: [StrangerSession.self, HourSlot.self], inMemory: true)
}
