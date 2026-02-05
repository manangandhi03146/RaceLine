import Foundation

@MainActor
final class RideStore: ObservableObject {
    @Published private(set) var rides: [SavedRide] = []

    private var baseURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("rides", isDirectory: true)
    }

    func load() {
        do {
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

            let folders = (try? FileManager.default.contentsOfDirectory(
                at: baseURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []

            var loaded: [SavedRide] = []
            for folder in folders where folder.hasDirectoryPath {
                let metaURL = folder.appendingPathComponent("meta.json")
                if FileManager.default.fileExists(atPath: metaURL.path),
                   let data = try? Data(contentsOf: metaURL),
                   let ride = try? JSONDecoder().decode(SavedRide.self, from: data) {
                    loaded.append(ride)
                }
            }

            loaded.sort { $0.createdAt > $1.createdAt }
            rides = loaded
        } catch {
            print("RideStore.load error:", error)
        }
    }

    func saveRide(name: String,
                  summary: RideSummary,
                  route: [RidePoint],
                  logTempURL: URL) -> SavedRide? {
        do {
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

            let id = UUID()
            let folder = baseURL.appendingPathComponent(id.uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

            let logName = "samples.jsonl"
            let destLogURL = folder.appendingPathComponent(logName)

            if FileManager.default.fileExists(atPath: destLogURL.path) {
                try FileManager.default.removeItem(at: destLogURL)
            }
            try FileManager.default.copyItem(at: logTempURL, to: destLogURL)

            let ride = SavedRide(
                id: id,
                createdAt: Date(),
                name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Ride" : name,
                summary: summary,
                route: route,
                logFilename: logName
            )

            let metaURL = folder.appendingPathComponent("meta.json")
            let data = try JSONEncoder().encode(ride)
            try data.write(to: metaURL, options: [.atomic])

            rides.insert(ride, at: 0)
            return ride
        } catch {
            print("RideStore.saveRide error:", error)
            return nil
        }
    }


    var latest: SavedRide? { rides.first }
}

