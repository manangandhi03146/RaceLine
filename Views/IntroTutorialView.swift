import CoreLocation
import CoreMotion
import SwiftUI
import UserNotifications

/// First-launch walkthrough. Explains what RaceLine does and primes the
/// user for the system permission prompts that follow. Tracks completion
/// in `UserDefaults` under `hasSeenIntroTutorial` so it only appears once,
/// but the Settings screen has a row to re-show it on demand.
struct IntroTutorialView: View {
    /// Called when the user finishes the tutorial (taps Get Started on the
    /// last page). The caller is responsible for setting the
    /// `hasSeenIntroTutorial` flag and moving to the next screen.
    let onFinish: () -> Void

    @State private var currentPage = 0

    private static let pages: [IntroPage] = [
        IntroPage(
            icon: "motorcycle",
            title: "Welcome to RaceLine",
            body: "Turn your phone into a motorcycle telemetry rig. Record street rides and track days, then analyze speed, lean angle, GPS, and more.",
            actionLabel: nil
        ),
        IntroPage(
            icon: "speedometer",
            title: "Track every ride",
            body: "Tap Start Ride and RaceLine records your route, speed, elevation, lean angles, hard braking events, and aggressive acceleration in real time.",
            actionLabel: nil
        ),
        IntroPage(
            icon: "wrench.and.screwdriver.fill",
            title: "Manage your bikes",
            body: "Add the bikes in your garage, tag each ride to the one you took out, and log maintenance with mileage-based reminders.",
            actionLabel: nil
        ),
        IntroPage(
            icon: "location.fill",
            title: "Location access",
            body: "RaceLine needs your location while you ride to capture route, speed, and elevation. Location is only collected while a ride is actively recording — never in the background.",
            actionLabel: "Allow Location"
        ),
        IntroPage(
            icon: "gyroscope",
            title: "Motion access",
            body: "Lean angle, acceleration, and braking detection use your phone's motion sensors. No tracking happens outside of an active ride.",
            actionLabel: "Allow Motion"
        ),
        IntroPage(
            icon: "bell.badge.fill",
            title: "Maintenance reminders",
            body: "Allow notifications so RaceLine can remind you when an oil change, tire swap, or service is due. Optional — you can change this anytime.",
            actionLabel: "Allow Notifications"
        ),
        IntroPage(
            icon: "checkmark.seal.fill",
            title: "You're all set",
            body: "Sign in with Apple or Google to back up your rides and sync them across devices. Let's ride.",
            actionLabel: nil
        ),
    ]

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip
                HStack {
                    Spacer()
                    if currentPage < Self.pages.count - 1 {
                        Button("Skip") { finish() }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    } else {
                        Color.clear.frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 12)

                // Paged content
                TabView(selection: $currentPage) {
                    ForEach(Array(Self.pages.enumerated()), id: \.offset) { index, page in
                        IntroPageView(page: page) {
                            handleAction(for: page)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .indexViewStyle(.page(backgroundDisplayMode: .never))

                // Custom dots — TabView's built-in dots look anemic on dark.
                HStack(spacing: 8) {
                    ForEach(0..<Self.pages.count, id: \.self) { i in
                        Circle()
                            .fill(i == currentPage ? Color.appAccent : Color.textGhost)
                            .frame(width: i == currentPage ? 10 : 7,
                                   height: i == currentPage ? 10 : 7)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 16)

                // Primary action
                PrimaryButton(title: currentPage == Self.pages.count - 1 ? "Get Started" : "Continue") {
                    advance()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    private func advance() {
        if currentPage >= Self.pages.count - 1 {
            finish()
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentPage += 1
            }
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "hasSeenIntroTutorial")
        onFinish()
    }

    private func handleAction(for page: IntroPage) {
        switch page.actionLabel {
        case "Allow Location":
            requestLocation()
        case "Allow Motion":
            requestMotion()
        case "Allow Notifications":
            Task { await requestNotifications() }
        default:
            break
        }
    }

    // MARK: - Permission requests

    private func requestLocation() {
        let manager = CLLocationManager()
        manager.requestWhenInUseAuthorization()
    }

    private func requestMotion() {
        // iOS only shows the motion prompt the first time CoreMotion is actually
        // queried. CMMotionActivityManager triggers the system prompt cleanly.
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        let manager = CMMotionActivityManager()
        manager.queryActivityStarting(from: Date(), to: Date(), to: .main) { _, _ in }
    }

    private func requestNotifications() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }
}

// MARK: - Page model + view

private struct IntroPage {
    let icon: String
    let title: String
    let body: String
    /// Optional inline call-to-action that triggers a system permission prompt.
    let actionLabel: String?
}

private struct IntroPageView: View {
    let page: IntroPage
    let onActionTapped: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 140, height: 140)
                Image(systemName: page.icon)
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
            }

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text(page.body)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
            }

            if let actionLabel = page.actionLabel {
                Button(action: onActionTapped) {
                    Text(actionLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .frame(minHeight: 44)
                        .background(Color.appAccent.opacity(0.12))
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
    }
}
