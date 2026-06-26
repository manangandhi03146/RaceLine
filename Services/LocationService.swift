import Foundation
import CoreLocation

@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published var lat: Double?
    @Published var lon: Double?
    @Published var speedMps: Double?
    @Published var altitudeM: Double?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    /// True when the user has fully denied or restricted location. Recording
    /// would produce empty data, so callers should block the Start Ride flow.
    var isPermissionBlocked: Bool {
        switch authorizationStatus {
        case .denied, .restricted: return true
        default:                   return false
        }
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .automotiveNavigation
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        authorizationStatus = manager.authorizationStatus
    }

    /// Asks for When-In-Use authorization the first time only. No-op if the
    /// user has already made a decision (iOS won't re-prompt in that case
    /// anyway, but this avoids spamming the request).
    func requestPermission() {
        guard manager.authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.lat       = loc.coordinate.latitude
            self.lon       = loc.coordinate.longitude
            self.speedMps  = (loc.speed >= 0) ? loc.speed : nil
            self.altitudeM = loc.verticalAccuracy >= 0 ? loc.altitude : nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        print("LocationService error:", error)
    }
}
