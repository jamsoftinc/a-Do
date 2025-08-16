import Foundation
import CoreLocation
import os
import Observation

@MainActor
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private let manager = CLLocationManager()
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    // Helper method to validate coordinates
    static func isValidCoordinate(latitude: Double, longitude: Double) -> Bool {
        return latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180
    }

    func requestAuthorization(always: Bool = false) {
        if always {
            manager.requestAlwaysAuthorization()
        } else {
            manager.requestWhenInUseAuthorization()
        }
    }

    func startMonitoring(label: String, latitude: Double, longitude: Double, radius: Double, notifyOnEntry: Bool, notifyOnExit: Bool) {
        // Validate coordinates before creating region
        guard Self.isValidCoordinate(latitude: latitude, longitude: longitude) else {
            Logger(subsystem: "Remember", category: "Location").error("Invalid coordinates for monitoring: lat=\(latitude), lon=\(longitude)")
            return
        }
        
        let clampedRadius = max(50, min(radius, 1000))
        let region = CLCircularRegion(center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), radius: clampedRadius, identifier: label)
        region.notifyOnEntry = notifyOnEntry
        region.notifyOnExit = notifyOnExit
        manager.startMonitoring(for: region)
    }

    func stopMonitoring(identifier: String) {
        for region in manager.monitoredRegions where region.identifier == identifier {
            manager.stopMonitoring(for: region)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Logger(subsystem: "Remember", category: "Location").info("didEnterRegion: \(region.identifier)")
        Task { @MainActor in
            NotificationManager.shared.fireNow(title: "Arrived: \(region.identifier)")
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Logger(subsystem: "Remember", category: "Location").info("didExitRegion: \(region.identifier)")
        Task { @MainActor in
            NotificationManager.shared.fireNow(title: "Left: \(region.identifier)")
        }
    }
}


