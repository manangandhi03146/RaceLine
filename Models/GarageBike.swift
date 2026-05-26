import Foundation

struct GarageBike: Codable, Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    let nickname: String
    let year: Int?
    let make: String
    let model: String
    let photoFilename: String?
    // Cloud sync fields — optional for backward compatibility with existing local JSON
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
}
