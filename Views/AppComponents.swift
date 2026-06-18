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

// MARK: - Sheet Components (shared across SaveRide, AddBike, AddMaintenance, EditMaintenance, …)

/// Top header bar used inside themed sheets. Provides Cancel / title / optional Save trio with
/// 44pt hit areas, a divider, and the app surface background.
struct AppSheetHeader: View {
    let title: String
    let onCancel: () -> Void
    var saveLabel: String = "Save"
    var isSaveDisabled: Bool = false
    var onSave: (() -> Void)? = nil

    var body: some View {
        HStack {
            Button { onCancel() } label: {
                Text("Cancel")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            Spacer()

            if let onSave {
                Button { onSave() } label: {
                    Text(saveLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSaveDisabled ? Color.textGhost : Color.appAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isSaveDisabled)
            } else {
                // Balance the cancel button so the title stays visually centered.
                Color.clear.frame(width: 72, height: 44)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background(Color.appBg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.appDivider).frame(height: 1)
        }
    }
}

/// Uppercase ghost-colored field caption + content. Pair with `.appFieldChrome()` on the inner control.
struct AppFieldGroup<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.8)
                .foregroundStyle(Color.textGhost)
            content
        }
    }
}

/// The pill chrome applied to text fields, menus, and date pickers inside themed sheets.
/// Uses `appSurface2` so the field stands clearly above `appBg`.
struct AppFieldChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appSurface2)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.appDivider.opacity(0.6), lineWidth: 1)
            )
    }
}

extension View {
    func appFieldChrome() -> some View {
        modifier(AppFieldChrome())
    }
}

/// A ghosty placeholder used for text-field prompts so they match the textGhost token.
extension Text {
    static func appPrompt(_ text: String) -> Text {
        Text(text).foregroundColor(Color.textGhost)
    }
}
