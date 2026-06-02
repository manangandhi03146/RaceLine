import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var rideStore: RideStore
    @AppStorage("cloudSyncEnabled") private var cloudSyncEnabled: Bool = false
    @AppStorage("hasChosenStorageMode") private var hasChosenStorageMode: Bool = false

    // MARK: - All-time stat aggregates
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
            // Personal bests section
            Section {
                if rideStore.rides.isEmpty {
                    Text("Record your first ride to see your stats here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    personalBestRow(
                        label: "Max Lean — Right",
                        value: allTimeMaxLeanRight > 0
                            ? String(format: "%.1f°", allTimeMaxLeanRight) : "—",
                        icon: "rotate.right.fill"
                    )
                    personalBestRow(
                        label: "Max Lean — Left",
                        value: allTimeMaxLeanLeft > 0
                            ? String(format: "%.1f°", allTimeMaxLeanLeft) : "—",
                        icon: "rotate.left.fill"
                    )
                    personalBestRow(
                        label: "Max Speed",
                        value: allTimeMaxSpeedMph > 0
                            ? String(format: "%.1f mph", allTimeMaxSpeedMph) : "—",
                        icon: "speedometer"
                    )
                    Divider()
                    HStack {
                        Label("\(totalRides) ride\(totalRides == 1 ? "" : "s")",
                              systemImage: "flag.checkered")
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

            // Cloud sync section
            Section {
                Toggle(isOn: $cloudSyncEnabled) {
                    Label("Sync photos to cloud", systemImage: "icloud.and.arrow.up")
                }
                .tint(Color.appAccent)
                .disabled(!authService.isLoggedIn)
                .onChange(of: cloudSyncEnabled) { _, newValue in
                    if newValue { hasChosenStorageMode = true }
                }

                if cloudSyncEnabled && authService.isLoggedIn {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 14))
                        Text("New ride and bike photos upload to your private cloud storage automatically.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if !authService.isLoggedIn {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14))
                        Text("Sign in via the Profile tab to enable cloud photo sync.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Storage")
            } footer: {
                if authService.isLoggedIn {
                    Text("Photos are uploaded to your private account area and protected by your login. Only you can access them.")
                }
            }

            // Privacy section
            Section {
                Label("Ride routes are stored locally unless you explicitly choose cloud sync.", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("No data is shared with third parties.", systemImage: "hand.raised.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Privacy")
            }

            // App info
            Section {
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
}
