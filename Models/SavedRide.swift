import Foundation

struct SavedRide: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let name: String
    let summary: RideSummary
    let route: [RidePoint]
    let logFilename: String
}

