import Foundation
import UIKit
import UserNotifications

@MainActor
final class MaintenanceStore: ObservableObject {
    enum AddResult {
        case success(MaintenanceRecord)
        case writeFailed
    }

    enum UpdateResult {
        case success
        case notFound
        case writeFailed
    }

    enum DeleteResult {
        case success
        case notFound
        case deleteFailed
    }

    @Published private(set) var records: [MaintenanceRecord] = []

    private var baseURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("maintenance", isDirectory: true)
    }

    // MARK: - Load

    func load() {
        do {
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
            let folders = (try? FileManager.default.contentsOfDirectory(
                at: baseURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            )) ?? []

            var loaded: [MaintenanceRecord] = []
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970

            for folder in folders where folder.hasDirectoryPath {
                let metaURL = folder.appendingPathComponent("meta.json")
                if FileManager.default.fileExists(atPath: metaURL.path),
                   let data = try? Data(contentsOf: metaURL),
                   let record = try? decoder.decode(MaintenanceRecord.self, from: data) {
                    loaded.append(record)
                }
            }

            loaded.sort { $0.date > $1.date }
            records = loaded
        } catch {
            print("MaintenanceStore.load error:", error)
        }
    }

    // MARK: - Add

    func addRecord(_ record: MaintenanceRecord, photo: UIImage? = nil) -> AddResult {
        do {
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
            let folder = baseURL.appendingPathComponent(record.id.uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

            var finalRecord = record
            if let photo {
                let filename = "receipt.jpg"
                if let data = photo.jpegData(compressionQuality: 0.8) {
                    try data.write(to: folder.appendingPathComponent(filename), options: [.atomic])
                }
                finalRecord = MaintenanceRecord(
                    id: record.id, createdAt: record.createdAt, bikeID: record.bikeID,
                    type: record.type, title: record.title, date: record.date,
                    odometerMiles: record.odometerMiles, notes: record.notes,
                    reminderIntervalDays: record.reminderIntervalDays,
                    reminderIntervalMiles: record.reminderIntervalMiles,
                    receiptPhotoFilename: filename, isArchived: record.isArchived,
                    remoteID: record.remoteID, syncStatus: record.syncStatus
                )
            }

            try writeMeta(finalRecord, to: folder)
            records.insert(finalRecord, at: 0)

            if record.reminderIntervalDays != nil {
                scheduleReminder(for: finalRecord)
            }

            return .success(finalRecord)
        } catch {
            print("MaintenanceStore.addRecord error:", error)
            return .writeFailed
        }
    }

    // MARK: - Update

    func updateRecord(_ updated: MaintenanceRecord) -> UpdateResult {
        guard let index = records.firstIndex(where: { $0.id == updated.id }) else { return .notFound }
        let folder = baseURL.appendingPathComponent(updated.id.uuidString, isDirectory: true)
        do {
            try writeMeta(updated, to: folder)
            records[index] = updated

            cancelReminder(for: updated.id)
            if updated.reminderIntervalDays != nil {
                scheduleReminder(for: updated)
            }

            return .success
        } catch {
            print("MaintenanceStore.updateRecord error:", error)
            return .writeFailed
        }
    }

    // MARK: - Delete

    func deleteRecord(id: UUID) -> DeleteResult {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return .notFound }
        let folder = baseURL.appendingPathComponent(id.uuidString, isDirectory: true)
        do {
            if FileManager.default.fileExists(atPath: folder.path) {
                try FileManager.default.removeItem(at: folder)
            }
            cancelReminder(for: id)
            records.remove(at: index)
            return .success
        } catch {
            print("MaintenanceStore.deleteRecord error:", error)
            return .deleteFailed
        }
    }

    // MARK: - Photo URL

    func receiptPhotoURL(for record: MaintenanceRecord) -> URL? {
        guard let filename = record.receiptPhotoFilename else { return nil }
        let url = baseURL.appendingPathComponent(record.id.uuidString).appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Per-bike query

    func records(forBikeID bikeID: UUID) -> [MaintenanceRecord] {
        records.filter { $0.bikeID == bikeID && !$0.effectiveIsArchived }
    }

    func dueOrOverdueRecords(forBikeID bikeID: UUID) -> [MaintenanceRecord] {
        records(forBikeID: bikeID).filter { $0.isDateReminderDue() }
    }

    func dueSoonRecords(withinDays days: Int = 14) -> [MaintenanceRecord] {
        records.filter { record in
            guard !record.effectiveIsArchived else { return false }
            guard let daysUntilDue = record.daysTilDue() else { return false }
            return daysUntilDue >= 0 && daysUntilDue <= days
        }
    }

    // MARK: - Private helpers

    private func writeMeta(_ record: MaintenanceRecord, to folder: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(record)
        try data.write(to: folder.appendingPathComponent("meta.json"), options: [.atomic])
    }

    // MARK: - Local notifications

    private func scheduleReminder(for record: MaintenanceRecord) {
        guard let days = record.reminderIntervalDays,
              let dueDate = Calendar.current.date(byAdding: .day, value: days, to: record.date),
              dueDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Maintenance Due"
        content.body  = "\(record.title) is due for your bike."
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: "maintenance-\(record.id.uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("MaintenanceStore notification error:", error) }
        }
    }

    private func cancelReminder(for id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["maintenance-\(id.uuidString)"]
        )
    }
}
