import Foundation
import CoreLocation

@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published var lat: Double?
    @Published var lon: Double?
    @Published var speedMps: Double?
    @Published var altitudeM: Double?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .automotiveNavigation
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
    }

    func requestPermission() {
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

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        print("LocationService error:", error)
    }
}
