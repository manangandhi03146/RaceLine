import Foundation
import Supabase
import UIKit

struct CloudGarageStore {
    private let client  = SupabaseManager.shared.client
    private let storage = CloudStorageService()

    // MARK: - Upsert bike + optional photo

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
            try await storage.uploadPhoto(photo, path: path, bucket: "bike-photos")
        }

        return returned.id
    }

    // MARK: - Photo helpers

    func createSignedPhotoURL(userID: UUID, bikeID: UUID) async throws -> URL {
        let path = photoStoragePath(userID: userID, bikeID: bikeID)
        return try await storage.createSignedURL(path: path, bucket: "bike-photos")
    }

    func deleteBike(remoteID: UUID, deletePhoto: Bool, userID: UUID, bikeID: UUID) async throws {
        try await client.from("bikes").delete().eq("id", value: remoteID.uuidString).execute()
        if deletePhoto {
            try? await storage.deleteObject(path: photoStoragePath(userID: userID, bikeID: bikeID),
                                            bucket: "bike-photos")
        }
    }

    // MARK: - Path helpers

    func photoStoragePath(userID: UUID, bikeID: UUID) -> String {
        "\(userID.uuidString)/bikes/\(bikeID.uuidString)/photo.jpg"
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
    let notes: String?
    let odometerMiles: Double?
    let isDefault: Bool
    let isArchived: Bool
    let photoPath: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case localId = "local_id"
        case nickname, year, make, model, notes
        case odometerMiles = "odometer_miles"
        case isDefault = "is_default"
        case isArchived = "is_archived"
        case photoPath = "photo_path"
        case createdAt = "created_at"
    }

    init(bike: GarageBike, userID: UUID) {
        userId       = userID
        localId      = bike.id
        nickname     = bike.nickname
        year         = bike.year
        make         = bike.make
        model        = bike.model
        notes        = bike.notes
        odometerMiles = bike.odometerMiles
        isDefault    = bike.effectiveIsDefault
        isArchived   = bike.effectiveIsArchived
        photoPath    = bike.cloudPhotoPath
        createdAt    = bike.createdAt
    }
}
