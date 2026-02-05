import SwiftUI
import PhotosUI

struct ShareCardScreen: View {
    @EnvironmentObject var rideStore: RideStore
    
    // Current (unsaved) ride passed from ContentView
    let currentSummary: RideSummary?
    let currentRoute: [RidePoint]
    let currentLogURL: URL?

    @State private var pickedItem: PhotosPickerItem?
    @State private var backgroundUIImage: UIImage?
    @State private var exportedURL: URL?
    @State private var title: String = "Ride"
    @State private var saveName: String = ""
    @State private var mode: ShareBackgroundMode = .fill
    @State private var tightPadding: Bool = true

    // Dropdown selection key
    // "current" or saved UUID string
    @State private var selectedKey: String = "current"

    private var hasCurrentRide: Bool {
        currentSummary != nil && currentRoute.count >= 2
    }

    private var rideOptions: [(key: String, label: String)] {
        var out: [(String, String)] = []
        out.append(("current", hasCurrentRide ? "Current Ride (unsaved)" : "Current Ride (none)"))

        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short

        for r in rideStore.rides {
            let label = "\(r.name) • \(String(format: "%.2f mi", r.summary.distanceMi))"
            out.append((r.id.uuidString, label))
        }
        return out
    }

    private var selectedSummaryAndRoute: (RideSummary, [RidePoint])? {
        if selectedKey == "current" {
            guard let s = currentSummary, currentRoute.count >= 2 else { return nil }
            return (s, currentRoute)
        } else {
            guard let id = UUID(uuidString: selectedKey),
                  let ride = rideStore.rides.first(where: { $0.id == id }) else { return nil }
            return (ride.summary, ride.route)
        }
    }
    
    private var selectedLabel: String {
        rideOptions.first(where: { $0.key == selectedKey })?.label ?? "Select ride"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {

                // Dropdown to choose ride
                HStack(spacing: 12) {
                    Text("Ride")
                        .font(.headline)
                        .fixedSize(horizontal: true, vertical: false)   // prevents shrinking
                        .frame(width: 50, alignment: .leading)          // keeps it stable

                    Menu {
                        ForEach(rideOptions, id: \.key) { opt in
                            Button {
                                selectedKey = opt.key
                            } label: {
                                Text(opt.label)
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(selectedLabel)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: "chevron.down")
                                .font(.system(size: 14, weight: .semibold))
                                .opacity(0.9)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: .leading) // makes it fill available space
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading) // prevents the whole “box” resizing
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Save current ride to storage (so it appears later)
                if selectedKey == "current" {
                    Button {
                        guard let s = currentSummary,
                              let logURL = currentLogURL else { return }
                        let defaultName = "Ride \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))"
                        let chosen = saveName.trimmingCharacters(in: .whitespacesAndNewlines)
                        _ = rideStore.saveRide(
                            name: chosen.isEmpty ? defaultName : chosen,
                            summary: s,
                            route: currentRoute,
                            logTempURL: logURL
                        )
                        rideStore.load() // refresh list
                        if let latest = rideStore.latest {
                            selectedKey = latest.id.uuidString
                            saveName = ""
                        }
                    } label: {
                        Text("Save Ride to Library")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(currentSummary == nil || currentLogURL == nil || currentRoute.count < 2)
                }

                // Mode + padding toggles (your existing controls)
                HStack {
                    Picker("Mode", selection: $mode) {
                        ForEach(ShareBackgroundMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Tight", isOn: $tightPadding)
                        .labelsHidden()
                }

                TextField("Title (optional)", text: $title)
                    .textFieldStyle(.roundedBorder)

                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label(backgroundUIImage == nil ? "Choose Photo" : "Change Photo", systemImage: "photo")
                }
                .onChange(of: pickedItem) { _, newItem in
                    Task { await loadImage(from: newItem) }
                }

                // Show the exact stats that will be on the image
                if let (s, _) = selectedSummaryAndRoute {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Stats on share image").font(.headline)
                        Text("Distance: \(String(format: "%.2f mi", s.distanceMi))")
                        Text("Time: \(s.durationText)")
                        Text("Max Speed: \(String(format: "%.1f mph", s.maxSpeedMph))")
                        Text("Max Lean: \(String(format: "%.0f°", s.maxAbsLeanDeg))")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Text("No ride data yet. Record a ride, then come back here.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Preview + export
                if let bg = backgroundUIImage, let (s, route) = selectedSummaryAndRoute {
                    ShareCardView(
                        background: bg,
                        summary: s,
                        title: title.isEmpty ? "Ride" : title,
                        route: route,
                        mode: mode,
                        tightPadding: tightPadding
                    )
                    .frame(width: 340, height: 605)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(radius: 12)
                    .padding(.top, 6)

                    HStack {
                        Button("Export PNG") {
                            exportedURL = exportPNG(
                                background: bg,
                                summary: s,
                                title: title.isEmpty ? "Ride" : title,
                                route: route,
                                mode: mode,
                                tightPadding: tightPadding
                            )
                        }
                        .buttonStyle(.borderedProminent)

                        if let url = exportedURL {
                            ShareLink(item: url) { Text("Share") }
                                .buttonStyle(.bordered)
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .padding()
        }
        .navigationTitle("Share")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            rideStore.load()

            // Default selection: current if available, else latest saved
            if !hasCurrentRide, let latest = rideStore.latest {
                selectedKey = latest.id.uuidString
            } else {
                selectedKey = "current"
            }
        }
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        exportedURL = nil

        if let data = try? await item.loadTransferable(type: Data.self),
           let ui = UIImage(data: data) {
            backgroundUIImage = ui

            // Auto-detect tall screenshots and default to FIT
            let ratio = ui.size.height / max(ui.size.width, 1)
            if ratio > 1.9 {
                mode = .fit
                tightPadding = true
            } else {
                mode = .fill
            }
        }
    }

    private func exportPNG(background: UIImage,
                           summary: RideSummary,
                           title: String,
                           route: [RidePoint],
                           mode: ShareBackgroundMode,
                           tightPadding: Bool) -> URL? {

        let size = CGSize(width: 1080, height: 1920)

        let view = ShareCardView(
            background: background,
            summary: summary,
            title: title,
            route: route,
            mode: mode,
            tightPadding: tightPadding
        )
        .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1

        guard let image = renderer.uiImage,
              let data = image.pngData() else { return nil }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("share-\(Int(Date().timeIntervalSince1970)).png")

        do {
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            print("Export failed:", error)
            return nil
        }
    }
}

