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

    func load() {
        do {
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

            let folders = (try? FileManager.default.contentsOfDirectory(
                at: baseURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []

            var loaded: [SavedRide] = []
            for folder in folders where folder.hasDirectoryPath {
                let metaURL = folder.appendingPathComponent("meta.json")
                if FileManager.default.fileExists(atPath: metaURL.path),
                   let data = try? Data(contentsOf: metaURL),
                   let ride = try? JSONDecoder().decode(SavedRide.self, from: data) {
                    loaded.append(ride)
                }
            }

            loaded.sort { $0.createdAt > $1.createdAt }
            rides = loaded
        } catch {
            print("RideStore.load error:", error)
        }
    }

    func saveRide(name: String,
                  summary: RideSummary,
                  route: [RidePoint],
                  logTempURL: URL,
                  rideBikeID: UUID? = nil,
                  ridePhoto: UIImage? = nil) -> SavedRide? {
        do {
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

            let finalName = displayName(name)
            guard !hasRide(named: finalName) else {
                return nil
            }

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
                guard let imageData = ridePhoto.jpegData(compressionQuality: 0.8) else {
                    return nil
                }
                try imageData.write(
                    to: folder.appendingPathComponent(filename, isDirectory: false),
                    options: [.atomic]
                )
            }

            let ride = SavedRide(
                id: id,
                createdAt: Date(),
                name: finalName,
                bikeID: rideBikeID,
                summary: summary,
                route: route,
                logFilename: logName,
                photoFilename: photoFilename,
                source: .recorded,
                metricAvailability: .allAvailable,
                storageMode: nil,
                cloudPhotoPath: nil,
                remoteID: nil
            )

            let metaURL = folder.appendingPathComponent("meta.json")
            let data = try JSONEncoder().encode(ride)
            try data.write(to: metaURL, options: [.atomic])

            rides.insert(ride, at: 0)
            return ride
        } catch {
            print("RideStore.saveRide error:", error)
            return nil
        }
    }

    func hasRide(named name: String, excludingID: UUID? = nil) -> Bool {
        let normalized = normalizedKey(name)
        return rides.contains { ride in
            if let excludingID, ride.id == excludingID {
                return false
            }
            return normalizedKey(ride.name) == normalized
        }
    }

    func renameRide(id: UUID, newName: String) -> RenameRideResult {
        let finalName = displayName(newName)
        guard !hasRide(named: finalName, excludingID: id) else {
            return .duplicateName
        }

        guard let index = rides.firstIndex(where: { $0.id == id }) else {
            return .notFound
        }

        let current = rides[index]
        let updated = SavedRide(
            id: current.id,
            createdAt: current.createdAt,
            name: finalName,
            bikeID: current.bikeID,
            summary: current.summary,
            route: current.route,
            logFilename: current.logFilename,
            photoFilename: current.photoFilename,
            source: current.source,
            metricAvailability: current.metricAvailability,
            storageMode: current.storageMode,
            cloudPhotoPath: current.cloudPhotoPath,
            remoteID: current.remoteID
        )

        let folder = baseURL.appendingPathComponent(id.uuidString, isDirectory: true)
        let metaURL = folder.appendingPathComponent("meta.json")

        do {
            let data = try JSONEncoder().encode(updated)
            try data.write(to: metaURL, options: [.atomic])
            rides[index] = updated
            return .success
        } catch {
            print("RideStore.renameRide error:", error)
            return .writeFailed
        }
    }

    func deleteRide(id: UUID) -> DeleteRideResult {
        guard let index = rides.firstIndex(where: { $0.id == id }) else {
            return .notFound
        }

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

    func setRidePhoto(id: UUID, image: UIImage) -> SetRidePhotoResult {
        guard let index = rides.firstIndex(where: { $0.id == id }) else {
            return .notFound
        }

        let folder = baseURL.appendingPathComponent(id.uuidString, isDirectory: true)
        let photoFilename = "ride-photo.jpg"
        let photoURL = folder.appendingPathComponent(photoFilename, isDirectory: false)
        let metaURL = folder.appendingPathComponent("meta.json")

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return .writeFailed
        }

        do {
            try imageData.write(to: photoURL, options: [.atomic])

            let current = rides[index]
            let updated = SavedRide(
                id: current.id,
                createdAt: current.createdAt,
                name: current.name,
                bikeID: current.bikeID,
                summary: current.summary,
                route: current.route,
                logFilename: current.logFilename,
                photoFilename: photoFilename,
                source: current.source,
                metricAvailability: current.metricAvailability,
                storageMode: current.storageMode,
                cloudPhotoPath: current.cloudPhotoPath,
                remoteID: current.remoteID
            )

            let data = try JSONEncoder().encode(updated)
            try data.write(to: metaURL, options: [.atomic])
            rides[index] = updated
            return .success
        } catch {
            print("RideStore.setRidePhoto error:", error)
            return .writeFailed
        }
    }

    func photoURL(for ride: SavedRide) -> URL? {
        guard let photoFilename = ride.photoFilename else { return nil }
        let folder = baseURL.appendingPathComponent(ride.id.uuidString, isDirectory: true)
        let photoURL = folder.appendingPathComponent(photoFilename, isDirectory: false)
        guard FileManager.default.fileExists(atPath: photoURL.path) else { return nil }
        return photoURL
    }

    func setRideBike(id: UUID, bikeID: UUID?) -> SetRideBikeResult {
        guard let index = rides.firstIndex(where: { $0.id == id }) else {
            return .notFound
        }

        let current = rides[index]
        let updated = SavedRide(
            id: current.id,
            createdAt: current.createdAt,
            name: current.name,
            bikeID: bikeID,
            summary: current.summary,
            route: current.route,
            logFilename: current.logFilename,
            photoFilename: current.photoFilename,
            source: current.source,
            metricAvailability: current.metricAvailability,
            storageMode: current.storageMode,
            cloudPhotoPath: current.cloudPhotoPath,
            remoteID: current.remoteID
        )

        let folder = baseURL.appendingPathComponent(id.uuidString, isDirectory: true)
        let metaURL = folder.appendingPathComponent("meta.json")

        do {
            let data = try JSONEncoder().encode(updated)
            try data.write(to: metaURL, options: [.atomic])
            rides[index] = updated
            return .success
        } catch {
            print("RideStore.setRideBike error:", error)
            return .writeFailed
        }
    }

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
            guard !hasRide(named: finalName) else {
                return .duplicateName
            }

            let id = UUID()
            let folder = baseURL.appendingPathComponent(id.uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

            let fileExtension = sourceFileURL.pathExtension.isEmpty ? "gpx" : sourceFileURL.pathExtension
            let logName = "import.\(fileExtension)"
            let destURL = folder.appendingPathComponent(logName, isDirectory: false)
            try FileManager.default.copyItem(at: sourceFileURL, to: destURL)

            let ride = SavedRide(
                id: id,
                createdAt: createdAt,
                name: finalName,
                bikeID: rideBikeID,
                summary: summary,
                route: route,
                logFilename: logName,
                photoFilename: nil,
                source: .importedGPX,
                metricAvailability: metricAvailability,
                storageMode: nil,
                cloudPhotoPath: nil,
                remoteID: nil
            )

            let metaURL = folder.appendingPathComponent("meta.json")
            let data = try JSONEncoder().encode(ride)
            try data.write(to: metaURL, options: [.atomic])

            rides.insert(ride, at: 0)
            return .success(ride)
        } catch {
            print("RideStore.importRide error:", error)
            return .writeFailed
        }
    }

    func updateCloudInfo(id: UUID, remoteID: UUID, cloudPhotoPath: String?) -> Bool {
        guard let index = rides.firstIndex(where: { $0.id == id }) else { return false }
        let current = rides[index]
        let updated = SavedRide(
            id: current.id,
            createdAt: current.createdAt,
            name: current.name,
            bikeID: current.bikeID,
            summary: current.summary,
            route: current.route,
            logFilename: current.logFilename,
            photoFilename: current.photoFilename,
            source: current.source,
            metricAvailability: current.metricAvailability,
            storageMode: .cloud,
            cloudPhotoPath: cloudPhotoPath ?? current.cloudPhotoPath,
            remoteID: remoteID
        )
        let folder = baseURL.appendingPathComponent(id.uuidString, isDirectory: true)
        let metaURL = folder.appendingPathComponent("meta.json")
        guard let data = try? JSONEncoder().encode(updated),
              (try? data.write(to: metaURL, options: [.atomic])) != nil else { return false }
        rides[index] = updated
        return true
    }

    private func displayName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Ride" : trimmed
    }

    private func normalizedKey(_ name: String) -> String {
        displayName(name).lowercased()
    }

    var latest: SavedRide? { rides.first }
}
