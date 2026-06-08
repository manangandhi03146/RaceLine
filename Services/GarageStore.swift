import Foundation
import UIKit

@MainActor
final class GarageStore: ObservableObject {
    enum AddBikeResult {
        case success(GarageBike)
        case writeFailed
    }

    enum UpdateBikeResult {
        case success
        case notFound
        case writeFailed
    }

    enum SetBikePhotoResult {
        case success
        case notFound
        case writeFailed
    }

    enum DeleteBikeResult {
        case success
        case notFound
        case deleteFailed
    }

    @Published private(set) var bikes: [GarageBike] = []

    private var baseURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("garage", isDirectory: true)
    }

    // MARK: - Load

    func load() {
        do {
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
            let folders = (try? FileManager.default.contentsOfDirectory(
                at: baseURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            )) ?? []

            var loaded: [GarageBike] = []
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970

            for folder in folders where folder.hasDirectoryPath {
                let metaURL = folder.appendingPathComponent("meta.json")
                if FileManager.default.fileExists(atPath: metaURL.path),
                   let data = try? Data(contentsOf: metaURL),
                   let bike = try? decoder.decode(GarageBike.self, from: data) {
                    loaded.append(bike)
                }
            }

            loaded.sort { $0.createdAt > $1.createdAt }
            bikes = loaded
        } catch {
            print("GarageStore.load error:", error)
        }
    }

    // MARK: - Add

    func addBike(nickname: String, year: Int?, make: String, model: String,
                 photo: UIImage?, notes: String? = nil,
                 odometerMiles: Double? = nil) -> AddBikeResult {
        do {
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

            let id = UUID()
            let folder = baseURL.appendingPathComponent(id.uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

            var photoFilename: String?
            if let photo {
                let filename = "bike-photo.jpg"
                photoFilename = filename
                guard let imageData = photo.jpegData(compressionQuality: 0.8) else { return .writeFailed }
                try imageData.write(to: folder.appendingPathComponent(filename), options: [.atomic])
            }

            let isFirstBike = bikes.isEmpty
            let bike = GarageBike(
                id: id, createdAt: Date(),
                nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
                year: year,
                make: make.trimmingCharacters(in: .whitespacesAndNewlines),
                model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                photoFilename: photoFilename,
                notes: notes, isDefault: isFirstBike, isArchived: false,
                odometerMiles: odometerMiles,
                storageMode: nil, cloudPhotoPath: nil, remoteID: nil
            )

            try writeMeta(bike, to: folder)
            bikes.insert(bike, at: 0)
            return .success(bike)
        } catch {
            print("GarageStore.addBike error:", error)
            return .writeFailed
        }
    }

    // MARK: - Photo URL

    func photoURL(for bike: GarageBike) -> URL? {
        guard let photoFilename = bike.photoFilename else { return nil }
        let url = baseURL.appendingPathComponent(bike.id.uuidString).appendingPathComponent(photoFilename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Update

    func updateBike(id: UUID, nickname: String, year: Int?, make: String, model: String,
                    notes: String? = nil, odometerMiles: Double? = nil,
                    isDefault: Bool? = nil, isArchived: Bool? = nil) -> UpdateBikeResult {
        guard let index = bikes.firstIndex(where: { $0.id == id }) else { return .notFound }
        let current = bikes[index]
        let updated = GarageBike(
            id: current.id, createdAt: current.createdAt,
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            year: year,
            make: make.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            photoFilename: current.photoFilename,
            notes: notes ?? current.notes,
            isDefault: isDefault ?? current.isDefault,
            isArchived: isArchived ?? current.isArchived,
            odometerMiles: odometerMiles ?? current.odometerMiles,
            storageMode: current.storageMode,
            cloudPhotoPath: current.cloudPhotoPath,
            remoteID: current.remoteID
        )
        return writeBike(updated, at: index)
    }

    // MARK: - Set default bike

    func setDefaultBike(id: UUID) -> UpdateBikeResult {
        var allUpdated: [GarageBike] = []
        for bike in bikes {
            let updated = GarageBike(
                id: bike.id, createdAt: bike.createdAt, nickname: bike.nickname,
                year: bike.year, make: bike.make, model: bike.model,
                photoFilename: bike.photoFilename, notes: bike.notes,
                isDefault: bike.id == id, isArchived: bike.isArchived,
                odometerMiles: bike.odometerMiles,
                storageMode: bike.storageMode, cloudPhotoPath: bike.cloudPhotoPath,
                remoteID: bike.remoteID
            )
            allUpdated.append(updated)
        }
        for (i, bike) in allUpdated.enumerated() {
            let folder = baseURL.appendingPathComponent(bike.id.uuidString, isDirectory: true)
            _ = try? writeMeta(bike, to: folder)
            bikes[i] = bike
        }
        return .success
    }

    // MARK: - Photo

    func setBikePhoto(id: UUID, image: UIImage) -> SetBikePhotoResult {
        guard let index = bikes.firstIndex(where: { $0.id == id }) else { return .notFound }
        let folder = baseURL.appendingPathComponent(id.uuidString, isDirectory: true)
        let photoFilename = "bike-photo.jpg"
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return .writeFailed }
        do {
            try imageData.write(to: folder.appendingPathComponent(photoFilename), options: [.atomic])
            let current = bikes[index]
            let updated = GarageBike(
                id: current.id, createdAt: current.createdAt, nickname: current.nickname,
                year: current.year, make: current.make, model: current.model,
                photoFilename: photoFilename, notes: current.notes,
                isDefault: current.isDefault, isArchived: current.isArchived,
                odometerMiles: current.odometerMiles,
                storageMode: current.storageMode, cloudPhotoPath: current.cloudPhotoPath,
                remoteID: current.remoteID
            )
            switch writeBike(updated, at: index) {
            case .success:      return .success
            case .notFound:     return .notFound
            case .writeFailed:  return .writeFailed
            }
        } catch {
            print("GarageStore.setBikePhoto error:", error)
            return .writeFailed
        }
    }

    // MARK: - Delete / Archive

    func deleteBike(id: UUID) -> DeleteBikeResult {
        guard let index = bikes.firstIndex(where: { $0.id == id }) else { return .notFound }
        let folder = baseURL.appendingPathComponent(id.uuidString, isDirectory: true)
        do {
            if FileManager.default.fileExists(atPath: folder.path) {
                try FileManager.default.removeItem(at: folder)
            }
            bikes.remove(at: index)
            return .success
        } catch {
            print("GarageStore.deleteBike error:", error)
            return .deleteFailed
        }
    }

    func archiveBike(id: UUID) -> UpdateBikeResult {
        updateBike(id: id,
                   nickname: bikes.first(where: { $0.id == id })?.nickname ?? "",
                   year: bikes.first(where: { $0.id == id })?.year,
                   make: bikes.first(where: { $0.id == id })?.make ?? "",
                   model: bikes.first(where: { $0.id == id })?.model ?? "",
                   isArchived: true)
    }

    // MARK: - Cloud sync info

    func updateCloudInfo(id: UUID, remoteID: UUID, cloudPhotoPath: String?) -> Bool {
        guard let index = bikes.firstIndex(where: { $0.id == id }) else { return false }
        let current = bikes[index]
        let updated = GarageBike(
            id: current.id, createdAt: current.createdAt, nickname: current.nickname,
            year: current.year, make: current.make, model: current.model,
            photoFilename: current.photoFilename, notes: current.notes,
            isDefault: current.isDefault, isArchived: current.isArchived,
            odometerMiles: current.odometerMiles,
            storageMode: .cloudSummaryOnly,
            cloudPhotoPath: cloudPhotoPath ?? current.cloudPhotoPath,
            remoteID: remoteID
        )
        switch writeBike(updated, at: index) {
        case .success: return true
        default: return false
        }
    }

    var defaultBike: GarageBike? {
        bikes.first(where: { $0.effectiveIsDefault }) ?? bikes.first
    }

    // MARK: - Private

    @discardableResult
    private func writeBike(_ bike: GarageBike, at index: Int) -> UpdateBikeResult {
        let folder = baseURL.appendingPathComponent(bike.id.uuidString, isDirectory: true)
        do {
            try writeMeta(bike, to: folder)
            bikes[index] = bike
            return .success
        } catch {
            print("GarageStore.writeBike error:", error)
            return .writeFailed
        }
    }

    @discardableResult
    private func writeMeta(_ bike: GarageBike, to folder: URL) throws -> Bool {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(bike)
        try data.write(to: folder.appendingPathComponent("meta.json"), options: [.atomic])
        return true
    }
}
