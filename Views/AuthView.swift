import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var authService: AuthService
    @AppStorage("localOnlyMode") private var localOnlyMode: Bool = false

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var showEmailConfirmBanner = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.appAccent.opacity(0.15))
                            .frame(width: 88, height: 88)
                        Image(systemName: "motorcycle")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                    }
                    .padding(.top, 56)
                    .padding(.bottom, 2)

                    Text("MotorcycleTrackShare")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Track rides. Share the feeling.")
                        .font(.subheadline)
                        .foregroundStyle(Color(white: 0.55))
                }
                .padding(.bottom, 36)

                // Card
                VStack(spacing: 14) {
                    Picker("", selection: $isSignUp) {
                        Text("Log In").tag(false)
                        Text("Sign Up").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: isSignUp) { _, _ in
                        errorMessage = nil
                        showEmailConfirmBanner = false
                    }

                    if showEmailConfirmBanner {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope.badge")
                                .foregroundStyle(Color.appAccent)
                            Text("Check your email to confirm your account.")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appAccent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    VStack(spacing: 10) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .textFieldStyle(.roundedBorder)

                        SecureField("Password", text: $password)
                            .textContentType(isSignUp ? .newPassword : .password)
                            .textFieldStyle(.roundedBorder)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    PrimaryButton(
                        title: isSignUp ? "Create Account" : "Log In",
                        isLoading: isBusy
                    ) {
                        Task { await submit() }
                    }
                }
                .minimalCard()
                .padding(.horizontal, 20)

                HStack {
                    Rectangle().fill(Color.appDivider).frame(height: 1)
                    Text("or")
                        .font(.subheadline)
                        .foregroundStyle(Color(white: 0.45))
                        .padding(.horizontal, 10)
                    Rectangle().fill(Color.appDivider).frame(height: 1)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)

                VStack(spacing: 8) {
                    SecondaryButton(title: "Continue without signing in") {
                        localOnlyMode = true
                    }

                    Text("Rides and bikes are stored locally on this device only.")
                        .font(.caption)
                        .foregroundStyle(Color(white: 0.45))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 40)
            }
        }
        .background(Color.appBg.ignoresSafeArea())
    }

    private func submit() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }

        isBusy = true
        errorMessage = nil
        showEmailConfirmBanner = false

        do {
            if isSignUp {
                try await authService.signUp(email: trimmedEmail, password: trimmedPassword)
                if !authService.isLoggedIn {
                    showEmailConfirmBanner = true
                }
            } else {
                try await authService.signIn(email: trimmedEmail, password: trimmedPassword)
            }
        } catch {
            errorMessage = friendlyError(error)
        }

        isBusy = false
    }

    private func friendlyError(_ error: Error) -> String {
        let msg = error.localizedDescription.lowercased()
        if msg.contains("invalid login credentials") || msg.contains("invalid_credentials") {
            return "Incorrect email or password."
        }
        if msg.contains("email") && msg.contains("already") {
            return "An account with this email already exists."
        }
        if msg.contains("password") && msg.contains("weak") {
            return "Password must be at least 6 characters."
        }
        if msg.contains("network") || msg.contains("offline") || msg.contains("connect") {
            return "Network error. Please check your connection."
        }
        return "Something went wrong. Please try again."
    }
}
