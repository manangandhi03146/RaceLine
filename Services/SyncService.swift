import Foundation
import Network
import UIKit

// Monitors network state and drives pending-upload queue.
@MainActor
final class SyncService: ObservableObject {
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var lastSyncError: String?
    @Published private(set) var isOnline = false

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.tread.network-monitor")

    private weak var rideStore: RideStore?
    private weak var garageStore: GarageStore?
    private weak var authService: AuthService?

    // MARK: - Setup

    func configure(rideStore: RideStore, garageStore: GarageStore, authService: AuthService) {
        self.rideStore    = rideStore
        self.garageStore  = garageStore
        self.authService  = authService
    }

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let online = path.status == .satisfied
                self?.isOnline = online
                if online {
                    await self?.syncPendingIfNeeded()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    // MARK: - Manual sync

    func syncNow() async {
        await syncPendingIfNeeded()
    }

    func forceResyncAll() async {
        guard let auth = authService, auth.isLoggedIn,
              let userID = auth.userID else { return }
        isSyncing = true
        lastSyncError = nil
        rideStore?.markAllCloudRidesPendingUpload()
        await syncAllBikes(userID: userID)
        isSyncing = false
        await syncPendingIfNeeded()
    }

    // MARK: - Bike sync

    private func syncAllBikes(userID: UUID) async {
        guard let store = garageStore else { return }
        let cloudStore = CloudGarageStore()
        for bike in store.bikes {
            do {
                let photo: UIImage? = store.photoURL(for: bike).flatMap {
                    guard let data = try? Data(contentsOf: $0) else { return nil }
                    return UIImage(data: data)
                }
                let remoteID = try await cloudStore.syncBike(bike, userID: userID, photo: photo)
                _ = store.updateCloudInfo(id: bike.id, remoteID: remoteID, cloudPhotoPath: bike.cloudPhotoPath)
            } catch {
                print("SyncService: failed to sync bike \(bike.id): \(error)")
            }
        }
    }

    // MARK: - Core sync logic

    private func syncPendingIfNeeded() async {
        guard !isSyncing,
              isOnline,
              let auth = authService, auth.isLoggedIn,
              let userID = auth.userID else { return }

        isSyncing = true
        lastSyncError = nil
        defer {
            isSyncing = false
            lastSyncDate = Date()
        }

        // 1. Push any locally-recorded rides waiting to upload.
        if let store = rideStore {
            let pending = store.pendingUploadRides + store.failedSyncRides
            for ride in pending {
                await syncRide(ride, userID: userID)
            }
        }

        // 2. Pull any rides from the cloud that don't exist locally
        //    (e.g. recorded on another device with the same account).
        await pullRemoteRides(userID: userID)
    }

    // MARK: - Pull from cloud

    /// Fetches every ride summary from Supabase for the signed-in user and
    /// creates a local mirror for anything missing on disk. Photos and full
    /// telemetry files are downloaded so the ride works offline afterwards.
    private func pullRemoteRides(userID: UUID) async {
        guard let store = rideStore else { return }
        let cloud = CloudRideStore()

        let remotes: [CloudRideSummary]
        do {
            remotes = try await cloud.fetchRideSummaries(userID: userID)
        } catch {
            print("SyncService: failed to fetch remote rides: \(error)")
            return
        }

        let localIDs = Set(store.rides.map { $0.id })

        for remote in remotes {
            guard let candidateID = remote.localId, !localIDs.contains(candidateID) else { continue }

            var photoData: Data? = nil
            if remote.hasPhoto, let path = remote.photoPath {
                do {
                    let image = try await cloud.downloadPhoto(path: path)
                    photoData = image.jpegData(compressionQuality: 0.9)
                } catch {
                    print("SyncService: photo download failed for \(remote.id): \(error)")
                }
            }

            var telemetryData: Data? = nil
            if remote.hasFullTelemetry {
                let path = cloud.telemetryStoragePath(userID: userID, rideID: candidateID)
                do {
                    telemetryData = try await cloud.downloadTelemetry(path: path)
                } catch {
                    print("SyncService: telemetry download failed for \(remote.id): \(error)")
                }
            }

            store.ingestRemote(remote, photoData: photoData, telemetryData: telemetryData)
        }
    }

    private func syncRide(_ ride: SavedRide, userID: UUID) async {
        guard let store = rideStore else { return }

        // Get photo if available
        let photo: UIImage?
        if let photoURL = store.photoURL(for: ride),
           let data = try? Data(contentsOf: photoURL) {
            photo = UIImage(data: data)
        } else {
            photo = nil
        }

        do {
            let cloudStore = CloudRideStore()
            // Canonical sync = the row upsert. If this succeeds the ride is
            // considered synced; photo/telemetry are best-effort follow-ups.
            let remoteID = try await cloudStore.syncRide(ride, userID: userID, photo: photo)

            var telemetryPath: String? = nil
            if ride.effectiveStorageMode.uploadsFullTelemetry,
               let telemetryURL = store.telemetryURL(for: ride) {
                let path = cloudStore.telemetryStoragePath(userID: userID, rideID: ride.id)
                do {
                    try await cloudStore.uploadTelemetry(fileURL: telemetryURL, path: path)
                    telemetryPath = path
                } catch {
                    // Don't mark the ride as failed — the summary row is in the cloud.
                    print("SyncService: telemetry upload failed for ride \(ride.id): \(error)")
                }
            }

            let photoPath = photo != nil ? cloudStore.photoStoragePath(userID: userID, rideID: ride.id) : nil
            store.updateCloudInfo(id: ride.id, remoteID: remoteID,
                                  cloudPhotoPath: photoPath,
                                  cloudTelemetryPath: telemetryPath)
        } catch {
            store.markSyncFailed(id: ride.id)
            lastSyncError = Self.friendlyMessage(for: error)
            print("SyncService: failed to sync ride \(ride.id): \(error)")
        }
    }

    // MARK: - Error formatting

    private static func friendlyMessage(for error: Error) -> String {
        let raw = error.localizedDescription
        if let range = raw.range(of: "Ride limit reached", options: .caseInsensitive) {
            return String(raw[range.lowerBound...])
        }
        return "Some rides failed to sync. Tap Retry to try again."
    }
}
