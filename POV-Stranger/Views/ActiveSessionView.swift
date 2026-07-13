import SwiftUI
import SwiftData
import Combine

struct ActiveSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionManager.self) private var sessionManager

    @Bindable var session: StrangerSession
    @State private var showingCapture = false
    @State private var farewellText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SessionCountdownView(session: session)

                if let latestSlot = latestPartnerSlot, latestSlot.theirPhotoData != nil {
                    PartnerPhotoCard(slot: latestSlot, session: session)
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
                    FarewellComposeView(text: $farewellText) {
                        sendFarewell()
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
                try? sessionManager.submitPhoto(imageData, for: session, context: modelContext)
            }
        }
        .onAppear { refreshStatus() }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            refreshStatus()
        }
    }

    private var latestPartnerSlot: HourSlot? {
        session.slots
            .filter { $0.theirPhotoData != nil }
            .sorted { ($0.theirCapturedAt ?? .distantPast) > ($1.theirCapturedAt ?? .distantPast) }
            .first
    }

    private func refreshStatus() {
        try? sessionManager.refreshSessionStatus(session, context: modelContext)
    }

    private func sendFarewell() {
        try? sessionManager.submitFarewell(farewellText, for: session, context: modelContext)
        farewellText = ""
    }

    #if DEBUG
    @ViewBuilder
    private var debugControls: some View {
        VStack(spacing: 8) {
            Text("Debug")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Simulate partner photo") {
                let data = Data([0x01, 0x02, 0x03])
                try? sessionManager.submitPhoto(data, for: session, context: modelContext)
            }
            .buttonStyle(.bordered)
        }
    }
    #endif
}

private struct PartnerPhotoCard: View {
    let slot: HourSlot
    let session: StrangerSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Through their eyes · Hour \(slot.hourIndex + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.6), .purple.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 220)

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
