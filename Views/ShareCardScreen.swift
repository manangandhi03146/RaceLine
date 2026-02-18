import SwiftUI
import PhotosUI
import UIKit

struct ShareCardScreen: View {
    @EnvironmentObject var rideStore: RideStore
    
    // Current (unsaved) ride passed from ContentView
    let currentSummary: RideSummary?
    let currentRoute: [RidePoint]
    let currentLogURL: URL?
    @Binding var initiallySelectedRideID: UUID?

    @State private var pickedItem: PhotosPickerItem?
    @State private var backgroundUIImage: UIImage?
    @State private var exportedURL: URL?
    @State private var title: String = "Ride"
    @State private var mode: ShareBackgroundMode = .fill
    @State private var textColor: Color = .white
    @State private var showDuplicateAlert = false
    @State private var showNameSheet = false
    @State private var reopenNameSheetAfterDuplicate = false
    @State private var pendingName: String = ""
    @State private var pendingRidePhoto: UIImage?

    // Dropdown selection key
    // "current" or saved UUID string
    @State private var selectedKey: String = "current"

    private var hasCurrentRide: Bool {
        currentSummary != nil && currentRoute.count >= 2
    }

    private var isCurrentRideSaved: Bool {
        guard let s = currentSummary, currentRoute.count >= 2 else { return false }
        return rideStore.rides.contains { $0.summary == s && $0.route == currentRoute }
    }

