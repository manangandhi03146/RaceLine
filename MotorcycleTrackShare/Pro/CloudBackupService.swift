import Foundation

/// User-visible state of the cloud backup pipeline. The Settings UI mirrors this.
enum CloudBackupStatus: Equatable {
    case foundationReady        // scaffolding lives, no coverage guarantees yet
    case active(coverage: Set<CloudBackupDomain>)
    case paused
    case failed(reason: String)

    var displayName: String {
        switch self {
        case .foundationReady: return "Foundation ready"
        case .active:          return "Active"
        case .paused:          return "Paused"
        case .failed:          return "Attention needed"
        }
    }
}

/// The discrete data domains the backup covers. Kept explicit so partial
/// coverage (e.g. rides only) can be represented honestly.
enum CloudBackupDomain: String, CaseIterable, Codable {
    case rides
    case bikes
    case maintenance
    case settings
}

/// Foundation for full-fidelity cloud backup. Today this reports status only —
/// actual per-domain uploads are handled by the existing `SyncService`,
/// `CloudRideStore`, and `CloudGarageStore`. This service exists so future work
/// (versioning, restore-from-cloud, per-domain toggles) has a single seam.
@MainActor
final class CloudBackupService: ObservableObject {

    @Published private(set) var status: CloudBackupStatus = .foundationReady
    @Published private(set) var lastAttemptedAt: Date?

    /// Which domains the foundation currently observes. Not all of these are
    /// fully synced yet — see the UI copy for what's live vs pending.
    let observedDomains: [CloudBackupDomain] = CloudBackupDomain.allCases

    // MARK: - Status control

    func markPaused() {
        status = .paused
    }

    func markResumed() {
        status = .foundationReady
    }

    /// Called by higher-level sync code when a run finishes. Kept generic so
    /// the actual sync engine can live elsewhere without depending on us.
    func recordAttempt(succeeded: Bool, reason: String? = nil) {
        lastAttemptedAt = Date()
        if succeeded {
            status = .active(coverage: Set(observedDomains))
        } else if let reason {
            status = .failed(reason: reason)
        }
    }

    // TODO: Once Pro is live, expose per-domain toggles + versioned restore
    //       flows here. Delegate the actual transport to `CloudRideStore` /
    //       `CloudGarageStore` / new `CloudMaintenanceStore`.
}
