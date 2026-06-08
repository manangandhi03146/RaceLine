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

        guard let store = rideStore,
              !store.pendingUploadRides.isEmpty && !store.failedSyncRides.isEmpty ||
              !store.pendingUploadRides.isEmpty else { return }

        isSyncing = true
        lastSyncError = nil

        let pending = store.pendingUploadRides + store.failedSyncRides

        for ride in pending {
            await syncRide(ride, userID: userID)
        }

        isSyncing = false
        lastSyncDate = Date()
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
            let remoteID = try await cloudStore.syncRide(ride, userID: userID, photo: photo)

            // Upload full telemetry if the storage mode requires it
            var telemetryPath: String? = nil
            if ride.effectiveStorageMode.uploadsFullTelemetry,
               let telemetryURL = store.telemetryURL(for: ride) {
                let path = cloudStore.telemetryStoragePath(userID: userID, rideID: ride.id)
                try await cloudStore.uploadTelemetry(fileURL: telemetryURL, path: path)
                telemetryPath = path
            }

            let photoPath = photo != nil ? cloudStore.photoStoragePath(userID: userID, rideID: ride.id) : nil
            store.updateCloudInfo(id: ride.id, remoteID: remoteID,
                                  cloudPhotoPath: photoPath,
                                  cloudTelemetryPath: telemetryPath)
        } catch {
            store.markSyncFailed(id: ride.id)
            lastSyncError = "Some rides failed to sync. Tap Retry to try again."
            print("SyncService: failed to sync ride \(ride.id): \(error)")
        }
    }
}