    private var rideOptions: [(key: String, label: String)] {
        var out: [(String, String)] = []
        let currentLabel: String
        if hasCurrentRide {
            currentLabel = isCurrentRideSaved ? "Current Ride (saved)" : "Current Ride (unsaved)"
        } else {
            currentLabel = "Current Ride (none)"
        }
        out.append(("current", currentLabel))

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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Save current ride to storage (so it appears later)
                if selectedKey == "current", !isCurrentRideSaved {
                    Button {
                        pendingName = defaultRideName()
                        pendingRidePhoto = nil
                        showNameSheet = true
                    } label: {
                        Text("Save Ride to Library")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(currentSummary == nil || currentLogURL == nil || currentRoute.count < 2)
                }

                // Mode controls
                HStack {
                    Picker("Mode", selection: $mode) {
                        ForEach(ShareBackgroundMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                HStack(spacing: 8) {
                    TextField("Title (optional)", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)

                    ColorPicker("Text", selection: $textColor, supportsOpacity: true)
                        .labelsHidden()
                        .frame(width: 44, height: 44, alignment: .trailing)
                }

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
                        tightPadding: true,
                        textColor: textColor,
                        routeColor: textColor
                    )
                    .frame(width: 340, height: 605)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(radius: 12)
                    .padding(.top, 6)

                    if let url = exportedURL {
                        ShareLink(item: url) { Text("Share") }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 6)
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showNameSheet) {
            SaveRideSheet(
                name: $pendingName,
                selectedImage: $pendingRidePhoto,
                onSave: {
                    guard let s = currentSummary,
                          let logURL = currentLogURL,
                          currentRoute.count >= 2 else {
                        showNameSheet = false
                        return
                    }

                    let trimmed = pendingName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let finalName = trimmed.isEmpty ? defaultRideName() : trimmed

                    if rideStore.hasRide(named: finalName) {
                        reopenNameSheetAfterDuplicate = true
                        showDuplicateAlert = true
                        return
                    }

                    let savedRide = rideStore.saveRide(
                        name: finalName,
                        summary: s,
                        route: currentRoute,
                        logTempURL: logURL,
                        ridePhoto: pendingRidePhoto
                    )
                    guard savedRide != nil else {
                        reopenNameSheetAfterDuplicate = true
                        showDuplicateAlert = true
                        return
                    }
                    rideStore.load()
                    if let latest = rideStore.latest {
                        selectedKey = latest.id.uuidString
                    }
                    pendingRidePhoto = nil
                    showNameSheet = false
                },
                onCancel: {
                    pendingRidePhoto = nil
                    showNameSheet = false
                }
            )
            .presentationDetents([.height(420)])
        }
        .alert("Ride name already exists", isPresented: $showDuplicateAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please choose a different name.")
        }
        .onChange(of: showDuplicateAlert) { _, isShowing in
            guard !isShowing, reopenNameSheetAfterDuplicate else { return }
            reopenNameSheetAfterDuplicate = false
            showNameSheet = true
        }
        .navigationTitle("Share")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: initiallySelectedRideID) { _, newValue in
            if newValue != nil {
                applyInitialSelectionFromNavigation()
            }
        }
        .onChange(of: selectedKey) { _, _ in
            applyAssociatedRidePhotoIfAvailable()
            refreshExportedURLIfNeeded()
        }
        .onChange(of: title) { _, _ in refreshExportedURLIfNeeded() }
        .onChange(of: mode) { _, _ in refreshExportedURLIfNeeded() }
        .onChange(of: textColor) { _, _ in refreshExportedURLIfNeeded() }
        .onChange(of: backgroundUIImage) { _, _ in refreshExportedURLIfNeeded() }
        .onAppear {
            rideStore.load()
            if initiallySelectedRideID != nil {
                applyInitialSelectionFromNavigation()
            } else {
                setDefaultSelection()
            }

            applyAssociatedRidePhotoIfAvailable()
            refreshExportedURLIfNeeded()
        }
    }

    private func applyInitialSelectionFromNavigation() {
        guard let rideID = initiallySelectedRideID else { return }
        if rideStore.rides.contains(where: { $0.id == rideID }) {
            selectedKey = rideID.uuidString
        } else {
            setDefaultSelection()
        }
        initiallySelectedRideID = nil
    }

    private func setDefaultSelection() {
        // Default selection: current if available, else latest saved
        if !hasCurrentRide, let latest = rideStore.latest {
            selectedKey = latest.id.uuidString
        } else {
            selectedKey = "current"
        }
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        exportedURL = nil

        if let data = try? await item.loadTransferable(type: Data.self),
           let ui = UIImage(data: data) {
            backgroundUIImage = normalizedImage(ui)
            applyDefaultMode(for: ui)
        }
    }

    private func defaultRideName() -> String {
        let now = Date()
        return "Ride \(DateFormatter.localizedString(from: now, dateStyle: .medium, timeStyle: .short))"
    }

    private func exportPNG(background: UIImage,
                           summary: RideSummary,
                           title: String,
                           route: [RidePoint],
                           mode: ShareBackgroundMode,
                           textColor: Color) -> URL? {

        let size = CGSize(width: 1080, height: 1920)

        let view = ShareCardView(
            background: background,
            summary: summary,
            title: title,
            route: route,
            mode: mode,
            tightPadding: true,
            textColor: textColor,
            routeColor: textColor
        )
        .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale

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

    private func refreshExportedURLIfNeeded() {
        guard let bg = backgroundUIImage,
              let (s, route) = selectedSummaryAndRoute else {
            exportedURL = nil
            return
        }

        exportedURL = exportPNG(
            background: bg,
            summary: s,
            title: title.isEmpty ? "Ride" : title,
            route: route,
            mode: mode,
            textColor: textColor
        )
    }

    private func applyAssociatedRidePhotoIfAvailable() {
        guard selectedKey != "current",
              let id = UUID(uuidString: selectedKey),
              let ride = rideStore.rides.first(where: { $0.id == id }) else {
            return
        }

        guard let url = rideStore.photoURL(for: ride),
              let data = try? Data(contentsOf: url),
              let ui = UIImage(data: data) else {
            backgroundUIImage = nil
            return
        }

        backgroundUIImage = normalizedImage(ui)
        applyDefaultMode(for: ui)
    }

    private func applyDefaultMode(for image: UIImage) {
        let ratio = image.size.height / max(image.size.width, 1)
        mode = (ratio > 1.9) ? .fit : .fill
    }

    private func normalizedImage(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? image
    }
}
