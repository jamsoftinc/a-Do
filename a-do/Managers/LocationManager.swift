import Foundation
import CoreLocation
import os
import Observation
import Contacts

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var geocodingTask: Task<Void, Never>?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentLocation: CLLocation?
    var isUpdatingLocation: Bool = false
    var currentAddress: String?
    var lastLocationError: String?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5 // Update location when user moves 5 meters
        manager.pausesLocationUpdatesAutomatically = false
        
        // Only enable background location updates if the app has background modes configured
        // This prevents crashes when background location is not properly set up
        if Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") != nil {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }
        
        // Initialize authorization status
        authorizationStatus = manager.authorizationStatus
    }
    
    // Helper method to validate coordinates
    static func isValidCoordinate(latitude: Double, longitude: Double) -> Bool {
        return latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180
    }

    func requestAuthorization(always: Bool = false) {
        Logger(subsystem: "a-do", category: "Location").info("Requesting location authorization: always=\(always)")
        
        if always {
            manager.requestAlwaysAuthorization()
        } else {
            manager.requestWhenInUseAuthorization()
        }
    }
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            let errorMsg = "Cannot start location updates: authorization not granted (status: \(authorizationStatus.rawValue))"
            Logger(subsystem: "a-do", category: "Location").error("\(errorMsg)")
            lastLocationError = errorMsg
            return
        }
        
        isUpdatingLocation = true
        lastLocationError = nil
        manager.startUpdatingLocation()
        Logger(subsystem: "a-do", category: "Location").info("Started location updates")
    }
    
    func stopLocationUpdates() {
        isUpdatingLocation = false
        manager.stopUpdatingLocation()
        Logger(subsystem: "a-do", category: "Location").info("Stopped location updates")
    }
    
    func getCurrentLocation() async -> CLLocation? {
        Logger(subsystem: "a-do", category: "Location").info("Getting current location...")
        
        // Check authorization first
        if authorizationStatus == .denied || authorizationStatus == .restricted {
            let errorMsg = "Location access denied or restricted (status: \(authorizationStatus.rawValue))"
            Logger(subsystem: "a-do", category: "Location").error("\(errorMsg)")
            lastLocationError = errorMsg
            return nil
        }
        
        // If we already have a recent location, return it
        if let location = currentLocation, 
           Date().timeIntervalSince(location.timestamp) < 300 { // 5 minutes
            Logger(subsystem: "a-do", category: "Location").info("Using cached location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            return location
        }
        
        // Otherwise, start updates and wait for a location
        startLocationUpdates()
        
        // Wait for up to 15 seconds for a location update
        for attempt in 0..<150 {
            if let location = currentLocation {
                Logger(subsystem: "a-do", category: "Location").info("Location obtained after \(Double(attempt) * 0.1) seconds: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                stopLocationUpdates()
                return location
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        stopLocationUpdates()
        let errorMsg = "Failed to get location after 15 seconds"
        Logger(subsystem: "a-do", category: "Location").error("\(errorMsg)")
        lastLocationError = errorMsg
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
            Logger(subsystem: "a-do", category: "Location").error("Reverse geocoding failed: \(error)")
        }
    }

    func startMonitoring(label: String, latitude: Double, longitude: Double, radius: Double, notifyOnEntry: Bool, notifyOnExit: Bool) {
        // Validate coordinates before creating region
        guard Self.isValidCoordinate(latitude: latitude, longitude: longitude) else {
            Logger(subsystem: "a-do", category: "Location").error("Invalid coordinates for monitoring: lat=\(latitude), lon=\(longitude)")
            return
        }
        
        // Only allow region monitoring if background location is properly configured
        guard Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") != nil else {
            Logger(subsystem: "a-do", category: "Location").error("Cannot start region monitoring: background modes not configured")
            return
        }
        
        let clampedRadius = max(50, min(radius, 1000))
        let region = CLCircularRegion(center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), radius: clampedRadius, identifier: label)
        region.notifyOnEntry = notifyOnEntry
        region.notifyOnExit = notifyOnExit
        manager.startMonitoring(for: region)
        
        Logger(subsystem: "a-do", category: "Location").info("Started monitoring region: \(label) at (\(latitude), \(longitude)) with radius \(clampedRadius)m")
    }

    func stopMonitoring(identifier: String) {
        for region in manager.monitoredRegions where region.identifier == identifier {
            manager.stopMonitoring(for: region)
            Logger(subsystem: "a-do", category: "Location").info("Stopped monitoring region: \(identifier)")
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let oldStatus = self.authorizationStatus
            self.authorizationStatus = manager.authorizationStatus
            Logger(subsystem: "a-do", category: "Location").info("Location authorization changed from \(oldStatus.rawValue) to \(manager.authorizationStatus.rawValue)")
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
            self.lastLocationError = nil
            Logger(subsystem: "a-do", category: "Location").info("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude) (accuracy: \(location.horizontalAccuracy)m)")
            
            // Reverse geocode to get address
            await self.reverseGeocode(location: location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            let errorMsg = "Location update failed: \(String(describing: error))"
            Logger(subsystem: "a-do", category: "Location").error("\(errorMsg)")
            self.lastLocationError = errorMsg
            self.isUpdatingLocation = false
        }
    }
    
    deinit {
        // Clean up resources synchronously to avoid deinit issues
        // Note: We can't call async methods in deinit, so we'll just clean up what we can
        geocodingTask?.cancel()
        geocodingTask = nil

        // Stop monitoring all regions
        // Create a copy of the set to avoid mutating while iterating
        let regionsToStop = Array(manager.monitoredRegions)
        for region in regionsToStop {
            manager.stopMonitoring(for: region)
        }
    }
}
