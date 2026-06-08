import Foundation

struct GarageBike: Identifiable {
    let id: UUID
    let createdAt: Date
    let nickname: String
    let year: Int?
    let make: String
    let model: String
    let photoFilename: String?
    let notes: String?
    let isDefault: Bool?
    let isArchived: Bool?
    let odometerMiles: Double?
    // Cloud sync fields — optional for backward compatibility
    let storageMode: StorageMode?
    let cloudPhotoPath: String?
    let remoteID: UUID?

    var title: String {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? specLine : trimmed
    }

    var specLine: String {
        let yearText = year.map(String.init) ?? "Year N/A"
        return "\(yearText) \(make) \(model)"
    }

    var effectiveIsDefault: Bool { isDefault ?? false }
    var effectiveIsArchived: Bool { isArchived ?? false }
}

extension GarageBike: Codable {
    enum CodingKeys: String, CodingKey {
        case id, createdAt, nickname, year, make, model, photoFilename, notes
        case isDefault, isArchived, odometerMiles
        case storageMode, cloudPhotoPath, remoteID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(UUID.self,   forKey: .id)
        createdAt     = try c.decode(Date.self,   forKey: .createdAt)
        nickname      = try c.decode(String.self, forKey: .nickname)
        year          = try c.decodeIfPresent(Int.self,    forKey: .year)
        make          = try c.decode(String.self, forKey: .make)
        model         = try c.decode(String.self, forKey: .model)
        photoFilename = try c.decodeIfPresent(String.self, forKey: .photoFilename)
        notes         = try c.decodeIfPresent(String.self, forKey: .notes)
        isDefault     = try c.decodeIfPresent(Bool.self,   forKey: .isDefault)
        isArchived    = try c.decodeIfPresent(Bool.self,   forKey: .isArchived)
        odometerMiles = try c.decodeIfPresent(Double.self, forKey: .odometerMiles)
        storageMode   = try? c.decodeIfPresent(StorageMode.self, forKey: .storageMode)
        cloudPhotoPath = try c.decodeIfPresent(String.self, forKey: .cloudPhotoPath)
        remoteID      = try c.decodeIfPresent(UUID.self,   forKey: .remoteID)
    }
}

extension GarageBike: Hashable {
    static func == (lhs: GarageBike, rhs: GarageBike) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
