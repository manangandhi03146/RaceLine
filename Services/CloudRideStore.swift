import Foundation
import Supabase
import UIKit

struct CloudRideStore {
    private let client  = SupabaseManager.shared.client
    private let storage = CloudStorageService()

    // MARK: - Upsert ride + optional photo

    /// Uploads the canonical ride row, then *best-effort* uploads the photo.
    /// A failed photo upload is logged but doesn't throw — the row is the
    /// authoritative sync event, and we don't want a transient storage hiccup
    /// to mark a fully-synced ride as failed.
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
            do {
                try await storage.uploadPhoto(photo, path: path, bucket: "ride-photos")
            } catch {
                print("CloudRideStore: photo upload failed for ride \(ride.id), keeping row as synced: \(error)")
            }
        }

        return returned.id
    }

    // MARK: - Upload telemetry JSONL

    func uploadTelemetry(fileURL: URL, path: String) async throws {
        let data = try Data(contentsOf: fileURL)
        try await client.storage
            .from("ride-telemetry")
            .upload(path, data: data,
                    options: FileOptions(contentType: "application/x-ndjson", upsert: true))
    }

    // MARK: - Create signed URLs for private media

    func createSignedPhotoURL(userID: UUID, rideID: UUID) async throws -> URL {
        let path = photoStoragePath(userID: userID, rideID: rideID)
        return try await storage.createSignedURL(path: path, bucket: "ride-photos")
    }

    func createSignedTelemetryURL(userID: UUID, rideID: UUID) async throws -> URL {
        let path = telemetryStoragePath(userID: userID, rideID: rideID)
        return try await storage.createSignedURL(path: path, bucket: "ride-telemetry")
    }

    // MARK: - Delete ride from DB + storage

    func deleteRide(remoteID: UUID, deletePhoto: Bool, userID: UUID, rideID: UUID) async throws {
        try await client.from("rides").delete().eq("id", value: remoteID.uuidString).execute()
        if deletePhoto {
            try? await storage.deleteObject(path: photoStoragePath(userID: userID, rideID: rideID),
                                            bucket: "ride-photos")
            try? await storage.deleteObject(path: telemetryStoragePath(userID: userID, rideID: rideID),
                                            bucket: "ride-telemetry")
        }
    }

    // MARK: - Fetch ride summaries from cloud

    func fetchRideSummaries(userID: UUID) async throws -> [CloudRideSummary] {
        let result: [CloudRideSummary] = try await client
            .from("rides")
            .select("""
                id, local_id, name, started_at, ended_at,
                duration_seconds, distance_meters, max_speed_mps,
                avg_speed_mps, max_lean_deg, ride_type, has_full_telemetry,
                has_photo, photo_path, tags, notes, storage_mode, created_at
            """)
            .eq("user_id", value: userID.uuidString)
            .order("started_at", ascending: false)
            .execute()
            .value
        return result
    }

    // MARK: - Path helpers

    func photoStoragePath(userID: UUID, rideID: UUID) -> String {
        "\(userID.uuidString)/rides/\(rideID.uuidString)/photo.jpg"
    }

    func telemetryStoragePath(userID: UUID, rideID: UUID) -> String {
        "\(userID.uuidString)/rides/\(rideID.uuidString)/telemetry.jsonl"
    }
}

// MARK: - Cloud ride summary (for fetching from DB)

struct CloudRideSummary: Decodable {
    let id: UUID
    let localId: UUID?
    let name: String?
    let startedAt: Date?
    let endedAt: Date?
    let durationSeconds: Double
    let distanceMeters: Double
    let maxSpeedMps: Double
    let avgSpeedMps: Double?
    let maxLeanDeg: Double
    let rideType: String?
    let hasFullTelemetry: Bool
    let hasPhoto: Bool
    let photoPath: String?
    let tags: [String]?
    let notes: String?
    let storageMode: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case localId = "local_id"
        case name
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationSeconds = "duration_seconds"
        case distanceMeters = "distance_meters"
        case maxSpeedMps = "max_speed_mps"
        case avgSpeedMps = "avg_speed_mps"
        case maxLeanDeg = "max_lean_deg"
        case rideType = "ride_type"
        case hasFullTelemetry = "has_full_telemetry"
        case hasPhoto = "has_photo"
        case photoPath = "photo_path"
        case tags, notes
        case storageMode = "storage_mode"
        case createdAt = "created_at"
    }
}

