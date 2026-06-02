import SwiftUI
import MapKit
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    private enum Tab: Hashable {
        case calendar
        case ride
        case share
        case garage
        case profile
        case settings
    }

    @EnvironmentObject private var authService: AuthService
    @AppStorage("cloudSyncEnabled") private var cloudSyncEnabled = false

    @StateObject private var motion = MotionService()
    @StateObject private var location = LocationService()
    @StateObject private var recorder = RideRecorder()
    @StateObject private var rideStore = RideStore()
    @StateObject private var garageStore = GarageStore()
    @StateObject private var motorcycleCatalog = MotorcycleCatalogService()
    @State private var selectedTab: Tab = .ride

    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.0, longitude: -74.0),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    @State private var didInitialCenter = false

    @State private var awaitingSavePrompt = false
    @State private var showSavePrompt = false
    @State private var showNameSheet = false
    @State private var pendingName: String = ""
    @State private var pendingRidePhoto: UIImage?
    @State private var pendingRideBikeID: UUID?
    @State private var showTooShortAlert = false
    @State private var showDuplicateAlert = false
    @State private var reopenNameSheetAfterDuplicate = false
    @State private var saveFinalizeRetryPending = false
    @State private var expandedRideID: UUID?
    @State private var pendingShareRideID: UUID?
    @State private var showRideDayPicker = false
    @State private var scrollTargetRideID: UUID?
    @State private var showGPXImporter = false
    @State private var importedRideDraft: ImportedRideDraft?
    @State private var showImportRideSheet = false
    @State private var importErrorMessage: String?
    @State private var reopenImportRideSheetAfterDuplicate = false

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
                    .environmentObject(garageStore)
                }
            } else if selectedTab == .garage {
                GarageView(
                    garageStore: garageStore,
                    catalogService: motorcycleCatalog
                )
            } else if selectedTab == .profile {
                NavigationStack {
                    ProfileView()
                }
            } else if selectedTab == .settings {
                NavigationStack {
                    SettingsView()
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
                    bikes: garageStore.bikes,
                    onExportJSONL: ride.logFilename.hasSuffix(".jsonl") ? {
                        rideStore.jsonlExportURL(for: ride)
                    } : nil,
                    onClose: { expandedRideID = nil },
                    onRename: { newName in
                        rideStore.renameRide(id: rideID, newName: newName)
                    },
                    onSetBike: { bikeID in
                        rideStore.setRideBike(id: rideID, bikeID: bikeID)
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
                        let rideToDelete = rideStore.rides.first(where: { $0.id == rideID })
                        let result = rideStore.deleteRide(id: rideID)
                        if case .success = result,
                           let ride = rideToDelete,
                           let remoteID = ride.remoteID,
                           let userID = authService.userID {
                            Task {
                                try? await CloudRideStore().deleteRide(
                                    remoteID: remoteID,
                                    deletePhoto: ride.cloudPhotoPath != nil,
                                    userID: userID,
                                    rideID: ride.id
                                )
                            }
                        }
                        return result
                    }
                )
            } else {
                Color.appBg
                    .ignoresSafeArea()
                    .onAppear { expandedRideID = nil }
            }
        }
        .onChange(of: showDuplicateAlert) { _, isShowing in
            guard !isShowing else { return }
            if reopenNameSheetAfterDuplicate {
                reopenNameSheetAfterDuplicate = false
                showNameSheet = true
            }
            if reopenImportRideSheetAfterDuplicate {
                reopenImportRideSheetAfterDuplicate = false
                showImportRideSheet = true
            }
        }
        .onAppear {
            rideStore.load()
            garageStore.load()
            location.requestPermission()
            location.start()
            motion.start(hz: 50)
        }
    }

    // MARK: - Ride Recording View

    private var rideRecordingView: some View {
        ZStack {
            Map(position: $position, interactionModes: .all) {
                UserAnnotation()
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }

            // Bottom-up gradient: matches nav bar at bottom, fades above lean stats
            VStack(spacing: 0) {
                Spacer()
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: Color.appSurface.opacity(0.55), location: 0.35),
                        .init(color: Color.appSurface.opacity(0.92), location: 0.72),
                        .init(color: Color.appSurface, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 560)
            }
            .allowsHitTesting(false)

            // Stats + controls
            VStack(spacing: 0) {
                // Top strip: elapsed time + distance
                HStack(alignment: .top) {
                    rideTopStat("TIME", recordingTime)
                    Spacer()
                    rideTopStat("DIST", recordingDistance)
                }
                .padding(.horizontal, 22)
                .padding(.top, 10)
                .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 1)
                .opacity(recorder.isRecording || recorder.summary != nil ? 1 : 0)

                Spacer()

                // Speed — dominant stat
                VStack(spacing: 4) {
                    Text(speedDisplayText)
                        .font(.statDisplay)
                        .foregroundStyle(Color.appAccent)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.18), value: speedDisplayText)

                    Text("MPH")
                        .font(.system(size: 13, weight: .semibold))
                        .kerning(2.0)
                        .foregroundStyle(Color.textGhost)
                }

                // Lean angle — live + max
                VStack(spacing: 4) {
                    Text(liveLeanDisplayText)
                        .font(.statSecondary)
                        .foregroundStyle(Color.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.18), value: liveLeanDisplayText)

                    Text("LEAN")
                        .font(.system(size: 11, weight: .semibold))
                        .kerning(1.5)
                        .foregroundStyle(Color.textGhost)

                    if recorder.isRecording || recorder.summary != nil {
                        Text(maxLeanDisplayText)
                            .font(.system(size: 24, weight: .bold).monospacedDigit())
                            .foregroundStyle(Color.textSecondary)
                            .contentTransition(.numericText())
                            .animation(.easeOut(duration: 0.18), value: maxLeanDisplayText)
                            .padding(.top, 8)

                        Text("MAX LEAN")
                            .font(.system(size: 10, weight: .semibold))
                            .kerning(1.5)
                            .foregroundStyle(Color.textGhost)
                    }
                }
                .padding(.top, 18)

                Spacer()

                // Bottom controls
                VStack(spacing: 10) {
                    if !recorder.isRecording {
                        Button {
                            motion.calibrateUpright()
                        } label: {
                            Text("Calibrate Lean Sensor")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(Color.textSecondary)
                        }
                    }

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
                                .font(.system(size: 20, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(recorder.isRecording ? Color.red : Color.appAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 12)
            }
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
        .confirmationDialog("Save this ride?", isPresented: $showSavePrompt, titleVisibility: .visible) {
            Button("Save") { showNameSheet = true }
            Button("Don't Save", role: .destructive) { }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showNameSheet) {
            SaveRideSheet(
                name: $pendingName,
                selectedImage: $pendingRidePhoto,
                selectedBikeID: $pendingRideBikeID,
                bikes: garageStore.bikes,
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
                        rideBikeID: pendingRideBikeID,
                        ridePhoto: pendingRidePhoto
                    )
                    guard let savedRide else {
                        reopenNameSheetAfterDuplicate = true
                        showDuplicateAlert = true
                        return
                    }

                    if cloudSyncEnabled, let userID = authService.userID {
                        let photo = pendingRidePhoto
                        Task {
                            if let remoteID = try? await CloudRideStore().syncRide(savedRide, userID: userID, photo: photo) {
                                let path = photo != nil ? CloudRideStore().photoStoragePath(userID: userID, rideID: savedRide.id) : nil
                                _ = rideStore.updateCloudInfo(id: savedRide.id, remoteID: remoteID, cloudPhotoPath: path)
                            }
                        }
                    }

                    rideStore.load()
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
            .presentationDetents([.height(390)])
        }
    }

    // MARK: - Ride Recording Computed Properties

    private var speedDisplayText: String {
        guard let mps = location.speedMps, mps > 0.5 else { return "0" }
        return String(Int((mps * 2.23693629).rounded()))
    }

    private var liveLeanDisplayText: String {
        String(format: "%.0f°", abs(motion.leanDeg))
    }

    private var maxLeanDisplayText: String {
        if recorder.isRecording {
            return String(format: "%.0f°", recorder.liveMaxAbsLeanDeg)
        }
        return String(format: "%.0f°", recorder.summary?.maxAbsLeanDeg ?? 0)
    }

    private var recordingTime: String {
        recorder.summary?.durationText ?? (recorder.isRecording ? "0:00:00" : "—")
    }

    private var recordingDistance: String {
        guard let s = recorder.summary else { return recorder.isRecording ? "0.00 mi" : "—" }
        return String(format: "%.2f mi", s.distanceMi)
    }

    private func rideTopStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .kerning(1.0)
                .foregroundStyle(Color.textGhost)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .monospacedDigit()
        }
    }

    // MARK: - Calendar View

    private var calendarView: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    if rideStore.rides.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "speedometer")
                                .font(.system(size: 44, weight: .semibold))
                                .foregroundStyle(Color.appAccent)
                            Text("No rides yet")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Color.textPrimary)
                            Text("Tap Start Ride to begin tracking.")
                                .font(.subheadline)
                                .foregroundStyle(Color.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 80)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 12, pinnedViews: [.sectionHeaders]) {
                            ForEach(ridesByMonth) { group in
                                Section {
                                    ForEach(group.rides) { ride in
                                        Button {
                                            expandedRideID = ride.id
                                        } label: {
                                            calendarRideCard(ride)
                                        }
                                        .buttonStyle(.plain)
                                        .id(ride.id)
                                    }
                                } header: {
                                    Text(group.month.uppercased())
                                        .font(.system(size: 11, weight: .semibold))
                                        .kerning(0.8)
                                        .foregroundStyle(Color.textGhost)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 16)
                                        .padding(.bottom, 2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.appBg)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
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
            .background(Color.appBg)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showRideDayPicker) {
                RideDayPickerSheet(rideDays: Set(firstRideIDByDay.keys)) { day in
                    if let targetID = firstRideIDByDay[day] {
                        scrollTargetRideID = targetID
                    }
                    showRideDayPicker = false
                }
            }
            .sheet(isPresented: $showImportRideSheet) {
                if let draft = importedRideDraft {
                    ImportRideSheet(
                        draft: draft,
                        bikes: garageStore.bikes,
                        onImport: { updatedDraft in
                            switch rideStore.importRide(
                                name: updatedDraft.name,
                                createdAt: updatedDraft.createdAt,
                                summary: updatedDraft.summary,
                                route: updatedDraft.route,
                                sourceFileURL: updatedDraft.sourceFileURL,
                                rideBikeID: updatedDraft.bikeID,
                                metricAvailability: updatedDraft.metricAvailability
                            ) {
                            case .success(let ride):
                                importedRideDraft = nil
                                showImportRideSheet = false
                                scrollTargetRideID = ride.id
                            case .duplicateName:
                                importedRideDraft = updatedDraft
                                reopenImportRideSheetAfterDuplicate = true
                                showImportRideSheet = false
                                showDuplicateAlert = true
                            case .writeFailed:
                                importErrorMessage = "The GPX file could not be imported."
                            }
                        },
                        onCancel: {
                            importedRideDraft = nil
                            showImportRideSheet = false
                        }
                    )
                }
            }
            .fileImporter(
                isPresented: $showGPXImporter,
                allowedContentTypes: [UTType(filenameExtension: "gpx") ?? .xml],
                allowsMultipleSelection: false
            ) { result in
                handleGPXImportSelection(result)
            }
            .alert("Import Failed", isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { importErrorMessage = nil }
            } message: {
                Text(importErrorMessage ?? "The GPX file could not be imported.")
            }
        }
    }

    private var calendarHeader: some View {
        HStack {
            Text("Rides")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            HStack(spacing: 16) {
                Button {
                    showGPXImporter = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
                Button {
                    showRideDayPicker = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color.appBg)
    }

    private func calendarRideCard(_ ride: SavedRide) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Ember header band — structural, full-width
            HStack(spacing: 8) {
                Text(ride.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.appAccent)

            // Stats body
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Text(calendarDateShort(ride.createdAt))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.textTertiary)
                    if let name = bikeName(for: ride) {
                        Text("·")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textGhost)
                        Text(name)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color.appAccent.opacity(0.80))
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 0) {
                    rideCardStat("DIST", rideMetricText(ride, field: .distance))
                    Spacer()
                    rideCardStat("TIME", rideMetricText(ride, field: .duration))
                    Spacer()
                    rideCardStat("MAX LEAN", rideMetricText(ride, field: .maxLean))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(Color.appSurface)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func rideCardStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.5)
                .foregroundStyle(Color.textGhost)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
        }
    }

    private func calendarDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }

    private struct MonthGroup: Identifiable {
        var id: String { month }
        let month: String
        var rides: [SavedRide]
    }

    private var ridesByMonth: [MonthGroup] {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        let sorted = rideStore.rides.sorted { $0.createdAt > $1.createdAt }
        var groups: [String: [SavedRide]] = [:]
        var order: [String] = []
        for ride in sorted {
            let month = formatter.string(from: ride.createdAt)
            if groups[month] == nil {
                groups[month] = []
                order.append(month)
            }
            groups[month]!.append(ride)
        }
        return order.map { MonthGroup(month: $0, rides: groups[$0] ?? []) }
    }

    // MARK: - Bottom Navigation Bar

    private var bottomNavigationBar: some View {
        HStack(spacing: 0) {
            navBarButton(title: "Rides", systemImage: "calendar", tab: .calendar)
            navBarButton(title: "Ride", systemImage: "speedometer", tab: .ride)
            navBarButton(title: "Share", systemImage: "square.and.arrow.up", tab: .share)
            navBarButton(title: "Garage", systemImage: "car.fill", tab: .garage)
            navBarButton(title: "Profile", systemImage: "person.fill", tab: .profile)
            navBarButton(title: "Settings", systemImage: "gear", tab: .settings)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.bottom, 2)
        .background(Color.appSurface.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.appDivider)
                .frame(height: 1)
        }
    }

    private func navBarButton(title: String, systemImage: String, tab: Tab) -> some View {
        let isActive = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: isActive ? 20 : 18, weight: isActive ? .semibold : .regular))
                Text(title)
                    .font(.system(size: 9, weight: isActive ? .semibold : .regular))
            }
            .foregroundStyle(isActive ? Color.appAccent : Color.textGhost)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .animation(.easeOut(duration: 0.15), value: isActive)
    }

    // MARK: - Save Prompt Logic

    private func maybePresentSavePrompt() {
        guard awaitingSavePrompt else { return }

        if let summary = recorder.summary, recorder.fileURL != nil {
            awaitingSavePrompt = false
            saveFinalizeRetryPending = false
            if summary.durationSec < 5 {
                showTooShortAlert = true
                return
            }
            pendingName = defaultRideName()
            pendingRideBikeID = nil
            pendingRidePhoto = nil
            showSavePrompt = true
            return
        }

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

    private func averageSpeedMph(for summary: RideSummary) -> Double {
        guard summary.durationSec > 0 else { return 0 }
        let avgMps = summary.distanceM / summary.durationSec
        return avgMps * 2.23693629
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

    private func rideMetricText(_ ride: SavedRide, field: RideMetricField) -> String {
        let availability = ride.metricAvailability ?? .allAvailable
        switch field {
        case .duration:
            return availability.hasDuration ? ride.summary.durationText : "N/A"
        case .maxSpeed:
            return availability.hasMaxSpeed ? String(format: "%.1f mph", ride.summary.maxSpeedMph) : "N/A"
        case .averageSpeed:
            return availability.hasAverageSpeed ? String(format: "%.1f mph", averageSpeedMph(for: ride.summary)) : "N/A"
        case .maxLean:
            return availability.hasMaxLean ? String(format: "%.0f°", ride.summary.maxAbsLeanDeg) : "N/A"
        case .distance:
            return availability.hasDistance ? String(format: "%.2f mi", ride.summary.distanceMi) : "N/A"
        }
    }

    private func ridePhotoImage(for ride: SavedRide) -> UIImage? {
        guard let url = rideStore.photoURL(for: ride),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }

    private func bikeName(for ride: SavedRide) -> String? {
        guard let bikeID = ride.bikeID,
              let bike = garageStore.bikes.first(where: { $0.id == bikeID }) else {
            return nil
        }
        return bike.title
    }

    private func handleGPXImportSelection(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let parser = GPXRideParser()
            let parsed = try parser.parse(fileURL: url)
            importedRideDraft = ImportedRideDraft(
                name: url.deletingPathExtension().lastPathComponent,
                createdAt: parsed.defaultCreatedAt,
                bikeID: nil,
                summary: parsed.summary,
                route: parsed.route,
                sourceFileURL: url,
                metricAvailability: parsed.metricAvailability
            )
            showImportRideSheet = true
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }
}

// MARK: - Supporting Types

private enum RideMetricField {
    case duration
    case maxSpeed
    case averageSpeed
    case maxLean
    case distance
}

private struct ImportedRideDraft {
    let name: String
    let createdAt: Date
    let bikeID: UUID?
    let summary: RideSummary
    let route: [RidePoint]
    let sourceFileURL: URL
    let metricAvailability: RideMetricAvailability

    func updated(name: String, createdAt: Date, bikeID: UUID?) -> ImportedRideDraft {
        let adjustedStart = createdAt
        let adjustedEnd = metricAvailability.hasDuration
            ? createdAt.addingTimeInterval(summary.durationSec)
            : createdAt

        let adjustedSummary = RideSummary(
            startTime: adjustedStart,
            endTime: adjustedEnd,
            durationSec: metricAvailability.hasDuration ? summary.durationSec : 0,
            distanceM: metricAvailability.hasDistance ? summary.distanceM : 0,
            maxSpeedMps: metricAvailability.hasMaxSpeed ? summary.maxSpeedMps : 0,
            maxAbsLeanDeg: metricAvailability.hasMaxLean ? summary.maxAbsLeanDeg : 0
        )

        return ImportedRideDraft(
            name: name,
            createdAt: createdAt,
            bikeID: bikeID,
            summary: adjustedSummary,
            route: route,
            sourceFileURL: sourceFileURL,
            metricAvailability: metricAvailability
        )
    }
}

// MARK: - Import Ride Sheet

private struct ImportRideSheet: View {
    let draft: ImportedRideDraft
    let bikes: [GarageBike]
    let onImport: (ImportedRideDraft) -> Void
    let onCancel: () -> Void

    @State private var draftName: String
    @State private var draftDate: Date
    @State private var selectedBikeID: UUID?

    init(draft: ImportedRideDraft,
         bikes: [GarageBike],
         onImport: @escaping (ImportedRideDraft) -> Void,
         onCancel: @escaping () -> Void) {
        self.draft = draft
        self.bikes = bikes
        self.onImport = onImport
        self.onCancel = onCancel
        _draftName = State(initialValue: draft.name)
        _draftDate = State(initialValue: draft.createdAt)
        _selectedBikeID = State(initialValue: draft.bikeID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import GPX Ride")
                .font(.headline)

            TextField("Ride name", text: $draftName)
                .textFieldStyle(.roundedBorder)

            DatePicker("Ride Date", selection: $draftDate)
                .datePickerStyle(.compact)

            Menu {
                Button("No bike") { selectedBikeID = nil }
                ForEach(bikes) { bike in
                    Button(bike.title) { selectedBikeID = bike.id }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bike Used")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                        Text(selectedBikeLabel)
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.appSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                importStatRow("Total Time", text(for: .duration))
                importStatRow("Max Speed", text(for: .maxSpeed))
                importStatRow("Avg Speed", text(for: .averageSpeed))
                importStatRow("Max Lean", text(for: .maxLean))
                importStatRow("Distance", text(for: .distance))
            }
            .padding(10)
            .background(Color.appSurface2)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack {
                Button("Cancel") { onCancel() }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Import Ride") {
                    onImport(draft.updated(name: draftName, createdAt: draftDate, bikeID: selectedBikeID))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appAccent)
            }
        }
        .padding(14)
        .presentationDetents([.height(370)])
    }

    private var selectedBikeLabel: String {
        guard let selectedBikeID,
              let bike = bikes.first(where: { $0.id == selectedBikeID }) else {
            return "No bike"
        }
        return bike.title
    }

    private func importStatRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
        }
    }

    private func text(for field: RideMetricField) -> String {
        switch field {
        case .duration:
            return draft.metricAvailability.hasDuration ? draft.summary.durationText : "N/A"
        case .maxSpeed:
            return draft.metricAvailability.hasMaxSpeed ? String(format: "%.1f mph", draft.summary.maxSpeedMph) : "N/A"
        case .averageSpeed:
            if draft.metricAvailability.hasAverageSpeed, draft.summary.durationSec > 0 {
                let avgMps = draft.summary.distanceM / draft.summary.durationSec
                return String(format: "%.1f mph", avgMps * 2.23693629)
            }
            return "N/A"
        case .maxLean:
            return draft.metricAvailability.hasMaxLean ? String(format: "%.0f°", draft.summary.maxAbsLeanDeg) : "N/A"
        case .distance:
            return draft.metricAvailability.hasDistance ? String(format: "%.2f mi", draft.summary.distanceMi) : "N/A"
        }
    }
}

