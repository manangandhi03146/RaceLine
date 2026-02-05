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

struct ContentView: View {
    @StateObject private var motion = MotionService()
    @StateObject private var location = LocationService()
    @StateObject private var recorder = RideRecorder()
    @StateObject private var rideStore = RideStore()

    // Map camera
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.0, longitude: -74.0),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    @State private var didInitialCenter = false

    // Navigation to share screen
    @State private var showShareScreen = false

    // Stop -> Save prompt (reliable)
    @State private var awaitingSavePrompt = false
    @State private var showSavePrompt = false
    @State private var showNameSheet = false
    @State private var pendingName: String = ""
    @State private var showTooShortAlert = false
    @State private var showDuplicateAlert = false

    var body: some View {
        NavigationStack {
            Map(position: $position, interactionModes: .all) {
                UserAnnotation()
            }
            // Keep top safe area (do NOT ignore)
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .onAppear {
                rideStore.load()

                location.requestPermission()
                location.start()

                // Keep lean updating always (so Calibrate updates UI even when not recording)
                motion.start(hz: 50)
            }
            .onChange(of: location.lat) { _, _ in centerOnUserIfNeeded() }
            .onChange(of: location.lon) { _, _ in centerOnUserIfNeeded() }

            // When stop happens, RideRecorder may set summary/fileURL slightly later.
            // These observers make the save prompt reliable.
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

            // Top-left stats (no box)
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
                .padding(.top, 26) // moved down slightly
            }

            // Bottom controls: Calibrate (left), Start/Stop (center), Share (right)
            .overlay(alignment: .bottom) {
                HStack {
                    // Calibrate button (disabled while recording)
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

                    Spacer()

                    // Start/Stop button
                    Button {
                        if recorder.isRecording {
                            // Stop recording — arm the prompt first, then stop.
                            awaitingSavePrompt = true
                            recorder.stop()
                        } else {
                            // Start recording
                            recorder.start(motion: motion, location: location, sampleHz: 10)
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(recorder.isRecording ? Color.red : Color.green)
                                .frame(width: 76, height: 76)
                                .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)

                            Image(systemName: recorder.isRecording ? "stop.fill" : "play.fill")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }

                    Spacer()

                    // Share button ALWAYS clickable
                    Button {
                        showShareScreen = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }

            // Navigation to Share screen
            .navigationDestination(isPresented: $showShareScreen) {
                ShareCardScreen(
                    currentSummary: recorder.summary,
                    currentRoute: recorder.route,
                    currentLogURL: recorder.fileURL
                )
                .environmentObject(rideStore)
            }

            // Stop -> Save popup
            .confirmationDialog("Save this ride?", isPresented: $showSavePrompt, titleVisibility: .visible) {
                Button("Save") { showNameSheet = true }
                Button("Don’t Save", role: .destructive) { }
                Button("Cancel", role: .cancel) { }
            }

            // Name sheet
            .sheet(isPresented: $showNameSheet) {
                SaveRideSheet(
                    name: $pendingName,
                    onSave: {
                        guard let s = recorder.summary,
                              let log = recorder.fileURL,
                              recorder.route.count >= 2 else {
                            showNameSheet = false
                            return
                        }

                        let trimmed = pendingName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let finalName = trimmed.isEmpty ? defaultRideName() : trimmed

                        if rideStore.hasRide(named: finalName) {
                            showDuplicateAlert = true
                            return
                        }

                        _ = rideStore.saveRide(
                            name: finalName,
                            summary: s,
                            route: recorder.route,
                            logTempURL: log
                        )

                        rideStore.load()
                        showNameSheet = false
                    },
                    onCancel: { showNameSheet = false }
                )
                .presentationDetents([.height(230)])
            }

            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Reliable save prompt logic

    private func maybePresentSavePrompt() {
        guard awaitingSavePrompt else { return }

        // If ready, show the save dialog once
        if recorder.summary != nil,
           recorder.fileURL != nil,
           recorder.route.count >= 2 {
            awaitingSavePrompt = false
            pendingName = defaultRideName()
            showSavePrompt = true
            return
        }

        // If stopped but still not enough data, show a small alert and stop waiting
        if recorder.isRecording == false,
           (recorder.route.count < 2 || recorder.summary == nil || recorder.fileURL == nil) {
            awaitingSavePrompt = false
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
}
