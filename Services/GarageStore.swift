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

    func load() {
        do {
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

            let folders = (try? FileManager.default.contentsOfDirectory(
                at: baseURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []

            var loaded: [GarageBike] = []
            for folder in folders where folder.hasDirectoryPath {
                let metaURL = folder.appendingPathComponent("meta.json")
                if FileManager.default.fileExists(atPath: metaURL.path),
                   let data = try? Data(contentsOf: metaURL),
                   let bike = try? JSONDecoder().decode(GarageBike.self, from: data) {
                    loaded.append(bike)
                }
            }

            loaded.sort { $0.createdAt > $1.createdAt }
            bikes = loaded
        } catch {
            print("GarageStore.load error:", error)
        }
    }

    func addBike(nickname: String,
                 year: Int?,
                 make: String,
                 model: String,
                 photo: UIImage?) -> AddBikeResult {
        do {
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

            let id = UUID()
            let folder = baseURL.appendingPathComponent(id.uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

            var photoFilename: String?
            if let photo {
                let filename = "bike-photo.jpg"
                photoFilename = filename
                guard let imageData = photo.jpegData(compressionQuality: 0.8) else {
                    return .writeFailed
                }
                try imageData.write(
                    to: folder.appendingPathComponent(filename, isDirectory: false),
                    options: [.atomic]
                )
            }

            let bike = GarageBike(
                id: id,
                createdAt: Date(),
                nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
                year: year,
                make: make.trimmingCharacters(in: .whitespacesAndNewlines),
                model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                photoFilename: photoFilename,
                storageMode: nil,
                cloudPhotoPath: nil,
                remoteID: nil
            )

            let metaURL = folder.appendingPathComponent("meta.json")
            let data = try JSONEncoder().encode(bike)
            try data.write(to: metaURL, options: [.atomic])

            bikes.insert(bike, at: 0)
            return .success(bike)
        } catch {
            print("GarageStore.addBike error:", error)
            return .writeFailed
        }
    }

    func photoURL(for bike: GarageBike) -> URL? {
        guard let photoFilename = bike.photoFilename else { return nil }
        let folder = baseURL.appendingPathComponent(bike.id.uuidString, isDirectory: true)
        let photoURL = folder.appendingPathComponent(photoFilename, isDirectory: false)
        guard FileManager.default.fileExists(atPath: photoURL.path) else { return nil }
        return photoURL
    }

    func updateBike(id: UUID,
                    nickname: String,
                    year: Int?,
                    make: String,
                    model: String) -> UpdateBikeResult {
        guard let index = bikes.firstIndex(where: { $0.id == id }) else {
            return .notFound
        }

        let current = bikes[index]
        let updated = GarageBike(
            id: current.id,
            createdAt: current.createdAt,
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            year: year,
            make: make.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            photoFilename: current.photoFilename,
            storageMode: current.storageMode,
            cloudPhotoPath: current.cloudPhotoPath,
            remoteID: current.remoteID
        )

        return writeBike(updated, at: index)
    }

    func setBikePhoto(id: UUID, image: UIImage) -> SetBikePhotoResult {
        guard let index = bikes.firstIndex(where: { $0.id == id }) else {
            return .notFound
        }

        let folder = baseURL.appendingPathComponent(id.uuidString, isDirectory: true)
        let photoFilename = "bike-photo.jpg"
        let photoURL = folder.appendingPathComponent(photoFilename, isDirectory: false)

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return .writeFailed
        }

        do {
            try imageData.write(to: photoURL, options: [.atomic])
            let current = bikes[index]
            let updated = GarageBike(
                id: current.id,
                createdAt: current.createdAt,
                nickname: current.nickname,
                year: current.year,
                make: current.make,
                model: current.model,
                photoFilename: photoFilename,
                storageMode: current.storageMode,
                cloudPhotoPath: current.cloudPhotoPath,
                remoteID: current.remoteID
            )

            switch writeBike(updated, at: index) {
            case .success:
                return .success
            case .notFound:
                return .notFound
            case .writeFailed:
                return .writeFailed
            }
        } catch {
            print("GarageStore.setBikePhoto error:", error)
            return .writeFailed
        }
    }

    func deleteBike(id: UUID) -> DeleteBikeResult {
        guard let index = bikes.firstIndex(where: { $0.id == id }) else {
            return .notFound
        }

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

    func updateCloudInfo(id: UUID, remoteID: UUID, cloudPhotoPath: String?) -> Bool {
        guard let index = bikes.firstIndex(where: { $0.id == id }) else { return false }
        let current = bikes[index]
        let updated = GarageBike(
            id: current.id,
            createdAt: current.createdAt,
            nickname: current.nickname,
            year: current.year,
            make: current.make,
            model: current.model,
            photoFilename: current.photoFilename,
            storageMode: .cloud,
            cloudPhotoPath: cloudPhotoPath ?? current.cloudPhotoPath,
            remoteID: remoteID
        )
        switch writeBike(updated, at: index) {
        case .success: return true
        default: return false
        }
    }

    private func writeBike(_ bike: GarageBike, at index: Int) -> UpdateBikeResult {
        let folder = baseURL.appendingPathComponent(bike.id.uuidString, isDirectory: true)
        let metaURL = folder.appendingPathComponent("meta.json")

        do {
            let data = try JSONEncoder().encode(bike)
            try data.write(to: metaURL, options: [.atomic])
            bikes[index] = bike
            return .success
        } catch {
            print("GarageStore.writeBike error:", error)
            return .writeFailed
        }
    }
}
