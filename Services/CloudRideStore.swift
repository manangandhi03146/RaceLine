import Foundation
import Supabase
import UIKit

struct CloudRideStore {
    private let client = SupabaseManager.shared.client
    private let storage = CloudStorageService()

    // MARK: - Upsert ride metadata + optional photo upload

    func syncRide(_ ride: SavedRide, userID: UUID, photo: UIImage? = nil) async throws -> UUID {
        let payload = RideUpsertPayload(ride: ride, userID: userID)

        struct ReturnedID: Decodable { let id: UUID }
        let returned: ReturnedID = try await client
            .from("rides")
            .upsert(payload, onConflict: "user_id,local_id")
            .select("id")
            .single()
            .execute()
            .value

        if let photo {
            let path = photoStoragePath(userID: userID, rideID: ride.id)
            try await storage.uploadPhoto(photo, path: path)
        }

        return returned.id
    }

    // MARK: - Upload / refresh photo for an already-synced ride

    func uploadPhoto(_ image: UIImage, userID: UUID, rideID: UUID) async throws {
        let path = photoStoragePath(userID: userID, rideID: rideID)
        try await storage.uploadPhoto(image, path: path)
    }

    // MARK: - Create signed URL for a private cloud photo

    func createSignedPhotoURL(userID: UUID, rideID: UUID) async throws -> URL {
        let path = photoStoragePath(userID: userID, rideID: rideID)
        return try await storage.createSignedURL(path: path)
    }

    // MARK: - Delete ride from DB (+ optionally its cloud photo)

    func deleteRide(remoteID: UUID, deletePhoto: Bool, userID: UUID, rideID: UUID) async throws {
        try await client.from("rides").delete().eq("id", value: remoteID.uuidString).execute()
        if deletePhoto {
            try? await storage.deletePhoto(path: photoStoragePath(userID: userID, rideID: rideID))
        }
    }

    // MARK: - Path helpers

    func photoStoragePath(userID: UUID, rideID: UUID) -> String {
        "\(userID.uuidString)/rides/\(rideID.uuidString)/ride-photo.jpg"
    }
}

// MARK: - DB payload

private struct RideUpsertPayload: Encodable {
    let userId: UUID
    let localId: UUID
    let name: String
    let createdAt: Date
    let summary: RideSummary
    let route: [RidePoint]
    let logFilename: String
    let photoStoragePath: String?
    let source: String?
    let metricAvailability: RideMetricAvailability?
    let bikeLocalId: UUID?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case localId = "local_id"
        case name
        case createdAt = "created_at"
        case summary
        case route
        case logFilename = "log_filename"
        case photoStoragePath = "photo_storage_path"
        case source
        case metricAvailability = "metric_availability"
        case bikeLocalId = "bike_local_id"
    }

    init(ride: SavedRide, userID: UUID) {
        userId = userID
        localId = ride.id
        name = ride.name
        createdAt = ride.createdAt
        summary = ride.summary
        route = ride.route
        logFilename = ride.logFilename
        photoStoragePath = ride.cloudPhotoPath
        source = ride.source?.rawValue
        metricAvailability = ride.metricAvailability
        bikeLocalId = ride.bikeID
    }
}