// MARK: - GPX Parsing

private struct ParsedGPXRide {
    let defaultCreatedAt: Date
    let summary: RideSummary
    let route: [RidePoint]
    let metricAvailability: RideMetricAvailability
}

private enum GPXRideParserError: LocalizedError {
    case unreadableFile
    case invalidGPX

    var errorDescription: String? {
        switch self {
        case .unreadableFile: return "The selected GPX file could not be read."
        case .invalidGPX: return "The selected GPX file does not contain usable track data."
        }
    }
}

private struct GPXRideParser {
    func parse(fileURL: URL) throws -> ParsedGPXRide {
        guard let parser = XMLParser(contentsOf: fileURL) else {
            throw GPXRideParserError.unreadableFile
        }

        let delegate = GPXParserDelegate()
        parser.delegate = delegate
        guard parser.parse() else {
            throw parser.parserError ?? GPXRideParserError.invalidGPX
        }

        let points = delegate.points
        let route = points.map { RidePoint(lat: $0.lat, lon: $0.lon) }
        guard !route.isEmpty else { throw GPXRideParserError.invalidGPX }

        let timedPoints = points.compactMap { point -> (Date, GPXTrackPoint)? in
            guard let time = point.time else { return nil }
            return (time, point)
        }
        let sortedTimedPoints = timedPoints.sorted { $0.0 < $1.0 }

        let startTime = sortedTimedPoints.first?.0 ?? Date()
        let endTime = sortedTimedPoints.last?.0 ?? startTime
        let hasDuration = sortedTimedPoints.count >= 2 && endTime >= startTime

        let distanceM = totalDistance(for: points)
        let hasDistance = points.count >= 2

        let maxSpeedMps = computedMaxSpeed(for: sortedTimedPoints)
        let hasMaxSpeed = maxSpeedMps != nil

        let hasAverageSpeed = hasDuration && hasDistance && endTime.timeIntervalSince(startTime) > 0

        let availability = RideMetricAvailability(
            hasDuration: hasDuration,
            hasMaxSpeed: hasMaxSpeed,
            hasAverageSpeed: hasAverageSpeed,
            hasMaxLean: false,
            hasDistance: hasDistance
        )

        let durationSec = hasDuration ? endTime.timeIntervalSince(startTime) : 0
        let summary = RideSummary(
            startTime: startTime,
            endTime: hasDuration ? endTime : startTime,
            durationSec: durationSec,
            distanceM: hasDistance ? distanceM : 0,
            maxSpeedMps: maxSpeedMps ?? 0,
            maxAbsLeanDeg: 0
        )

        return ParsedGPXRide(
            defaultCreatedAt: startTime,
            summary: summary,
            route: route,
            metricAvailability: availability
        )
    }

