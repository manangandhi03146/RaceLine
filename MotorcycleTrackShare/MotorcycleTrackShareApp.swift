import SwiftUI

@main
struct MotorcycleTrackShareApp: App {
    @StateObject private var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .task {
                    await authService.initialize()
                }
        }
    }
}
