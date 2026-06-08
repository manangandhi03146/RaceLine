import Foundation

enum SavedRideSource: String, Codable {
    case recorded
    case importedGPX
}

enum StorageMode: String, Codable, CaseIterable {
    // Legacy values (backward compat with existing saves)
    case local  = "local"
    case cloud  = "cloud"
    // Current values
    case localOnly           = "localOnly"
    case cloudSummaryOnly    = "cloudSummaryOnly"
    case cloudFull           = "cloudFull"
    case localAndCloudFull   = "localAndCloudFull"

    var displayName: String {
        switch self {
        case .local, .localOnly:         return "Phone Only"
        case .cloud, .cloudSummaryOnly:  return "Cloud Summary Only"
        case .cloudFull:                 return "Cloud Full Data"
        case .localAndCloudFull:         return "Phone + Cloud Full"
        }
    }

    var isCloudEnabled: Bool {
        switch self {
        case .local, .localOnly: return false
        default: return true
        }
    }

    var uploadsFullTelemetry: Bool {
        self == .cloudFull || self == .localAndCloudFull
    }

    var canonical: StorageMode {
        switch self {
        case .local:  return .localOnly
        case .cloud:  return .cloudSummaryOnly
        default:      return self
        }
    }
}

enum SyncStatus: String, Codable {
    case localOnly      = "localOnly"
    case pendingUpload  = "pendingUpload"
    case synced         = "synced"
    case syncFailed     = "syncFailed"
}

enum RideType: String, Codable, CaseIterable {
    case street = "street"
    case track  = "track"

    var displayName: String {
        switch self {
        case .street: return "Street"
        case .track:  return "Track"
        }
    }

    var iconName: String {
        switch self {
        case .street: return "road.lanes"
        case .track:  return "flag.checkered"
        }
    }
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

struct SavedRide: Identifiable {
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

    // Cloud sync fields
    let storageMode: StorageMode?
    let syncStatus: SyncStatus?
    let cloudPhotoPath: String?
    let cloudTelemetryPath: String?
    let remoteID: UUID?

    // Ride metadata
    let rideType: RideType?
    let notes: String?
    let tags: [String]?

    // Track mode fields
    let trackName: String?
    let sessionName: String?
    let sessionNotes: String?
    let tirePressure: String?
    let tireType: String?
    let suspensionNotes: String?

    var effectiveStorageMode: StorageMode {
        storageMode?.canonical ?? .localOnly
    }

    var effectiveSyncStatus: SyncStatus {
        syncStatus ?? .localOnly
    }

    var effectiveRideType: RideType {
        rideType ?? .street
    }

    var effectiveTags: [String] {
        tags ?? []
    }

    // Full memberwise init for creating/updating rides
    init(id: UUID, createdAt: Date, name: String, bikeID: UUID?,
         summary: RideSummary, route: [RidePoint], logFilename: String,
         photoFilename: String?, source: SavedRideSource?,
         metricAvailability: RideMetricAvailability?,
         storageMode: StorageMode?, syncStatus: SyncStatus?,
         cloudPhotoPath: String?, cloudTelemetryPath: String?,
         remoteID: UUID?,
         rideType: RideType?, notes: String?, tags: [String]?,
         trackName: String?, sessionName: String?, sessionNotes: String?,
         tirePressure: String?, tireType: String?, suspensionNotes: String?) {
        self.id = id
        self.createdAt = createdAt
        self.name = name
        self.bikeID = bikeID
        self.summary = summary
        self.route = route
        self.logFilename = logFilename
        self.photoFilename = photoFilename
        self.source = source
        self.metricAvailability = metricAvailability
        self.storageMode = storageMode
        self.syncStatus = syncStatus
        self.cloudPhotoPath = cloudPhotoPath
        self.cloudTelemetryPath = cloudTelemetryPath
        self.remoteID = remoteID
        self.rideType = rideType
        self.notes = notes
        self.tags = tags
        self.trackName = trackName
        self.sessionName = sessionName
        self.sessionNotes = sessionNotes
        self.tirePressure = tirePressure
        self.tireType = tireType
        self.suspensionNotes = suspensionNotes
    }
}

// MARK: - Codable with backward compatibility

extension SavedRide: Codable {
    enum CodingKeys: String, CodingKey {
        case id, createdAt, name, bikeID, summary, route, logFilename
        case photoFilename, source, metricAvailability
        case storageMode, syncStatus, cloudPhotoPath, cloudTelemetryPath, remoteID
        case rideType, notes, tags
        case trackName, sessionName, sessionNotes
        case tirePressure, tireType, suspensionNotes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(UUID.self,   forKey: .id)
        let createdAtRaw = try c.decode(Double.self, forKey: .createdAt)
        createdAt = createdAtRaw >= 978_307_200
            ? Date(timeIntervalSince1970: createdAtRaw)
            : Date(timeIntervalSinceReferenceDate: createdAtRaw)
        name             = try c.decode(String.self, forKey: .name)
        bikeID           = try c.decodeIfPresent(UUID.self, forKey: .bikeID)
        summary          = try c.decode(RideSummary.self, forKey: .summary)
        route            = (try? c.decode([RidePoint].self, forKey: .route)) ?? []
        logFilename      = try c.decode(String.self, forKey: .logFilename)
        photoFilename    = try c.decodeIfPresent(String.self, forKey: .photoFilename)
        source           = try? c.decodeIfPresent(SavedRideSource.self, forKey: .source)
        metricAvailability = try c.decodeIfPresent(RideMetricAvailability.self, forKey: .metricAvailability)
        storageMode      = try? c.decodeIfPresent(StorageMode.self, forKey: .storageMode)
        syncStatus       = try? c.decodeIfPresent(SyncStatus.self, forKey: .syncStatus)
        cloudPhotoPath   = try c.decodeIfPresent(String.self, forKey: .cloudPhotoPath)
        cloudTelemetryPath = try c.decodeIfPresent(String.self, forKey: .cloudTelemetryPath)
        remoteID         = try c.decodeIfPresent(UUID.self, forKey: .remoteID)
        rideType         = try? c.decodeIfPresent(RideType.self, forKey: .rideType)
        notes            = try c.decodeIfPresent(String.self, forKey: .notes)
        tags             = try c.decodeIfPresent([String].self, forKey: .tags)
        trackName        = try c.decodeIfPresent(String.self, forKey: .trackName)
        sessionName      = try c.decodeIfPresent(String.self, forKey: .sessionName)
        sessionNotes     = try c.decodeIfPresent(String.self, forKey: .sessionNotes)
        tirePressure     = try c.decodeIfPresent(String.self, forKey: .tirePressure)
        tireType         = try c.decodeIfPresent(String.self, forKey: .tireType)
        suspensionNotes  = try c.decodeIfPresent(String.self, forKey: .suspensionNotes)
    }
}