    private func totalDistance(for points: [GPXTrackPoint]) -> Double {
        zip(points, points.dropFirst()).reduce(0) { partial, pair in
            partial + haversineMeters(lat1: pair.0.lat, lon1: pair.0.lon, lat2: pair.1.lat, lon2: pair.1.lon)
        }
    }

    private func computedMaxSpeed(for timedPoints: [(Date, GPXTrackPoint)]) -> Double? {
        var maxSpeed: Double?
        for pair in zip(timedPoints, timedPoints.dropFirst()) {
            let delta = pair.1.0.timeIntervalSince(pair.0.0)
            guard delta > 0 else { continue }
            let distance = haversineMeters(lat1: pair.0.1.lat, lon1: pair.0.1.lon, lat2: pair.1.1.lat, lon2: pair.1.1.lon)
            let speed = distance / delta
            if speed.isFinite { maxSpeed = max(maxSpeed ?? speed, speed) }
        }
        return maxSpeed
    }

    private func haversineMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLon = (lon2 - lon1) * .pi / 180.0
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0)
            * sin(dLon / 2) * sin(dLon / 2)
        return 2.0 * r * atan2(sqrt(a), sqrt(1.0 - a))
    }
}

private struct GPXTrackPoint {
    let lat: Double
    let lon: Double
    let time: Date?
}

