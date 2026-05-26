import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authService: AuthService
    @AppStorage("cloudSyncEnabled") private var cloudSyncEnabled: Bool = false
    @AppStorage("localOnlyMode") private var localOnlyMode: Bool = false
    @AppStorage("hasChosenStorageMode") private var hasChosenStorageMode: Bool = false

    @State private var isLoggingOut = false
    @State private var showLogoutError = false
    @State private var showSignInPrompt = false

    var body: some View {
        List {
            // Account section
            Section {
                if authService.isLoggedIn {
                    HStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.appAccent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(authService.userEmail ?? "Signed in")
                                .font(.headline)
                            Text("Cloud sync available")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    Button(role: .destructive) {
                        Task { await logOut() }
                    } label: {
                        HStack {
                            if isLoggingOut {
                                ProgressView().frame(width: 20, height: 20)
                            } else {
                                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        }
                    }
                    .disabled(isLoggingOut)
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Local mode")
                                .font(.headline)
                            Text("Rides saved on this device only")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    Button {
                        showSignInPrompt = true
                    } label: {
                        Label("Sign in or create account", systemImage: "arrow.right.circle")
                    }
                }
            } header: {
                Text("Account")
            }

            // Cloud sync section
            Section {
                Toggle(isOn: $cloudSyncEnabled) {
                    Label("Sync photos to cloud", systemImage: "icloud.and.arrow.up")
                }
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
                        Text("Sign in to enable cloud photo sync.")
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
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("Sign Out Failed", isPresented: $showLogoutError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please try again.")
        }
        .sheet(isPresented: $showSignInPrompt) {
            NavigationStack {
                AuthView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showSignInPrompt = false }
                        }
                    }
            }
        }
    }

    private func logOut() async {
        isLoggingOut = true
        do {
            cloudSyncEnabled = false
            try await authService.signOut()
            localOnlyMode = true
        } catch {
            showLogoutError = true
        }
        isLoggingOut = false
    }
}
