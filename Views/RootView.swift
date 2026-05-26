import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authService: AuthService
    @AppStorage("localOnlyMode") private var localOnlyMode: Bool = false

    var body: some View {
        Group {
            if authService.isLoading {
                LoadingView(message: "Starting up…")
            } else if authService.isLoggedIn || localOnlyMode {
                ContentView()
            } else {
                AuthView()
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.25), value: authService.isLoggedIn)
        .animation(.easeInOut(duration: 0.25), value: authService.isLoading)
    }
}
