import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var rideStore: RideStore
    @EnvironmentObject private var syncService: SyncService

    @AppStorage("defaultStorageMode")        private var defaultStorageModeRaw: String = StorageMode.localOnly.rawValue
    @AppStorage("samplingRateHz")            private var samplingRateHz: Double = 10
    @AppStorage("preferredUnits")            private var preferredUnits: String = "imperial"
    @AppStorage("hideRouteByDefault")        private var hideRouteByDefault: Bool = true
    @AppStorage("routeHideDistanceMiles")    private var routeHideDistanceMiles: Double = 0.25
    @AppStorage("cloudSyncPaused")           private var cloudSyncPaused: Bool = false

    @State private var showFullRouteWarning = false
    @State private var pendingStorageMode: StorageMode?
    @State private var showForceResyncConfirm = false

    private var defaultStorageMode: StorageMode {
        StorageMode(rawValue: defaultStorageModeRaw)?.canonical ?? .localOnly
    }

    // MARK: - All-time stats

    private var allTimeMaxSpeedMph: Double {
        rideStore.rides.map { $0.summary.maxSpeedMph }.max() ?? 0
    }
    private var allTimeMaxLeanRight: Double {
        rideStore.rides.map { $0.summary.maxLeanRightDeg }.max() ?? 0
    }
    private var allTimeMaxLeanLeft: Double {
        rideStore.rides.map { $0.summary.maxLeanLeftDeg }.max() ?? 0
    }
    private var totalDistanceMi: Double {
        rideStore.rides.reduce(0) { $0 + $1.summary.distanceMi }
    }
    private var totalRides: Int { rideStore.rides.count }

    var body: some View {
        List {
            // Personal bests
            Section {
                if rideStore.rides.isEmpty {
                    Text("Record your first ride to see your stats here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    personalBestRow(label: "Max Lean — Right",
                                    value: allTimeMaxLeanRight > 0 ? String(format: "%.1f°", allTimeMaxLeanRight) : "—",
                                    icon: "rotate.right.fill")
                    personalBestRow(label: "Max Lean — Left",
                                    value: allTimeMaxLeanLeft > 0 ? String(format: "%.1f°", allTimeMaxLeanLeft) : "—",
                                    icon: "rotate.left.fill")
                    personalBestRow(label: "Max Speed",
                                    value: allTimeMaxSpeedMph > 0 ? String(format: "%.1f mph", allTimeMaxSpeedMph) : "—",
                                    icon: "speedometer")
                    Divider()
                    HStack {
                        Label("\(totalRides) ride\(totalRides == 1 ? "" : "s")", systemImage: "flag.checkered")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.1f mi total", totalDistanceMi))
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }
            } header: {
                Text("Personal Bests")
            }

            // Cloud sync
            if authService.isLoggedIn {
                Section {
                    // Sync status
                    HStack {
                        Label("Sync Status", systemImage: syncStatusIcon)
                        Spacer()
                        Text(syncStatusText)
                            .font(.subheadline)
                            .foregroundStyle(syncStatusColor)
                    }

                    if let lastSync = syncService.lastSyncDate {
                        HStack {
                            Label("Last Synced", systemImage: "clock")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle(isOn: $cloudSyncPaused) {
                        Label("Pause Cloud Sync", systemImage: "pause.circle")
                    }
                    .tint(Color.appAccent)

                    if !cloudSyncPaused && !syncService.isSyncing {
                        Button {
                            Task { await syncService.syncNow() }
                        } label: {
                            Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                                .foregroundStyle(Color.appAccent)
                        }

                        Button {
                            showForceResyncConfirm = true
                        } label: {
                            Label("Re-sync All Data", systemImage: "arrow.clockwise.icloud")
                                .foregroundStyle(Color.appAccent)
                        }
                        .confirmationDialog(
                            "Re-sync All Data?",
                            isPresented: $showForceResyncConfirm,
                            titleVisibility: .visible
                        ) {
                            Button("Re-sync All") {
                                Task { await syncService.forceResyncAll() }
                            }
                            Button("Cancel", role: .cancel) { }
                        } message: {
                            Text("This will re-upload all rides and bikes to the cloud. Use this if your data is missing from the web dashboard.")
                        }
                    }

                    if syncService.isSyncing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Syncing…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Cloud Sync")
                } footer: {
                    if let error = syncService.lastSyncError {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }

            // Default storage mode
            Section {
                Picker("Default Storage", selection: Binding(
                    get: { defaultStorageMode },
                    set: { newMode in
                        if newMode.uploadsFullTelemetry {
                            pendingStorageMode = newMode
                            showFullRouteWarning = true
                        } else {
                            defaultStorageModeRaw = newMode.rawValue
                        }
                    }
                )) {
                    ForEach([StorageMode.localOnly, .cloudSummaryOnly, .cloudFull, .localAndCloudFull], id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .disabled(!authService.isLoggedIn)
            } header: {
                Text("Default Storage Mode")
            } footer: {
                Text(storageModeFooter)
                    .font(.caption)
            }

            // Recording
            Section {
                Picker("Sampling Rate", selection: $samplingRateHz) {
                    Text("Low Battery (1 Hz)").tag(1.0)
                    Text("Standard (10 Hz)").tag(10.0)
                    Text("High Detail (25 Hz)").tag(25.0)
                    Text("Track / Max (50 Hz)").tag(50.0)
                }

                Picker("Units", selection: $preferredUnits) {
                    Text("Imperial (mph, mi)").tag("imperial")
                    Text("Metric (km/h, km)").tag("metric")
                }
            } header: {
                Text("Recording")
            } footer: {
                if samplingRateHz >= 25 {
                    Text("High sampling rates use more battery and storage.")
                        .font(.caption)
                }
            }

            // Route privacy
            Section {
                Toggle("Hide Route Start/End by Default", isOn: $hideRouteByDefault)
                    .tint(Color.appAccent)

                if hideRouteByDefault {
                    Picker("Hide Distance", selection: $routeHideDistanceMiles) {
                        Text("0.1 mile").tag(0.1)
                        Text("0.25 mile").tag(0.25)
                        Text("0.5 mile").tag(0.5)
                        Text("1.0 mile").tag(1.0)
                    }
                }
            } header: {
                Text("Route Privacy")
            } footer: {
                Text("Hides the start and end of your route on share cards and web maps to protect your home, school, and frequent locations.")
                    .font(.caption)
            }

            // App info
            Section {
                HStack {
                    Text("App")
                    Spacer()
                    Text("Tread")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("About")
            }
        }
        .contentMargins(.bottom, 80, for: .scrollContent)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color.appSurface, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .confirmationDialog("Full Route Upload",
                            isPresented: $showFullRouteWarning,
                            titleVisibility: .visible) {
            Button("Enable Full Route Sync", role: .destructive) {
                if let mode = pendingStorageMode {
                    defaultStorageModeRaw = mode.rawValue
                }
                pendingStorageMode = nil
            }
            Button("Cancel", role: .cancel) {
                pendingStorageMode = nil
            }
        } message: {
            Text("Full route data includes exact GPS coordinates that can reveal your home, workplace, and frequently visited locations. Are you sure?")
        }
    }

    private func personalBestRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appAccent)
        }
    }

    private var syncStatusIcon: String {
        let failed  = rideStore.failedSyncRides.count
        let pending = rideStore.pendingUploadRides.count
        if failed > 0  { return "exclamationmark.icloud" }
        if pending > 0 { return "icloud.and.arrow.up" }
        return "checkmark.icloud"
    }

    private var syncStatusText: String {
        let failed  = rideStore.failedSyncRides.count
        let pending = rideStore.pendingUploadRides.count
        if failed > 0  { return "\(failed) failed" }
        if pending > 0 { return "\(pending) pending" }
        return "Up to date"
    }

    private var syncStatusColor: Color {
        let failed  = rideStore.failedSyncRides.count
        if failed > 0 { return .red }
        if rideStore.pendingUploadRides.count > 0 { return .orange }
        return .green
    }

    private var storageModeFooter: String {
        if !authService.isLoggedIn {
            return "Sign in to enable cloud storage modes."
        }
        switch defaultStorageMode {
        case .localOnly:
            return "Rides are saved only on this device."
        case .localAndCloudFull, .cloudFull:
            return "Warning: full GPS route data is uploaded, including exact coordinates."
        default:
            return "Ride stats sync to the cloud. GPS routes stay on your device."
        }
    }
}
