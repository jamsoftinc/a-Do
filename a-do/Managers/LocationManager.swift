import Foundation
import CoreLocation
import os
import Observation
import Contacts

@MainActor
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentLocation: CLLocation?
    var isUpdatingLocation: Bool = false
    var currentAddress: String?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 10 // Update location when user moves 10 meters
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
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            Logger(subsystem: "a-do", category: "Location").error("Cannot start location updates: authorization not granted")
            return
        }
        
        isUpdatingLocation = true
        manager.startUpdatingLocation()
        Logger(subsystem: "a-do", category: "Location").info("Started location updates")
    }
    
    func stopLocationUpdates() {
        isUpdatingLocation = false
        manager.stopUpdatingLocation()
        Logger(subsystem: "a-do", category: "Location").info("Stopped location updates")
    }
    
    func getCurrentLocation() async -> CLLocation? {
        // If we already have a recent location, return it
        if let location = currentLocation, 
           Date().timeIntervalSince(location.timestamp) < 300 { // 5 minutes
            return location
        }
        
        // Otherwise, start updates and wait for a location
        startLocationUpdates()
        
        // Wait for up to 10 seconds for a location update
        for _ in 0..<100 {
            if let location = currentLocation {
                return location
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        stopLocationUpdates()
        return nil
    }
    
    private func reverseGeocode(location: CLLocation) async {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                let address = [
                    placemark.thoroughfare,
                    placemark.subThoroughfare,
                    placemark.locality,
                    placemark.administrativeArea
                ].compactMap { $0 }.joined(separator: ", ")
                
                if !address.isEmpty {
                    currentAddress = address
                    Logger(subsystem: "a-do", category: "Location").info("Address resolved: \(address)")
                }
            }
        } catch {
            Logger(subsystem: "a-do", category: "Location").error("Reverse geocoding failed: \(String(describing: error))")
        }
    }

    func startMonitoring(label: String, latitude: Double, longitude: Double, radius: Double, notifyOnEntry: Bool, notifyOnExit: Bool) {
        // Validate coordinates before creating region
        guard Self.isValidCoordinate(latitude: latitude, longitude: longitude) else {
            Logger(subsystem: "a-do", category: "Location").error("Invalid coordinates for monitoring: lat=\(latitude), lon=\(longitude)")
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
        Logger(subsystem: "a-do", category: "Location").info("didEnterRegion: \(region.identifier)")
        Task { @MainActor in
            NotificationManager.shared.fireNow(title: "Arrived: \(region.identifier)")
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Logger(subsystem: "a-do", category: "Location").info("didExitRegion: \(region.identifier)")
        Task { @MainActor in
            NotificationManager.shared.fireNow(title: "Left: \(region.identifier)")
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            self.currentLocation = location
            Logger(subsystem: "a-do", category: "Location").info("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            
            // Reverse geocode to get address
            await self.reverseGeocode(location: location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            Logger(subsystem: "a-do", category: "Location").error("Location update failed: \(String(describing: error))")
            self.isUpdatingLocation = false
        }
    }
}


