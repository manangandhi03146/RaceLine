import SwiftUI
import UserNotifications

@main
struct MotorcycleTrackShareApp: App {
    @StateObject private var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .task {
                    await authService.initialize()
                    await requestNotificationPermission()
                }
        }
    }

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }
}
