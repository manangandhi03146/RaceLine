import SwiftUI

/// Post-sign-in setup. Two questions: display name + units.
struct OnboardingView: View {
    @EnvironmentObject private var authService: AuthService

    let profile: UserProfile

    @State private var displayName: String
    @State private var preferredUnits: String
    @State private var isSaving = false

    init(profile: UserProfile) {
        self.profile = profile
        _displayName = State(initialValue: profile.displayName ?? "")
        _preferredUnits = State(initialValue: profile.preferredUnits.isEmpty ? "imperial" : profile.preferredUnits)
    }

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Hero
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                    Text("Welcome to RaceLine")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)
                    Text("Two quick things, then you're riding.")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.top, 56)
                .padding(.bottom, 32)

                // Form
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        AppFieldGroup(label: "DISPLAY NAME") {
                            TextField("",
                                      text: $displayName,
                                      prompt: .appPrompt("What should we call you?"))
                                .foregroundStyle(Color.textPrimary)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .appFieldChrome()
                        }

                        AppFieldGroup(label: "UNITS") {
                            Picker("", selection: $preferredUnits) {
                                Text("Imperial (mph, mi)").tag("imperial")
                                Text("Metric (km/h, km)").tag("metric")
                            }
                            .pickerStyle(.segmented)
                        }

                        Text("You can change these later in Settings.")
                            .font(.caption)
                            .foregroundStyle(Color.textTertiary)
                            .padding(.top, 2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }

                Spacer(minLength: 0)

                PrimaryButton(
                    title: "Continue",
                    isLoading: isSaving
                ) {
                    Task { await finish() }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(displayName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.55 : 1)
            }
        }
    }

    private func finish() async {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        await authService.completeOnboarding(displayName: trimmed, preferredUnits: preferredUnits)
        isSaving = false
    }
}