private final class GPXParserDelegate: NSObject, XMLParserDelegate {
    private(set) var points: [GPXTrackPoint] = []

    private var currentLat: Double?
    private var currentLon: Double?
    private var currentTime: Date?
    private var currentValue = ""
    private var insideTimeElement = false
    private lazy var isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentValue = ""
        if elementName == "trkpt" {
            currentLat = attributeDict["lat"].flatMap(Double.init)
            currentLon = attributeDict["lon"].flatMap(Double.init)
            currentTime = nil
        } else if elementName == "time" {
            insideTimeElement = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentValue += string
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        let trimmed = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if elementName == "time", insideTimeElement {
            currentTime = parseDate(trimmed)
            insideTimeElement = false
        } else if elementName == "trkpt" {
            if let currentLat, let currentLon {
                points.append(GPXTrackPoint(lat: currentLat, lon: currentLon, time: currentTime))
            }
            currentLat = nil
            currentLon = nil
            currentTime = nil
        }
        currentValue = ""
    }

    private func parseDate(_ text: String) -> Date? {
        if let date = isoFormatter.date(from: text) { return date }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: text)
    }
}

// MARK: - Ride Detail Screen

private struct RideDetailScreen: View {
    private enum PhotoPickerSource: String, Identifiable {
        case camera
        case library

