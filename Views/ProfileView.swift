import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var rideStore: RideStore
    @EnvironmentObject private var syncService: SyncService
    @AppStorage("defaultStorageMode") private var defaultStorageModeRaw: String = StorageMode.localOnly.rawValue

    @State private var isLoggingOut = false
    @State private var showDeleteAccountConfirm = false
    @State private var isDeleting = false
    @State private var showDeleteError = false
    @State private var showPrivacyPolicy = false

    private var defaultStorageMode: StorageMode {
        StorageMode(rawValue: defaultStorageModeRaw) ?? .localOnly
    }

    private var profile: UserProfile? { authService.state.profile }

    private var identityHeadline: String {
        if let name = profile?.displayName, !name.isEmpty { return name }
        if let email = profile?.email, !email.isEmpty     { return email }
        return "Signed in"
    }

    private var identitySubtitle: String? {
        guard let name = profile?.displayName, !name.isEmpty else { return nil }
        return profile?.email
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

    private var syncBadge: String? {
        let failed  = rideStore.failedSyncRides.count
        let pending = rideStore.pendingUploadRides.count
        if failed > 0  { return "\(failed) sync failed" }
        if pending > 0 { return "\(pending) pending" }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // Avatar + identity
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.appSurface2)
                            .frame(width: 96, height: 96)
                        Image(systemName: "person.fill")
                            .font(.system(size: 42, weight: .medium))
                            .foregroundStyle(Color.appAccent)
                    }
                    .padding(.top, 32)

                    VStack(spacing: 6) {
                        Text(identityHeadline)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)

                        if let subtitle = identitySubtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(1)
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "icloud.fill")
                                .font(.system(size: 12))
                            Text("Cloud sync active")
                                .font(.subheadline)
                        }
                        .foregroundStyle(Color.appAccent)

                        if let badge = syncBadge {
                            Text(badge)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 28)

                // Personal bests
                VStack(alignment: .leading, spacing: 10) {
                    Text("PERSONAL BESTS")
                        .font(.system(size: 11, weight: .semibold))
                        .kerning(0.8)
                        .foregroundStyle(Color.textGhost)
                        .padding(.horizontal, 24)

                    if rideStore.rides.isEmpty {
                        Text("Record your first ride to see your stats here.")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                            .padding(.horizontal, 24)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            personalBestCard(label: "Max Lean Right", value: allTimeMaxLeanRight > 0 ? String(format: "%.1f°", allTimeMaxLeanRight) : "—", icon: "rotate.right.fill")
                            personalBestCard(label: "Max Lean Left",  value: allTimeMaxLeanLeft  > 0 ? String(format: "%.1f°", allTimeMaxLeanLeft)  : "—", icon: "rotate.left.fill")
                            personalBestCard(label: "Max Speed",      value: allTimeMaxSpeedMph  > 0 ? String(format: "%.1f mph", allTimeMaxSpeedMph) : "—", icon: "speedometer")
                            personalBestCard(label: "Total Distance", value: String(format: "%.1f mi", totalDistanceMi), icon: "road.lanes")
                        }
                        .padding(.horizontal, 16)

                        HStack {
                            Image(systemName: "flag.checkered")
                                .font(.system(size: 12))
                            Text("\(totalRides) ride\(totalRides == 1 ? "" : "s") total")
                                .font(.subheadline)
                        }
                        .foregroundStyle(Color.textSecondary)
                        .padding(.horizontal, 24)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 28)

                // Account actions
                VStack(spacing: 10) {
                    PrimaryButton(
                        title: "Sign Out",
                        isLoading: isLoggingOut,
                        isDestructive: true
                    ) {
                        Task { await logOut() }
                    }

                    Button {
                        showDeleteAccountConfirm = true
                    } label: {
                        Text("Delete Account")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)

                // Privacy policy link
                Button {
                    showPrivacyPolicy = true
                } label: {
                    Text("Privacy Policy")
                        .font(.caption)
                        .foregroundStyle(Color.appAccent)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 12)

                Spacer(minLength: 100)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { profileHeader }
        .background(Color.appBg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Delete Account?",
                            isPresented: $showDeleteAccountConfirm,
                            titleVisibility: .visible) {
            Button("Delete My Account and Data", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete all your rides, bikes, and account data. This cannot be undone.")
        }
        .alert("Delete Failed", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Could not delete your account. Please try again or contact support.")
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicySheet()
        }
    }

    private var profileHeader: some View {
        HStack {
            Text("Profile")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            NavigationLink {
                SettingsView()
                    .environmentObject(rideStore)
                    .environmentObject(syncService)
                    .environmentObject(authService)
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .background(Color.appBg)
    }

    private func logOut() async {
        isLoggingOut = true
        await authService.signOut()
        isLoggingOut = false
    }

    private func personalBestCard(label: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.3)
                    .foregroundStyle(Color.textGhost)
            }
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.appAccent)
                .minimumScaleFactor(0.7)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func deleteAccount() async {
        isDeleting = true
        do {
            try await authService.deleteAccount()
        } catch {
            showDeleteError = true
        }
        isDeleting = false
    }
}

// MARK: - Privacy Policy Sheet

struct PrivacyPolicySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("RaceLine Privacy Policy")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.textPrimary)

                        Text("Last updated: June 2026")
                            .font(.caption)
                            .foregroundStyle(Color.textTertiary)

                        privacySection("What we collect", """
RaceLine collects only the data you choose to provide: your email address (for account creation), ride stats, and optionally GPS route data if you enable full cloud sync.

By default, GPS routes are stored locally on your device only. Cloud sync uploads summary statistics (speed, distance, lean angles) without your exact GPS route unless you explicitly enable full route sync.
""")

                        privacySection("Your account", """
RaceLine requires an account so your rides sync across the iOS app and the web dashboard. We only store what you explicitly opt to upload — ride summaries by default, full GPS routes only if you turn them on.
""")

                        privacySection("Cloud sync", """
If you enable cloud sync, ride summaries are stored in a private Supabase database. Only you can access your data. Full GPS route data is only uploaded if you choose "Cloud Full Data" storage mode with an explicit privacy warning.
""")

                        privacySection("Data deletion", """
You can delete your account and all associated data at any time from Profile → Delete Account. This permanently removes all rides, bikes, and media from our servers.
""")

                        privacySection("Third parties", """
RaceLine does not sell or share your data with third parties. We use Supabase for database and authentication services, and Apple/Google for sign-in.
""")

                        privacySection("Contact", """
For privacy questions, contact us at: privacy@raceline.app
""")
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color.appBg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.appAccent)
                }
            }
        }
    }

    private func privacySection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
