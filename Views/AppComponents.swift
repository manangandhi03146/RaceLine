import SwiftUI

// MARK: - Color Tokens

extension Color {
    // Surfaces
    static let appBg       = Color(red: 0.094, green: 0.094, blue: 0.094)   // #181818
    static let appSurface  = Color(red: 0.141, green: 0.141, blue: 0.141)   // #242424
    static let appSurface2 = Color(red: 0.184, green: 0.184, blue: 0.184)   // #2F2F2F
    static let appAccent   = Color(red: 1.000, green: 0.427, blue: 0.000)   // #FF6D00
    static let appDivider  = Color(red: 0.220, green: 0.220, blue: 0.220)   // #383838

    // Text hierarchy
    static let textPrimary   = Color(red: 0.941, green: 0.941, blue: 0.933) // #F0F0EE
    static let textSecondary = Color(white: 0.549)                           // #8C8C8C
    static let textTertiary  = Color(white: 0.451)                           // #737373
    static let textGhost     = Color(white: 0.349)                           // #595959
}

// MARK: - Font Scale

extension Font {
    static let statDisplay:   Font = .system(size: 76, weight: .bold).monospacedDigit()
    static let statSecondary: Font = .system(size: 38, weight: .bold).monospacedDigit()
}

// MARK: - PrimaryButton

struct PrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(isDestructive ? Color.red : Color.appAccent)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(isLoading)
    }
}

// MARK: - SecondaryButton

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.appAccent)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Color.appAccent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

// MARK: - EmptyStateView

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color.appAccent)

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.textPrimary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - LoadingView

struct LoadingView: View {
    var message: String = "Loading…"

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color.appAccent)
                .scaleEffect(1.4)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBg.ignoresSafeArea())
    }
}

// MARK: - MinimalCard modifier

struct MinimalCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func minimalCard() -> some View {
        modifier(MinimalCard())
    }
}
