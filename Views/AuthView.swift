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
    @State private var showForgotPassword = false

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

                    Text("Tread")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)

                    Text("Privacy-first ride tracking.")
                        .font(.subheadline)
                        .foregroundStyle(Color(white: 0.55))
                }
                .padding(.bottom, 36)

                // Auth card
                VStack(spacing: 14) {
                    Picker("", selection: $isSignUp) {
                        Text("Sign In").tag(false)
                        Text("Create Account").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: isSignUp) { _, _ in
                        errorMessage = nil
                    }

                    if showEmailConfirmBanner {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "envelope.badge.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.appAccent)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Check your email")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.textPrimary)
                                Text("We sent a confirmation link to \(email). Tap it, then come back and sign in.")
                                    .font(.caption)
                                    .foregroundStyle(Color.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appAccent.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.appAccent.opacity(0.5), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    VStack(spacing: 10) {
                        TextField("", text: $email, prompt: .appPrompt("Email"))
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .foregroundStyle(Color.textPrimary)
                            .appFieldChrome()

                        SecureField("", text: $password, prompt: .appPrompt("Password"))
                            .textContentType(isSignUp ? .newPassword : .password)
                            .foregroundStyle(Color.textPrimary)
                            .appFieldChrome()
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    PrimaryButton(
                        title: isSignUp ? "Create Account" : "Sign In",
                        isLoading: isBusy
                    ) {
                        Task { await submit() }
                    }

                    if !isSignUp {
                        Button {
                            showForgotPassword = true
                        } label: {
                            Text("Forgot Password?")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.appAccent)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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
                    Text("Rides stay private and stored on this device only.")
                        .font(.caption)
                        .foregroundStyle(Color(white: 0.45))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 40)
            }
        }
        .background(Color.appBg.ignoresSafeArea())
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordSheet()
        }
    }

    private func submit() async {
        let trimmedEmail    = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            errorMessage = "That email address doesn't look valid."
            return
        }
        if isSignUp, trimmedPassword.count < 6 {
            errorMessage = "Password must be at least 6 characters."
            return
        }

        isBusy = true
        errorMessage = nil

        do {
            if isSignUp {
                let outcome = try await authService.signUp(email: trimmedEmail, password: trimmedPassword)
                switch outcome {
                case .signedIn:
                    showEmailConfirmBanner = false
                case .emailConfirmationRequired:
                    showEmailConfirmBanner = true
                    password = ""
                    isSignUp = false
                }
            } else {
                try await authService.signIn(email: trimmedEmail, password: trimmedPassword)
                showEmailConfirmBanner = false
            }
        } catch {
            errorMessage = friendlyError(error)
        }

        isBusy = false
    }

    private func friendlyError(_ error: Error) -> String {
        let raw = error.localizedDescription
        let msg = raw.lowercased()
        if msg.contains("invalid login credentials") || msg.contains("invalid_credentials") {
            return "Incorrect email or password."
        }
        if msg.contains("already registered") ||
            (msg.contains("user") && msg.contains("already")) ||
            (msg.contains("email") && msg.contains("already")) {
            return "An account with this email already exists. Try signing in."
        }
        if msg.contains("password") && (msg.contains("at least") || msg.contains("weak") || msg.contains("short")) {
            return "Password must be at least 6 characters."
        }
        if msg.contains("invalid") && msg.contains("email") {
            return "That email address doesn't look valid."
        }
        if msg.contains("confirm") {
            return "Please confirm your email address before signing in."
        }
        if msg.contains("network") || msg.contains("offline") || msg.contains("connect") || msg.contains("internet") {
            return "Network error. Check your connection and try again."
        }
        if msg.contains("rate") || msg.contains("too many") {
            return "Too many attempts. Please wait a moment and try again."
        }
        // Surface the underlying message so the user has something actionable.
        return raw
    }
}

// MARK: - Forgot Password Sheet

struct ForgotPasswordSheet: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var isBusy = false
    @State private var sent = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "envelope.open")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                            .padding(.top, 32)

                        Text("Reset Password")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.textPrimary)

                        Text("Enter your email and we'll send you a reset link.")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    if sent {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.green)
                            Text("Email sent!")
                                .font(.headline)
                                .foregroundStyle(Color.textPrimary)
                            Text("Check your inbox for a password reset link.")
                                .font(.subheadline)
                                .foregroundStyle(Color.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        VStack(spacing: 12) {
                            TextField("Email address", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .textFieldStyle(.roundedBorder)

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.subheadline)
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            PrimaryButton(title: "Send Reset Link", isLoading: isBusy) {
                                Task { await sendReset() }
                            }
                        }
                        .minimalCard()
                    }
                }
                .padding(.horizontal, 20)
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

    private func sendReset() async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter your email address."
            return
        }

        isBusy = true
        errorMessage = nil

        do {
            try await authService.sendPasswordReset(email: trimmed)
            sent = true
        } catch {
            errorMessage = "Could not send reset email. Please check the address and try again."
        }

        isBusy = false
    }
}
