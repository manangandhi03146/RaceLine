import Foundation

enum SavedRideSource: String, Codable {
    case recorded
    case importedGPX
}

enum StorageMode: String, Codable {
    case local
    case cloud
}

struct RideMetricAvailability: Codable, Hashable {
    let hasDuration: Bool
    let hasMaxSpeed: Bool
    let hasAverageSpeed: Bool
    let hasMaxLean: Bool
    let hasDistance: Bool

    static let allAvailable = RideMetricAvailability(
        hasDuration: true,
        hasMaxSpeed: true,
        hasAverageSpeed: true,
        hasMaxLean: true,
        hasDistance: true
    )
}

struct SavedRide: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let name: String
    let bikeID: UUID?
    let summary: RideSummary
    let route: [RidePoint]
    let logFilename: String
    let photoFilename: String?
    let source: SavedRideSource?
    let metricAvailability: RideMetricAvailability?
    // Cloud sync fields — optional for backward compatibility with existing local JSON
    let storageMode: StorageMode?
    let cloudPhotoPath: String?
    let remoteID: UUID?
}
