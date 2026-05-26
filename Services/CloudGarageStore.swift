import Foundation
import Supabase
import UIKit

struct CloudGarageStore {
    private let client = SupabaseManager.shared.client
    private let storage = CloudStorageService()

    // MARK: - Upsert bike metadata + optional photo upload

    func syncBike(_ bike: GarageBike, userID: UUID, photo: UIImage? = nil) async throws -> UUID {
        let payload = BikeUpsertPayload(bike: bike, userID: userID)

        struct ReturnedID: Decodable { let id: UUID }
        let returned: ReturnedID = try await client
            .from("bikes")
            .upsert(payload, onConflict: "user_id,local_id")
            .select("id")
            .single()
            .execute()
            .value

        if let photo {
            let path = photoStoragePath(userID: userID, bikeID: bike.id)
            try await storage.uploadPhoto(photo, path: path)
        }

        return returned.id
    }

    // MARK: - Upload / refresh photo for an already-synced bike

    func uploadPhoto(_ image: UIImage, userID: UUID, bikeID: UUID) async throws {
        let path = photoStoragePath(userID: userID, bikeID: bikeID)
        try await storage.uploadPhoto(image, path: path)
    }

    // MARK: - Create signed URL for a private cloud photo

    func createSignedPhotoURL(userID: UUID, bikeID: UUID) async throws -> URL {
        let path = photoStoragePath(userID: userID, bikeID: bikeID)
        return try await storage.createSignedURL(path: path)
    }

    // MARK: - Delete bike from DB (+ optionally its cloud photo)

    func deleteBike(remoteID: UUID, deletePhoto: Bool, userID: UUID, bikeID: UUID) async throws {
        try await client.from("bikes").delete().eq("id", value: remoteID.uuidString).execute()
        if deletePhoto {
            try? await storage.deletePhoto(path: photoStoragePath(userID: userID, bikeID: bikeID))
        }
    }

    // MARK: - Path helpers

    func photoStoragePath(userID: UUID, bikeID: UUID) -> String {
        "\(userID.uuidString)/bikes/\(bikeID.uuidString)/bike-photo.jpg"
    }
}

// MARK: - DB payload

private struct BikeUpsertPayload: Encodable {
    let userId: UUID
    let localId: UUID
    let nickname: String
    let year: Int?
    let make: String
    let model: String
    let photoStoragePath: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case localId = "local_id"
        case nickname
        case year
        case make
        case model
        case photoStoragePath = "photo_storage_path"
        case createdAt = "created_at"
    }

    init(bike: GarageBike, userID: UUID) {
        userId = userID
        localId = bike.id
        nickname = bike.nickname
        year = bike.year
        make = bike.make
        model = bike.model
        photoStoragePath = bike.cloudPhotoPath
        createdAt = bike.createdAt
    }
}
