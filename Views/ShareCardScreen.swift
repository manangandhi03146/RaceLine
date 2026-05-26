import SwiftUI
import PhotosUI
import UIKit

struct ShareCardScreen: View {
    private enum ShareMetricField {
        case duration
        case maxSpeed
        case averageSpeed
        case maxLean
        case distance
    }

    @EnvironmentObject var rideStore: RideStore
    @EnvironmentObject var garageStore: GarageStore
    
    // Current (unsaved) ride passed from ContentView
    let currentSummary: RideSummary?
    let currentRoute: [RidePoint]
    let currentLogURL: URL?
    @Binding var initiallySelectedRideID: UUID?

    @State private var pickedItem: PhotosPickerItem?
    @State private var backgroundUIImage: UIImage?
    @State private var exportedURL: URL?
    @State private var exportTask: Task<Void, Never>?
    @State private var title: String = "Ride"
    @State private var mode: ShareBackgroundMode = .fill
    @State private var textColor: Color = .white
    @State private var showDuplicateAlert = false
    @State private var showNameSheet = false
    @State private var reopenNameSheetAfterDuplicate = false
    @State private var pendingName: String = ""
    @State private var pendingRidePhoto: UIImage?
    @State private var pendingRideBikeID: UUID?

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

    private var selectedSavedRide: SavedRide? {
        guard selectedKey != "current",
              let id = UUID(uuidString: selectedKey) else { return nil }
        return rideStore.rides.first(where: { $0.id == id })
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
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appSurface2)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                // Save current ride to storage (so it appears later)
                if selectedKey == "current", !isCurrentRideSaved {
                    Button {
                        pendingName = defaultRideName()
                        pendingRideBikeID = nil
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
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Ride Stats")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(white: 0.50))
                        shareStatRow("Distance", shareMetricText(summary: s, field: .distance))
                        shareStatRow("Time", shareMetricText(summary: s, field: .duration))
                        shareStatRow("Max Speed", shareMetricText(summary: s, field: .maxSpeed))
                        shareStatRow("Max Lean", shareMetricText(summary: s, field: .maxLean))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    Text("No ride data yet. Record a ride, then come back here.")
                        .font(.subheadline)
                        .foregroundStyle(Color(white: 0.45))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        .background(Color.appBg.ignoresSafeArea())
        .sheet(isPresented: $showNameSheet) {
            SaveRideSheet(
                name: $pendingName,
                selectedImage: $pendingRidePhoto,
                selectedBikeID: $pendingRideBikeID,
                bikes: garageStore.bikes,
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
                        rideBikeID: pendingRideBikeID,
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
                    pendingRideBikeID = nil
                    pendingRidePhoto = nil
                    showNameSheet = false
                },
                onCancel: {
                    pendingRideBikeID = nil
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
            Task { await applyAssociatedRidePhotoIfAvailable() }
        }
        .onChange(of: title) { _, _ in refreshExportedURLIfNeeded() }
        .onChange(of: mode) { _, _ in refreshExportedURLIfNeeded() }
        .onChange(of: textColor) { _, _ in refreshExportedURLIfNeeded() }
        .onChange(of: backgroundUIImage) { _, _ in refreshExportedURLIfNeeded() }
        .onAppear {
            if rideStore.rides.isEmpty { rideStore.load() }
            if initiallySelectedRideID != nil {
                applyInitialSelectionFromNavigation()
            } else {
                setDefaultSelection()
            }
            Task { await applyAssociatedRidePhotoIfAvailable() }
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
        exportTask?.cancel()
        guard let bg = backgroundUIImage,
              let (s, route) = selectedSummaryAndRoute else {
            exportedURL = nil
            return
        }
        let (t, m, c) = (title.isEmpty ? "Ride" : title, mode, textColor)
        exportTask = Task {
            let url = exportPNG(background: bg, summary: s, title: t, route: route, mode: m, textColor: c)
            if !Task.isCancelled { exportedURL = url }
        }
    }

    private func applyAssociatedRidePhotoIfAvailable() async {
        guard selectedKey != "current",
              let id = UUID(uuidString: selectedKey),
              let ride = rideStore.rides.first(where: { $0.id == id }),
              let url = rideStore.photoURL(for: ride) else {
            if selectedKey == "current" { /* keep existing background */ }
            return
        }

        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }.value

        guard let image else {
            backgroundUIImage = nil
            return
        }
        backgroundUIImage = normalizedImage(image)
        applyDefaultMode(for: image)
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

    private func shareStatRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color(white: 0.50))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
    }

    private func shareMetricText(summary: RideSummary, field: ShareMetricField) -> String {
        let availability = selectedSavedRide?.metricAvailability ?? .allAvailable
        switch field {
        case .duration:
            return availability.hasDuration ? summary.durationText : "N/A"
        case .maxSpeed:
            return availability.hasMaxSpeed ? String(format: "%.1f mph", summary.maxSpeedMph) : "N/A"
        case .averageSpeed:
            if availability.hasAverageSpeed, summary.durationSec > 0 {
                let avgMps = summary.distanceM / summary.durationSec
                return String(format: "%.1f mph", avgMps * 2.23693629)
            }
            return "N/A"
        case .maxLean:
            return availability.hasMaxLean ? String(format: "%.0f°", summary.maxAbsLeanDeg) : "N/A"
        case .distance:
            return availability.hasDistance ? String(format: "%.2f mi", summary.distanceMi) : "N/A"
        }
    }
}