        var id: String { rawValue }

        var uiKitSourceType: UIImagePickerController.SourceType {
            switch self {
            case .camera: return .camera
            case .library: return .photoLibrary
            }
        }
    }

    let ride: SavedRide
    let initialPhoto: UIImage?
    let bikes: [GarageBike]
    let onExportJSONL: (() -> URL?)?
    let onClose: () -> Void
    let onRename: (String) -> RideStore.RenameRideResult
    let onSetBike: (UUID?) -> RideStore.SetRideBikeResult
    let onShare: () -> Void
    let onSetPhoto: (UIImage) -> RideStore.SetRidePhotoResult
    let onDelete: () -> RideStore.DeleteRideResult

    @State private var draftName: String
    @State private var selectedBikeID: UUID?
    @State private var photoImage: UIImage?
    @State private var showDuplicateAlert = false
    @State private var showRenameFailedAlert = false
    @State private var showBikeSaveFailedAlert = false
    @State private var showDeleteConfirm = false
    @State private var showDeleteFailedAlert = false
    @State private var showPhotoSourceDialog = false
    @State private var showPhotoSaveFailedAlert = false
    @State private var photoPickerSource: PhotoPickerSource?
    @State private var exportURL: URL?
    @State private var showExportSheet = false
    @State private var showExportFailedAlert = false

