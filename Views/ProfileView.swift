import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authService: AuthService
    @AppStorage("cloudSyncEnabled") private var cloudSyncEnabled: Bool = false
    @AppStorage("localOnlyMode") private var localOnlyMode: Bool = false

    @State private var isLoggingOut = false
    @State private var showLogoutError = false
    @State private var showSignInPrompt = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Avatar + identity
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.appSurface2)
                            .frame(width: 96, height: 96)
                        Image(systemName: authService.isLoggedIn ? "person.fill" : "person")
                            .font(.system(size: 42, weight: .medium))
                            .foregroundStyle(authService.isLoggedIn ? Color.appAccent : Color.textGhost)
                    }
                    .padding(.top, 32)

                    VStack(spacing: 6) {
                        if authService.isLoggedIn {
                            Text(authService.userEmail ?? "Signed in")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Color.textPrimary)
                            HStack(spacing: 6) {
                                Image(systemName: "icloud.fill")
                                    .font(.system(size: 12))
                                Text("Cloud sync available")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(Color.appAccent)
                        } else {
                            Text("Not signed in")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Color.textPrimary)
                            Text("Rides saved on this device only")
                                .font(.subheadline)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 32)

                // Action button
                if authService.isLoggedIn {
                    PrimaryButton(
                        title: "Sign Out",
                        isLoading: isLoggingOut,
                        isDestructive: true
                    ) {
                        Task { await logOut() }
                    }
                    .padding(.horizontal, 24)
                } else {
                    PrimaryButton(title: "Sign In or Create Account") {
                        showSignInPrompt = true
                    }
                    .padding(.horizontal, 24)
                }

                // Info row when not logged in
                if !authService.isLoggedIn {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textGhost)
                        Text("Your rides stay private and local until you choose to sign in.")
                            .font(.caption)
                            .foregroundStyle(Color.textGhost)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                    .multilineTextAlignment(.center)
                }
            }
            .padding(.bottom, 100)
        }
        .background(Color.appBg.ignoresSafeArea())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appSurface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
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
