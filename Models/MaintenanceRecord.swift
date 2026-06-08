import Foundation

enum MaintenanceType: String, Codable, CaseIterable {
    case oilChange        = "oilChange"
    case chainCleanLube   = "chainCleanLube"
    case chainAdjustment  = "chainAdjustment"
    case tires            = "tires"
    case brakePads        = "brakePads"
    case brakeFluid       = "brakeFluid"
    case coolant          = "coolant"
    case airFilter        = "airFilter"
    case custom           = "custom"

    var displayName: String {
        switch self {
        case .oilChange:       return "Oil Change"
        case .chainCleanLube:  return "Chain Clean/Lube"
        case .chainAdjustment: return "Chain Adjustment"
        case .tires:           return "Tires"
        case .brakePads:       return "Brake Pads"
        case .brakeFluid:      return "Brake Fluid"
        case .coolant:         return "Coolant"
        case .airFilter:       return "Air Filter"
        case .custom:          return "Custom"
        }
    }

    var iconName: String {
        switch self {
        case .oilChange:       return "drop.fill"
        case .chainCleanLube:  return "link"
        case .chainAdjustment: return "wrench.adjustable"
        case .tires:           return "circle.circle"
        case .brakePads:       return "stop.circle"
        case .brakeFluid:      return "drop"
        case .coolant:         return "thermometer.snowflake"
        case .airFilter:       return "wind"
        case .custom:          return "wrench.and.screwdriver"
        }
    }
}

struct MaintenanceRecord: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let bikeID: UUID?
    let type: MaintenanceType
    let title: String
    let date: Date
    let odometerMiles: Double?
    let notes: String?
    let reminderIntervalDays: Int?
    let reminderIntervalMiles: Double?
    let receiptPhotoFilename: String?
    let isArchived: Bool?
    let updatedAt: Date?

    // Cloud sync
    let remoteID: UUID?
    let syncStatus: SyncStatus?

    var effectiveIsArchived: Bool { isArchived ?? false }
    var effectiveSyncStatus: SyncStatus { syncStatus ?? .localOnly }

    init(id: UUID = UUID(),
         createdAt: Date = Date(),
         bikeID: UUID?,
         type: MaintenanceType,
         title: String,
         date: Date,
         odometerMiles: Double? = nil,
         notes: String? = nil,
         reminderIntervalDays: Int? = nil,
         reminderIntervalMiles: Double? = nil,
         receiptPhotoFilename: String? = nil,
         isArchived: Bool? = nil,
         updatedAt: Date? = nil,
         remoteID: UUID? = nil,
         syncStatus: SyncStatus? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.bikeID = bikeID
        self.type = type
        self.title = title
        self.date = date
        self.odometerMiles = odometerMiles
        self.notes = notes
        self.reminderIntervalDays = reminderIntervalDays
        self.reminderIntervalMiles = reminderIntervalMiles
        self.receiptPhotoFilename = receiptPhotoFilename
        self.isArchived = isArchived
        self.updatedAt = updatedAt
        self.remoteID = remoteID
        self.syncStatus = syncStatus
    }

    enum CodingKeys: String, CodingKey {
        case id, createdAt, bikeID, type, title, date, odometerMiles, notes
        case reminderIntervalDays, reminderIntervalMiles, receiptPhotoFilename
        case isArchived, updatedAt, remoteID, syncStatus
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                    = try c.decode(UUID.self,   forKey: .id)
        createdAt             = try c.decode(Date.self,   forKey: .createdAt)
        bikeID                = try c.decodeIfPresent(UUID.self,   forKey: .bikeID)
        type                  = (try? c.decode(MaintenanceType.self, forKey: .type)) ?? .custom
        title                 = try c.decode(String.self, forKey: .title)
        date                  = try c.decode(Date.self,   forKey: .date)
        odometerMiles         = try c.decodeIfPresent(Double.self, forKey: .odometerMiles)
        notes                 = try c.decodeIfPresent(String.self, forKey: .notes)
        reminderIntervalDays  = try c.decodeIfPresent(Int.self,    forKey: .reminderIntervalDays)
        reminderIntervalMiles = try c.decodeIfPresent(Double.self, forKey: .reminderIntervalMiles)
        receiptPhotoFilename  = try c.decodeIfPresent(String.self, forKey: .receiptPhotoFilename)
        isArchived            = try c.decodeIfPresent(Bool.self,   forKey: .isArchived)
        updatedAt             = try c.decodeIfPresent(Date.self,   forKey: .updatedAt)
        remoteID              = try c.decodeIfPresent(UUID.self,   forKey: .remoteID)
        syncStatus            = try? c.decodeIfPresent(SyncStatus.self, forKey: .syncStatus)
    }

    // Returns true if a date-based reminder is due (today or past due)
    func isDateReminderDue() -> Bool {
        guard let days = reminderIntervalDays else { return false }
        let dueDate = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
        return dueDate <= Date()
    }

    func daysTilDue() -> Int? {
        guard let days = reminderIntervalDays else { return nil }
        let dueDate = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
        return Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day
    }
}
