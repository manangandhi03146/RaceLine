import SwiftUI

/// Placeholder for the future Social feed. Occupies the tab slot that
/// previously held the standalone Maintenance tab (maintenance now lives on
/// each bike's detail screen).
///
/// This screen ships in "coming soon" mode: the interaction affordances are
/// spelled out, but no backend is wired up yet. Future work will replace the
/// scaffold body with the real feed.
struct SocialFeedView: View {
    @State private var selectedFilter: FeedFilter = .following

    private enum FeedFilter: String, CaseIterable, Identifiable {
        case following, nearby, world
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .following: return "Following"
            case .nearby:    return "Nearby"
            case .world:     return "World"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    filterBar
                        .padding(.horizontal, 12)

                    heroCard
                        .padding(.horizontal, 12)

                    upcomingCard
                        .padding(.horizontal, 12)

                    Spacer(minLength: 100)
                }
                .padding(.top, 12)
            }
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .background(Color.appBg)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Text("Social")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Image(systemName: "bell")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.textGhost)
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .background(Color.appBg)
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(FeedFilter.allCases) { filter in
                let isSelected = filter == selectedFilter
                Button {
                    selectedFilter = filter
                } label: {
                    Text(filter.displayName)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .white : Color.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .frame(minHeight: 36)
                        .background(isSelected ? Color.appAccent : Color.appSurface2)
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                Text("COMING SOON")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1.2)
            }
            .foregroundStyle(Color.appAccent)

            Text("Your riding community, in one feed")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Follow other riders, drop into their share cards, react to a canyon run, and post your own — all without leaving RaceLine.")
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                featureRow(icon: "person.2.fill",
                           title: "Follow riders you know",
                           detail: "See their rides + share cards in your feed.")
                featureRow(icon: "location.circle.fill",
                           title: "Nearby rides",
                           detail: "Discover routes and rides near you, opt-in only.")
                featureRow(icon: "heart.fill",
                           title: "React and comment",
                           detail: "Cheer a good ride, drop a note — no doomscrolling.")
            }
            .padding(.top, 4)
        }
        .minimalCard()
    }

    private var upcomingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What's under construction")
                .font(.system(size: 13, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(Color.textGhost)

            Text("Right now this tab is a placeholder while the feed backend is being built. Existing app features — ride recording, garage, maintenance, sharing — keep working exactly as before.")
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .minimalCard()
    }

    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.appAccent)
                .frame(width: 24, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
