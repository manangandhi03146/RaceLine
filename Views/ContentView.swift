//
//  ContentView.swift
//  MotorcycleTrackShare
//
//  Fully updated:
//  - Map background + live stats (no box)
//  - Start/Stop + Calibrate (left) + Share (right, always clickable)
//  - Auto-center once on first valid GPS fix (no “ocean start”)
//  - Motion updates always running so Calibrate updates lean even when not recording
//  - On Stop: reliably prompts to Save ride (waits until summary/fileURL are ready)
//  - Save prompt + name sheet
//

import SwiftUI
import MapKit
import UIKit

struct ContentView: View {
    private enum Tab: Hashable {
        case calendar
        case ride
        case share
    }

    @StateObject private var motion = MotionService()
    @StateObject private var location = LocationService()
    @StateObject private var recorder = RideRecorder()
    @StateObject private var rideStore = RideStore()
    @State private var selectedTab: Tab = .ride

    // Map camera
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.0, longitude: -74.0),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    @State private var didInitialCenter = false

    // Stop -> Save prompt (reliable)
    @State private var awaitingSavePrompt = false
    @State private var showSavePrompt = false
    @State private var showNameSheet = false
    @State private var pendingName: String = ""
    @State private var pendingRidePhoto: UIImage?
    @State private var showTooShortAlert = false
    @State private var showDuplicateAlert = false
    @State private var reopenNameSheetAfterDuplicate = false
    @State private var saveFinalizeRetryPending = false
    @State private var expandedRideID: UUID?
    @State private var pendingShareRideID: UUID?
    @State private var showRideDayPicker = false
    @State private var scrollTargetRideID: UUID?

    var body: some View {
        Group {
            if selectedTab == .ride {
                rideRecordingView
            } else if selectedTab == .share {
                NavigationStack {
                    ShareCardScreen(
                        currentSummary: recorder.summary,
                        currentRoute: recorder.route,
                        currentLogURL: recorder.fileURL,
                        initiallySelectedRideID: $pendingShareRideID
                    )
                    .environmentObject(rideStore)
                }
            } else {
                calendarView
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomNavigationBar
        }
        .fullScreenCover(isPresented: Binding(
            get: { expandedRideID != nil },
            set: { if !$0 { expandedRideID = nil } }
        )) {
            if let rideID = expandedRideID,
               let ride = rideStore.rides.first(where: { $0.id == rideID }) {
                RideDetailScreen(
                    ride: ride,
                    initialPhoto: ridePhotoImage(for: ride),
                    onClose: { expandedRideID = nil },
                    onRename: { newName in
                        rideStore.renameRide(id: rideID, newName: newName)
                    },
                    onShare: {
                        pendingShareRideID = rideID
                        expandedRideID = nil
                        selectedTab = .share
                    },
                    onSetPhoto: { image in
                        rideStore.setRidePhoto(id: rideID, image: image)
                    },
                    onDelete: {
                        rideStore.deleteRide(id: rideID)
                    }
                )
            } else {
                Color.black
                    .ignoresSafeArea()
                    .onAppear { expandedRideID = nil }
            }
        }
        .onAppear {
            rideStore.load()
            location.requestPermission()
            location.start()
            motion.start(hz: 50)
        }
    }

    private var calendarView: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    if rideStore.rides.isEmpty {
                        Text("No rides yet.")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 48)
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12)
                            ],
                            spacing: 12
                        ) {
                            ForEach(rideStore.rides) { ride in
                                Button {
                                    expandedRideID = ride.id
                                } label: {
                                    calendarRideCard(ride)
                                }
                                .buttonStyle(.plain)
                                .id(ride.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 120)
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    calendarHeader
                }
                .onChange(of: scrollTargetRideID) { _, targetID in
                    guard let targetID else { return }
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(targetID, anchor: .top)
                    }
                    scrollTargetRideID = nil
                }
            }
            .background(Color(.systemBackground))
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showRideDayPicker) {
                RideDayPickerSheet(rideDays: Set(firstRideIDByDay.keys)) { day in
                    if let targetID = firstRideIDByDay[day] {
                        scrollTargetRideID = targetID
                    }
                    showRideDayPicker = false
                }
            }
        }
    }

    private var calendarHeader: some View {
        HStack {
            Text("Calendar")
                .font(.system(size: 34, weight: .bold))
            Spacer()
            Button {
                showRideDayPicker = true
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color(.systemBackground).opacity(0.96))
    }

    private func calendarRideCard(_ ride: SavedRide) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ride.name)
                .font(.title3.weight(.semibold))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .topLeading)

            Text(calendarDateTime(ride.createdAt))
                .font(.body)
                .foregroundStyle(.secondary)

            Divider().opacity(0.35)

            calendarStatRow("Total Time", ride.summary.durationText)
            calendarStatRow("Max Speed", String(format: "%.1f mph", ride.summary.maxSpeedMph))
            calendarStatRow("Avg Speed", String(format: "%.1f mph", averageSpeedMph(for: ride.summary)))
            calendarStatRow("Max Lean", String(format: "%.0f°", ride.summary.maxAbsLeanDeg))
            calendarStatRow("Distance", String(format: "%.2f mi", ride.summary.distanceMi))

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(minHeight: 210)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func calendarStatRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }

    private var firstRideIDByDay: [Date: UUID] {
        var out: [Date: UUID] = [:]
        let calendar = Calendar.current
        for ride in rideStore.rides {
            let day = calendar.startOfDay(for: ride.createdAt)
            if out[day] == nil {
                out[day] = ride.id
            }
        }
        return out
    }

    private var rideRecordingView: some View {
        Map(position: $position, interactionModes: .all) {
            UserAnnotation()
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onChange(of: location.lat) { _, _ in centerOnUserIfNeeded() }
        .onChange(of: location.lon) { _, _ in centerOnUserIfNeeded() }
        .onChange(of: recorder.summary) { _, _ in maybePresentSavePrompt() }
        .onChange(of: recorder.fileURL) { _, _ in maybePresentSavePrompt() }
        .onChange(of: recorder.isRecording) { _, isRec in
            if !isRec { maybePresentSavePrompt() }
        }
        .alert("Ride too short to save", isPresented: $showTooShortAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Record a little longer so we can capture enough data.")
        }
        .alert("Ride name already exists", isPresented: $showDuplicateAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please choose a different name.")
        }
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Speed: \(formatSpeed(location.speedMps))")
                Text(String(format: "Lean: %.1f°", motion.leanDeg))
                Text("GPS: \(formatGPS(lat: location.lat, lon: location.lon))")
            }
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.75), radius: 3, x: 0, y: 1)
            .padding(.leading, 14)
            .padding(.top, 26)
        }
        .overlay(alignment: .bottomLeading) {
            Button {
                motion.calibrateUpright()
            } label: {
                Image(systemName: "scope")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(.black.opacity(0.55))
                    .clipShape(Circle())
            }
            .disabled(recorder.isRecording)
            .opacity(recorder.isRecording ? 0.45 : 1.0)
            .padding(.leading, 18)
            .padding(.bottom, 96)
        }
        .overlay(alignment: .bottom) {
            Button {
                if recorder.isRecording {
                    awaitingSavePrompt = true
                    recorder.stop()
                } else {
                    recorder.start(motion: motion, location: location, sampleHz: 10)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: recorder.isRecording ? "stop.fill" : "play.fill")
                        .font(.system(size: 20, weight: .bold))
                    Text(recorder.isRecording ? "Stop Ride" : "Start Ride")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(recorder.isRecording ? Color.red : Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
        .confirmationDialog("Save this ride?", isPresented: $showSavePrompt, titleVisibility: .visible) {
            Button("Save") { showNameSheet = true }
            Button("Don’t Save", role: .destructive) { }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showNameSheet) {
            SaveRideSheet(
                name: $pendingName,
                selectedImage: $pendingRidePhoto,
                onSave: {
                    guard let s = recorder.summary,
                          let log = recorder.fileURL else {
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
                        route: recorder.route,
                        logTempURL: log,
                        ridePhoto: pendingRidePhoto
                    )
                    guard savedRide != nil else {
                        reopenNameSheetAfterDuplicate = true
                        showDuplicateAlert = true
                        return
                    }

                    rideStore.load()
                    pendingRidePhoto = nil
                    showNameSheet = false
                },
                onCancel: {
                    pendingRidePhoto = nil
                    showNameSheet = false
                }
            )
            .presentationDetents([.height(350)])
        }
        .onChange(of: showDuplicateAlert) { _, isShowing in
            guard !isShowing, reopenNameSheetAfterDuplicate else { return }
            reopenNameSheetAfterDuplicate = false
            showNameSheet = true
        }
    }

    private var bottomNavigationBar: some View {
        HStack(spacing: 0) {
            navBarButton(title: "Calendar", systemImage: "calendar", tab: .calendar)
            navBarButton(title: "Ride", systemImage: "speedometer", tab: .ride)
            navBarButton(title: "Share", systemImage: "square.and.arrow.up", tab: .share)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
        .padding(.bottom, 2)
        .background(Color.black.ignoresSafeArea(edges: .bottom))
    }

    private func navBarButton(title: String, systemImage: String, tab: Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 21, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(selectedTab == tab ? Color.white : Color.white.opacity(0.65))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Reliable save prompt logic

    private func maybePresentSavePrompt() {
        guard awaitingSavePrompt else { return }

        // If summary/file are present, finalize using a duration threshold.
        if let summary = recorder.summary, recorder.fileURL != nil {
            awaitingSavePrompt = false
            saveFinalizeRetryPending = false
            if summary.durationSec < 5 {
                showTooShortAlert = true
                return
            }
            pendingName = defaultRideName()
            pendingRidePhoto = nil
            showSavePrompt = true
            return
        }

        // Stop() flips isRecording first, then publishes summary/file.
        // Give one short retry window before failing.
        if recorder.isRecording == false, !saveFinalizeRetryPending {
            saveFinalizeRetryPending = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                saveFinalizeRetryPending = false
                if awaitingSavePrompt {
                    maybePresentSavePrompt()
                }
            }
            return
        }

        if recorder.isRecording == false {
            awaitingSavePrompt = false
            saveFinalizeRetryPending = false
            showTooShortAlert = true
        }
    }

    // MARK: - Helpers

    private func centerOnUserIfNeeded() {
        guard !didInitialCenter,
              let lat = location.lat,
              let lon = location.lon else { return }

        position = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )
        didInitialCenter = true
    }

    private func defaultRideName() -> String {
        let now = Date()
        return "Ride \(DateFormatter.localizedString(from: now, dateStyle: .medium, timeStyle: .short))"
    }

    private func formatSpeed(_ mps: Double?) -> String {
        guard let mps else { return "—" }
        let mph = mps * 2.23693629
        return String(format: "%.1f mph", mph)
    }

    private func formatGPS(lat: Double?, lon: Double?) -> String {
        guard let lat, let lon else { return "—" }
        return String(format: "%.5f, %.5f", lat, lon)
    }

    private func averageSpeedMph(for summary: RideSummary) -> Double {
        guard summary.durationSec > 0 else { return 0 }
        let avgMps = summary.distanceM / summary.durationSec
        return avgMps * 2.23693629
    }

    private func calendarDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func ridePhotoImage(for ride: SavedRide) -> UIImage? {
        guard let url = rideStore.photoURL(for: ride),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }
}

private struct RideDetailScreen: View {
    private enum PhotoPickerSource: String, Identifiable {
        case camera
        case library

        var id: String { rawValue }

        var uiKitSourceType: UIImagePickerController.SourceType {
            switch self {
            case .camera:
                return .camera
            case .library:
                return .photoLibrary
            }
        }
    }

    let ride: SavedRide
    let initialPhoto: UIImage?
    let onClose: () -> Void
    let onRename: (String) -> RideStore.RenameRideResult
    let onShare: () -> Void
    let onSetPhoto: (UIImage) -> RideStore.SetRidePhotoResult
    let onDelete: () -> RideStore.DeleteRideResult

    @State private var draftName: String
    @State private var photoImage: UIImage?
    @State private var showDuplicateAlert = false
    @State private var showRenameFailedAlert = false
    @State private var showDeleteConfirm = false
    @State private var showDeleteFailedAlert = false
    @State private var showPhotoSourceDialog = false
    @State private var showPhotoSaveFailedAlert = false
    @State private var photoPickerSource: PhotoPickerSource?

    init(ride: SavedRide,
         initialPhoto: UIImage?,
         onClose: @escaping () -> Void,
         onRename: @escaping (String) -> RideStore.RenameRideResult,
         onShare: @escaping () -> Void,
         onSetPhoto: @escaping (UIImage) -> RideStore.SetRidePhotoResult,
         onDelete: @escaping () -> RideStore.DeleteRideResult) {
        self.ride = ride
        self.initialPhoto = initialPhoto
        self.onClose = onClose
        self.onRename = onRename
        self.onShare = onShare
        self.onSetPhoto = onSetPhoto
        self.onDelete = onDelete
        _draftName = State(initialValue: ride.name)
        _photoImage = State(initialValue: initialPhoto)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.94).ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                    Spacer()
                    Button {
                        onShare()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    TextField("Ride name", text: $draftName)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3.weight(.semibold))

                    Button("Save Name") {
                        switch onRename(draftName) {
                        case .success:
                            break
                        case .duplicateName:
                            showDuplicateAlert = true
                        case .notFound, .writeFailed:
                            showRenameFailedAlert = true
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        showPhotoSourceDialog = true
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.secondary.opacity(0.14))
                                .frame(height: 170)

                            if let photoImage {
                                Image(uiImage: photoImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 170)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            } else {
                                VStack(spacing: 6) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 26, weight: .semibold))
                                    Text("Add Ride Photo")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Tap to upload or take photo")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Divider().opacity(0.4)

                    Text(dateTimeText(ride.createdAt))
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    detailRow("Total Time", ride.summary.durationText)
                    detailRow("Max Speed", String(format: "%.1f mph", ride.summary.maxSpeedMph))
                    detailRow("Avg Speed", String(format: "%.1f mph", averageSpeedMph(for: ride.summary)))
                    detailRow("Max Lean", String(format: "%.0f°", ride.summary.maxAbsLeanDeg))
                    detailRow("Distance", String(format: "%.2f mi", ride.summary.distanceMi))

                    Spacer()

                    Button("Delete Ride") {
                        showDeleteConfirm = true
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(12)
        }
        .alert("Ride name already exists", isPresented: $showDuplicateAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please choose a different name.")
        }
        .alert("Could not save name", isPresented: $showRenameFailedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please try again.")
        }
        .confirmationDialog("Ride Photo", isPresented: $showPhotoSourceDialog, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") {
                    photoPickerSource = .camera
                }
            }
            Button("Choose Photo") {
                photoPickerSource = .library
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(item: $photoPickerSource) { source in
            UIKitImagePicker(sourceType: source.uiKitSourceType) { image in
                switch onSetPhoto(image) {
                case .success:
                    photoImage = image
                case .notFound, .writeFailed:
                    showPhotoSaveFailedAlert = true
                }
            }
            .ignoresSafeArea()
        }
        .alert("Delete this ride?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                switch onDelete() {
                case .success:
                    onClose()
                case .notFound, .deleteFailed:
                    showDeleteFailedAlert = true
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Could not delete ride", isPresented: $showDeleteFailedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please try again.")
        }
        .alert("Could not save photo", isPresented: $showPhotoSaveFailedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please try again.")
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.title3.weight(.semibold))
        }
    }

    private func averageSpeedMph(for summary: RideSummary) -> Double {
        guard summary.durationSec > 0 else { return 0 }
        let avgMps = summary.distanceM / summary.durationSec
        return avgMps * 2.23693629
    }

    private func dateTimeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct RideDayPickerSheet: View {
    let rideDays: Set<Date>
    let onSelectDay: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var monthAnchor: Date

    private let calendar = Calendar.current

    init(rideDays: Set<Date>, onSelectDay: @escaping (Date) -> Void) {
        let normalized = Set(rideDays.map { Calendar.current.startOfDay(for: $0) })
        self.rideDays = normalized
        self.onSelectDay = onSelectDay
        _monthAnchor = State(initialValue: normalized.max() ?? Date())
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button {
                    shiftMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                }

                Spacer()

                Text(monthTitle(monthAnchor))
                    .font(.headline)

                Spacer()

                Button {
                    shiftMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                }
            }

            HStack(spacing: 0) {
                ForEach(weekdaySymbols(), id: \.self) { day in
                    Text(day)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 8) {
                ForEach(Array(monthGridDays().enumerated()), id: \.offset) { _, maybeDate in
                    if let date = maybeDate {
                        let day = calendar.component(.day, from: date)
                        let dayKey = calendar.startOfDay(for: date)
                        let hasRide = rideDays.contains(dayKey)

                        Button {
                            guard hasRide else { return }
                            onSelectDay(dayKey)
                            dismiss()
                        } label: {
                            ZStack {
                                if hasRide {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 34, height: 34)
                                }

                                Text("\(day)")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(hasRide ? Color.white : Color.primary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                }
            }

            if rideDays.isEmpty {
                Text("No ride days yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding(16)
        .presentationDetents([.height(420)])
    }

    private func shiftMonth(by amount: Int) {
        if let next = calendar.date(byAdding: .month, value: amount, to: monthStart(monthAnchor)) {
            monthAnchor = next
        }
    }

    private func monthStart(_ date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private func monthGridDays() -> [Date?] {
        let monthStartDate = monthStart(monthAnchor)
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStartDate)?.count ?? 0
        let firstWeekday = calendar.component(.weekday, from: monthStartDate)
        let lead = (firstWeekday - calendar.firstWeekday + 7) % 7

        var values = Array(repeating: Optional<Date>.none, count: lead)
        for dayOffset in 0..<daysInMonth {
            if let day = calendar.date(byAdding: .day, value: dayOffset, to: monthStartDate) {
                values.append(day)
            }
        }
        return values
    }

    private func weekdaySymbols() -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let index = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[index...]) + Array(symbols[..<index])
    }

    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }
}