    init(ride: SavedRide,
         initialPhoto: UIImage?,
         bikes: [GarageBike],
         onExportJSONL: (() -> URL?)? = nil,
         onClose: @escaping () -> Void,
         onRename: @escaping (String) -> RideStore.RenameRideResult,
         onSetBike: @escaping (UUID?) -> RideStore.SetRideBikeResult,
         onShare: @escaping () -> Void,
         onSetPhoto: @escaping (UIImage) -> RideStore.SetRidePhotoResult,
         onDelete: @escaping () -> RideStore.DeleteRideResult) {
        self.ride = ride
        self.initialPhoto = initialPhoto
        self.bikes = bikes
        self.onExportJSONL = onExportJSONL
        self.onClose = onClose
        self.onRename = onRename
        self.onSetBike = onSetBike
        self.onShare = onShare
        self.onSetPhoto = onSetPhoto
        self.onDelete = onDelete
        _draftName = State(initialValue: ride.name)
        _selectedBikeID = State(initialValue: ride.bikeID)
        _photoImage = State(initialValue: initialPhoto)
    }

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            VStack(spacing: 12) {
                // Header bar
                HStack {
                    Button { onClose() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.textGhost)
                    }
                    Spacer()
                    Button { onShare() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.appAccent.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 4)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Ride name", text: $draftName)
                                .textFieldStyle(.roundedBorder)
                                .font(.title3.weight(.semibold))

                            Button("Save Name") {
                                switch onRename(draftName) {
                                case .success: break
                                case .duplicateName: showDuplicateAlert = true
                                case .notFound, .writeFailed: showRenameFailedAlert = true
                                }
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                        }

                        // Bike picker
                        Menu {
                            Button("No bike") {
                                switch onSetBike(nil) {
                                case .success: selectedBikeID = nil
                                case .notFound, .writeFailed: showBikeSaveFailedAlert = true
                                }
                            }
                            ForEach(bikes) { bike in
                                Button(bike.title) {
                                    switch onSetBike(bike.id) {
                                    case .success: selectedBikeID = bike.id
                                    case .notFound, .writeFailed: showBikeSaveFailedAlert = true
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Bike Used")
                                        .font(.caption)
                                        .foregroundStyle(Color.textTertiary)
                                    Text(selectedBikeLabel)
                                        .foregroundStyle(Color.textPrimary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.textSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.appSurface2)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        // Photo
                        Button { showPhotoSourceDialog = true } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.appSurface2)
                                    .frame(height: 160)

                                if let photoImage {
                                    Image(uiImage: photoImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 160)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                } else {
                                    VStack(spacing: 6) {
                                        Image(systemName: "photo.on.rectangle")
                                            .font(.system(size: 24, weight: .regular))
                                            .foregroundStyle(Color.textTertiary)
                                        Text("Add Ride Photo")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.textSecondary)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        Rectangle()
                            .fill(Color.appDivider)
                            .frame(height: 1)

                        // Date
                        Text(dateTimeText(ride.createdAt))
                            .font(.subheadline)
                            .foregroundStyle(Color.textTertiary)

                        // Stats
                        VStack(spacing: 10) {
                            detailRow("Total Time", metricText(.duration))
                            detailRow("Max Speed", metricText(.maxSpeed))
                            detailRow("Avg Speed", metricText(.averageSpeed))
                            detailRow("Max Lean", metricText(.maxLean))
                            detailRow("Distance", metricText(.distance))
                        }

                        if onExportJSONL != nil {
                            SecondaryButton(title: "Export JSONL") {
                                if let url = onExportJSONL?() {
                                    exportURL = url
                                    showExportSheet = true
                                } else {
                                    showExportFailedAlert = true
                                }
                            }
                        }

                        Spacer(minLength: 20)

                        PrimaryButton(title: "Delete Ride", isDestructive: true) {
                            showDeleteConfirm = true
                        }
                    }
                    .padding(16)
                }
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(12)
        }
        .alert("Ride name already exists", isPresented: $showDuplicateAlert) {
            Button("OK", role: .cancel) { }
        } message: { Text("Please choose a different name.") }
        .alert("Could not save name", isPresented: $showRenameFailedAlert) {
            Button("OK", role: .cancel) { }
        } message: { Text("Please try again.") }
        .alert("Could not save bike", isPresented: $showBikeSaveFailedAlert) {
            Button("OK", role: .cancel) { }
        } message: { Text("Please try again.") }
        .confirmationDialog("Ride Photo", isPresented: $showPhotoSourceDialog, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { photoPickerSource = .camera }
            }
            Button("Choose Photo") { photoPickerSource = .library }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(item: $photoPickerSource) { source in
            UIKitImagePicker(sourceType: source.uiKitSourceType) { image in
                switch onSetPhoto(image) {
                case .success: photoImage = image
                case .notFound, .writeFailed: showPhotoSaveFailedAlert = true
                }
            }
            .ignoresSafeArea()
        }
        .alert("Delete this ride?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                switch onDelete() {
                case .success: onClose()
                case .notFound, .deleteFailed: showDeleteFailedAlert = true
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This action cannot be undone.") }
        .alert("Could not delete ride", isPresented: $showDeleteFailedAlert) {
            Button("OK", role: .cancel) { }
        } message: { Text("Please try again.") }
        .alert("Could not save photo", isPresented: $showPhotoSaveFailedAlert) {
            Button("OK", role: .cancel) { }
        } message: { Text("Please try again.") }
        .alert("Export Failed", isPresented: $showExportFailedAlert) {
            Button("OK", role: .cancel) { }
        } message: { Text("The ride file could not be exported.") }
        .sheet(isPresented: $showExportSheet) {
            if let url = exportURL {
                ActivityView(activityItems: [url])
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
        }
    }

    private func averageSpeedMph(for summary: RideSummary) -> Double {
        guard summary.durationSec > 0 else { return 0 }
        return (summary.distanceM / summary.durationSec) * 2.23693629
    }

    private func dateTimeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func metricText(_ field: RideMetricField) -> String {
        let availability = ride.metricAvailability ?? .allAvailable
        switch field {
        case .duration:
            return availability.hasDuration ? ride.summary.durationText : "N/A"
        case .maxSpeed:
            return availability.hasMaxSpeed ? String(format: "%.1f mph", ride.summary.maxSpeedMph) : "N/A"
        case .averageSpeed:
            return availability.hasAverageSpeed ? String(format: "%.1f mph", averageSpeedMph(for: ride.summary)) : "N/A"
        case .maxLean:
            return availability.hasMaxLean ? String(format: "%.0f°", ride.summary.maxAbsLeanDeg) : "N/A"
        case .distance:
            return availability.hasDistance ? String(format: "%.2f mi", ride.summary.distanceMi) : "N/A"
        }
    }

    private var selectedBikeLabel: String {
        guard let selectedBikeID,
              let bike = bikes.first(where: { $0.id == selectedBikeID }) else {
            return "No bike"
        }
        return bike.title
    }
}

// MARK: - Ride Day Picker Sheet

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
                Button { shiftMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
                Spacer()
                Text(monthTitle(monthAnchor))
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Button { shiftMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
            }

            HStack(spacing: 0) {
                ForEach(weekdaySymbols(), id: \.self) { day in
                    Text(day)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.textTertiary)
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
                                        .fill(Color.appAccent)
                                        .frame(width: 34, height: 34)
                                }
                                Text("\(day)")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(hasRide ? Color.white : Color.textTertiary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(maxWidth: .infinity, minHeight: 36)
                    }
                }
            }

            if rideDays.isEmpty {
                Text("No ride days yet.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.top, 8)
            }
        }
        .padding(16)
        .presentationDetents([.height(420)])
        .presentationBackground(Color.appSurface)
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

// MARK: - Activity View

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