// MARK: - DB payload

private struct RideUpsertPayload: Encodable {
    let userId: UUID
    let localId: UUID
    let name: String
    let startedAt: Date?
    let endedAt: Date?
    let durationSeconds: Double
    let distanceMeters: Double
    let maxSpeedMps: Double
    let avgSpeedMps: Double?
    let maxLeanDeg: Double
    let maxLeftLeanDeg: Double
    let maxRightLeanDeg: Double
    let elevationGainMeters: Double?
    let hardBrakingCount: Int
    let aggressiveAccelCount: Int
    let rideType: String
    let trackName: String?
    let sessionName: String?
    let sessionNotes: String?
    let tirePressure: String?
    let tireType: String?
    let suspensionNotes: String?
    let notes: String?
    let tags: [String]
    let storageMode: String
    let hasFullTelemetry: Bool
    let hasPhoto: Bool
    let photoPath: String?
    let telemetryPath: String?
    let bikeLocalId: UUID?
    let source: String?
    let visibility: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case localId = "local_id"
        case name
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationSeconds = "duration_seconds"
        case distanceMeters = "distance_meters"
        case maxSpeedMps = "max_speed_mps"
        case avgSpeedMps = "avg_speed_mps"
        case maxLeanDeg = "max_lean_deg"
        case maxLeftLeanDeg = "max_left_lean_deg"
        case maxRightLeanDeg = "max_right_lean_deg"
        case elevationGainMeters = "elevation_gain_meters"
        case hardBrakingCount = "hard_braking_count"
        case aggressiveAccelCount = "aggressive_accel_count"
        case rideType = "ride_type"
        case trackName = "track_name"
        case sessionName = "session_name"
        case sessionNotes = "session_notes"
        case tirePressure = "tire_pressure"
        case tireType = "tire_type"
        case suspensionNotes = "suspension_notes"
        case notes, tags
        case storageMode = "storage_mode"
        case hasFullTelemetry = "has_full_telemetry"
        case hasPhoto = "has_photo"
        case photoPath = "photo_path"
        case telemetryPath = "telemetry_path"
        case bikeLocalId = "bike_local_id"
        case source, visibility
        case createdAt = "created_at"
    }

    init(ride: SavedRide, userID: UUID) {
        userId              = userID
        localId             = ride.id
        name                = ride.name
        startedAt           = ride.summary.startTime
        endedAt             = ride.summary.endTime
        durationSeconds     = ride.summary.durationSec
        distanceMeters      = ride.summary.distanceM
        maxSpeedMps         = ride.summary.maxSpeedMps
        avgSpeedMps         = ride.summary.avgSpeedMps
        maxLeanDeg          = ride.summary.maxAbsLeanDeg
        maxLeftLeanDeg      = ride.summary.maxLeanLeftDeg
        maxRightLeanDeg     = ride.summary.maxLeanRightDeg
        elevationGainMeters = ride.summary.elevationGainM
        hardBrakingCount    = ride.summary.hardBrakingCount ?? 0
        aggressiveAccelCount = ride.summary.aggressiveAccelCount ?? 0
        rideType            = ride.effectiveRideType.rawValue
        trackName           = ride.trackName
        sessionName         = ride.sessionName
        sessionNotes        = ride.sessionNotes
        tirePressure        = ride.tirePressure
        tireType            = ride.tireType
        suspensionNotes     = ride.suspensionNotes
        notes               = ride.notes
        tags                = ride.effectiveTags
        storageMode         = ride.effectiveStorageMode.rawValue
        hasFullTelemetry    = ride.effectiveStorageMode.uploadsFullTelemetry
        hasPhoto            = ride.photoFilename != nil
        photoPath           = ride.cloudPhotoPath
        telemetryPath       = ride.cloudTelemetryPath
        bikeLocalId         = ride.bikeID
        source              = ride.source?.rawValue
        visibility          = "private"
        createdAt           = ride.createdAt
    }
}
