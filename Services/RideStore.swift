import Foundation
import UIKit

@MainActor
final class RideStore: ObservableObject {
    enum RenameRideResult {
        case success
        case duplicateName
        case notFound
        case writeFailed
    }

    enum DeleteRideResult {
        case success
        case notFound
        case deleteFailed
    }

    enum SetRidePhotoResult {
        case success
        case notFound
        case writeFailed
    }

    enum SetRideBikeResult {
        case success
        case notFound
        case writeFailed
    }

    enum ImportRideResult {
        case success(SavedRide)
        case duplicateName
        case writeFailed
    }

    @Published private(set) var rides: [SavedRide] = []

    private var baseURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("rides", isDirectory: true)
    }

    // MARK: - Load

    func load() {
        do {
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

            let folders = (try? FileManager.default.contentsOfDirectory(
                at: baseURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []

            var loaded: [SavedRide] = []
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970

            for folder in folders where folder.hasDirectoryPath {
                let metaURL = folder.appendingPathComponent("meta.json")
                if FileManager.default.fileExists(atPath: metaURL.path),
                   let data = try? Data(contentsOf: metaURL),
                   let ride = try? decoder.decode(SavedRide.self, from: data) {
                    loaded.append(ride)
                }
            }

            loaded.sort { $0.createdAt > $1.createdAt }
            rides = loaded
        } catch {
            print("RideStore.load error:", error)
        }
    }

    // MARK: - Save new ride

    func saveRide(name: String,
                  summary: RideSummary,
                  route: [RidePoint],
                  logTempURL: URL,
                  rideBikeID: UUID? = nil,
                  ridePhoto: UIImage? = nil,
                  rideType: RideType = .street,
                  notes: String? = nil,
                  tags: [String] = [],
                  trackName: String? = nil,
                  sessionName: String? = nil,
                  sessionNotes: String? = nil,
                  tirePressure: String? = nil,
                  tireType: String? = nil,
                  suspensionNotes: String? = nil,
                  storageMode: StorageMode = .localOnly) -> SavedRide? {
        do {
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

            let finalName = displayName(name)
            guard !hasRide(named: finalName) else { return nil }

            let id = UUID()
            let folder = baseURL.appendingPathComponent(id.uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

            let logName = "samples.jsonl"
            let destLogURL = folder.appendingPathComponent(logName)
            if FileManager.default.fileExists(atPath: destLogURL.path) {
                try FileManager.default.removeItem(at: destLogURL)
            }
            try FileManager.default.copyItem(at: logTempURL, to: destLogURL)

            var photoFilename: String?
            if let ridePhoto {
                let filename = "ride-photo.jpg"
                photoFilename = filename
                guard let imageData = ridePhoto.jpegData(compressionQuality: 0.8) else { return nil }
                try imageData.write(
                    to: folder.appendingPathComponent(filename, isDirectory: false),
                    options: [.atomic]
                )
            }

            let ride = SavedRide(
                id: id, createdAt: Date(), name: finalName, bikeID: rideBikeID,
                summary: summary, route: route, logFilename: logName,
                photoFilename: photoFilename, source: .recorded,
                metricAvailability: .allAvailable,
                storageMode: storageMode,
                syncStatus: storageMode.isCloudEnabled ? .pendingUpload : .localOnly,
                cloudPhotoPath: nil, cloudTelemetryPath: nil, remoteID: nil,
                rideType: rideType, notes: notes,
                tags: tags.isEmpty ? nil : tags,
                trackName: trackName, sessionName: sessionName,
                sessionNotes: sessionNotes, tirePressure: tirePressure,
                tireType: tireType, suspensionNotes: suspensionNotes
            )

            try writeMeta(ride, to: folder)
            rides.insert(ride, at: 0)
            return ride
        } catch {
            print("RideStore.saveRide error:", error)
            return nil
        }
    }

    // MARK: - Duplicate check

    func hasRide(named name: String, excludingID: UUID? = nil) -> Bool {
        let normalized = normalizedKey(name)
        return rides.contains { ride in
            if let excludingID, ride.id == excludingID { return false }
            return normalizedKey(ride.name) == normalized
        }
    }

    // MARK: - Rename

    func renameRide(id: UUID, newName: String) -> RenameRideResult {
        let finalName = displayName(newName)
        guard !hasRide(named: finalName, excludingID: id) else { return .duplicateName }
        guard let index = rides.firstIndex(where: { $0.id == id }) else { return .notFound }
        let updated = copying(rides[index]) { $0.name = finalName }
        return writeAndUpdate(updated, at: index) ? .success : .writeFailed
    }

    // MARK: - Update notes / tags

    func updateNotesAndTags(id: UUID, notes: String?, tags: [String]) -> Bool {
        guard let index = rides.firstIndex(where: { $0.id == id }) else { return false }
        let updated = copying(rides[index]) {
            $0.notes = notes
            $0.tags  = tags.isEmpty ? nil : tags
        }
        return writeAndUpdate(updated, at: index)
    }

    // MARK: - Set photo

    func setRidePhoto(id: UUID, image: UIImage) -> SetRidePhotoResult {
        guard let index = rides.firstIndex(where: { $0.id == id }) else { return .notFound }
        let folder = baseURL.appendingPathComponent(id.uuidString, isDirectory: true)
        let photoFilename = "ride-photo.jpg"
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return .writeFailed }
        do {
            try imageData.write(to: folder.appendingPathComponent(photoFilename), options: [.atomic])
            let updated = copying(rides[index]) { $0.photoFilename = photoFilename }
            return writeAndUpdate(updated, at: index) ? .success : .writeFailed
        } catch {
            print("RideStore.setRidePhoto error:", error)
            return .writeFailed
        }
    }

    // MARK: - Set bike

    func setRideBike(id: UUID, bikeID: UUID?) -> SetRideBikeResult {
        guard let index = rides.firstIndex(where: { $0.id == id }) else { return .notFound }
        let updated = copying(rides[index]) { $0.bikeID = bikeID }
        return writeAndUpdate(updated, at: index) ? .success : .writeFailed
    }

    // MARK: - Delete

    func deleteRide(id: UUID) -> DeleteRideResult {
        guard let index = rides.firstIndex(where: { $0.id == id }) else { return .notFound }
        let folder = baseURL.appendingPathComponent(id.uuidString, isDirectory: true)
        do {
            if FileManager.default.fileExists(atPath: folder.path) {
                try FileManager.default.removeItem(at: folder)
            }
            rides.remove(at: index)
            return .success
        } catch {
            print("RideStore.deleteRide error:", error)
            return .deleteFailed
        }
    }

    // MARK: - Cloud sync state

    func updateCloudInfo(id: UUID, remoteID: UUID, cloudPhotoPath: String?,
                         cloudTelemetryPath: String? = nil) -> Bool {
        guard let index = rides.firstIndex(where: { $0.id == id }) else { return false }
        let updated = copying(rides[index]) {
            $0.remoteID           = remoteID
            $0.syncStatus         = .synced
            $0.cloudPhotoPath     = cloudPhotoPath ?? $0.cloudPhotoPath
            $0.cloudTelemetryPath = cloudTelemetryPath ?? $0.cloudTelemetryPath
            $0.storageMode        = $0.storageMode?.canonical ?? .cloudSummaryOnly
        }
        return writeAndUpdate(updated, at: index)
    }

    func markSyncFailed(id: UUID) -> Bool {
        guard let index = rides.firstIndex(where: { $0.id == id }) else { return false }
        let updated = copying(rides[index]) { $0.syncStatus = .syncFailed }
        return writeAndUpdate(updated, at: index)
    }

    func markPendingUpload(id: UUID) -> Bool {
        guard let index = rides.firstIndex(where: { $0.id == id }) else { return false }
        let updated = copying(rides[index]) { $0.syncStatus = .pendingUpload }
        return writeAndUpdate(updated, at: index)
    }

    func markAllCloudRidesPendingUpload() {
        rides
            .filter { $0.effectiveStorageMode.isCloudEnabled }
            .forEach { _ = markPendingUpload(id: $0.id) }
    }

    // MARK: - Import

    func importRide(name: String,
                    createdAt: Date,
                    summary: RideSummary,
                    route: [RidePoint],
                    sourceFileURL: URL,
                    rideBikeID: UUID? = nil,
                    metricAvailability: RideMetricAvailability) -> ImportRideResult {
        do {
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
            let finalName = displayName(name)
            guard !hasRide(named: finalName) else { return .duplicateName }

            let id = UUID()
            let folder = baseURL.appendingPathComponent(id.uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

            let ext     = sourceFileURL.pathExtension.isEmpty ? "gpx" : sourceFileURL.pathExtension
            let logName = "import.\(ext)"
            try FileManager.default.copyItem(at: sourceFileURL,
                                             to: folder.appendingPathComponent(logName))

            let ride = SavedRide(
                id: id, createdAt: createdAt, name: finalName, bikeID: rideBikeID,
                summary: summary, route: route, logFilename: logName,
                photoFilename: nil, source: .importedGPX,
                metricAvailability: metricAvailability,
                storageMode: .localOnly, syncStatus: .localOnly,
                cloudPhotoPath: nil, cloudTelemetryPath: nil, remoteID: nil,
                rideType: .street, notes: nil, tags: nil,
                trackName: nil, sessionName: nil, sessionNotes: nil,
                tirePressure: nil, tireType: nil, suspensionNotes: nil
            )

            try writeMeta(ride, to: folder)
            rides.insert(ride, at: 0)
            return .success(ride)
        } catch {
            print("RideStore.importRide error:", error)
            return .writeFailed
        }
    }

    // MARK: - URLs

    func photoURL(for ride: SavedRide) -> URL? {
        guard let photoFilename = ride.photoFilename else { return nil }
        let url = baseURL.appendingPathComponent(ride.id.uuidString).appendingPathComponent(photoFilename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func jsonlExportURL(for ride: SavedRide) -> URL? {
        guard ride.logFilename.hasSuffix(".jsonl") else { return nil }
        let sourceURL = baseURL.appendingPathComponent(ride.id.uuidString).appendingPathComponent(ride.logFilename)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return nil }
        let safeName = ride.name
            .components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let filename = (safeName.isEmpty ? "ride" : safeName) + ".jsonl"
        let destURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: destURL)
        try? FileManager.default.copyItem(at: sourceURL, to: destURL)
        return FileManager.default.fileExists(atPath: destURL.path) ? destURL : nil
    }

    func telemetryURL(for ride: SavedRide) -> URL? {
        guard ride.logFilename.hasSuffix(".jsonl") else { return nil }
        let url = baseURL.appendingPathComponent(ride.id.uuidString).appendingPathComponent(ride.logFilename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Computed stats

    var pendingUploadRides: [SavedRide] {
        rides.filter { $0.effectiveSyncStatus == .pendingUpload }
    }

    var failedSyncRides: [SavedRide] {
        rides.filter { $0.effectiveSyncStatus == .syncFailed }
    }

    var latest: SavedRide? { rides.first }

    // MARK: - Bike stats helper

    func rides(forBikeID bikeID: UUID) -> [SavedRide] {
        rides.filter { $0.bikeID == bikeID }
    }

    // MARK: - Private helpers

    private func displayName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Ride" : trimmed
    }

    private func normalizedKey(_ name: String) -> String {
        displayName(name).lowercased()
    }

    private func writeMeta(_ ride: SavedRide, to folder: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(ride)
        try data.write(to: folder.appendingPathComponent("meta.json"), options: [.atomic])
    }

    @discardableResult
    private func writeAndUpdate(_ updated: SavedRide, at index: Int) -> Bool {
        let folder = baseURL.appendingPathComponent(updated.id.uuidString, isDirectory: true)
        do {
            try writeMeta(updated, to: folder)
            rides[index] = updated
            return true
        } catch {
            print("RideStore.writeAndUpdate error:", error)
            return false
        }
    }

    // Builder pattern for safe copying of immutable struct
    private func copying(_ ride: SavedRide, mutations: (inout RideDraft) -> Void) -> SavedRide {
        var draft = RideDraft(ride: ride)
        mutations(&draft)
        return draft.build()
    }
}

// MARK: - RideDraft (mutable builder)

private struct RideDraft {
    var id: UUID
    var createdAt: Date
    var name: String
    var bikeID: UUID?
    var summary: RideSummary
    var route: [RidePoint]
    var logFilename: String
    var photoFilename: String?
    var source: SavedRideSource?
    var metricAvailability: RideMetricAvailability?
    var storageMode: StorageMode?
    var syncStatus: SyncStatus?
    var cloudPhotoPath: String?
    var cloudTelemetryPath: String?
    var remoteID: UUID?
    var rideType: RideType?
    var notes: String?
    var tags: [String]?
    var trackName: String?
    var sessionName: String?
    var sessionNotes: String?
    var tirePressure: String?
    var tireType: String?
    var suspensionNotes: String?

    init(ride: SavedRide) {
        id = ride.id
        createdAt = ride.createdAt
        name = ride.name
        bikeID = ride.bikeID
        summary = ride.summary
        route = ride.route
        logFilename = ride.logFilename
        photoFilename = ride.photoFilename
        source = ride.source
        metricAvailability = ride.metricAvailability
        storageMode = ride.storageMode
        syncStatus = ride.syncStatus
        cloudPhotoPath = ride.cloudPhotoPath
        cloudTelemetryPath = ride.cloudTelemetryPath
        remoteID = ride.remoteID
        rideType = ride.rideType
        notes = ride.notes
        tags = ride.tags
        trackName = ride.trackName
        sessionName = ride.sessionName
        sessionNotes = ride.sessionNotes
        tirePressure = ride.tirePressure
        tireType = ride.tireType
        suspensionNotes = ride.suspensionNotes
    }

    func build() -> SavedRide {
        SavedRide(
            id: id, createdAt: createdAt, name: name, bikeID: bikeID,
            summary: summary, route: route, logFilename: logFilename,
            photoFilename: photoFilename, source: source,
            metricAvailability: metricAvailability,
            storageMode: storageMode, syncStatus: syncStatus,
            cloudPhotoPath: cloudPhotoPath, cloudTelemetryPath: cloudTelemetryPath,
            remoteID: remoteID, rideType: rideType, notes: notes, tags: tags,
            trackName: trackName, sessionName: sessionName, sessionNotes: sessionNotes,
            tirePressure: tirePressure, tireType: tireType, suspensionNotes: suspensionNotes
        )
    }
}
