import Foundation
import CoreLocation
import os
import Observation
import Contacts
#if canImport(MapKit)
import MapKit
#endif

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private let manager = CLLocationManager()
    private var geocodingTask: Task<Void, Never>?
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
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

    func awaitAuthorization(always: Bool = false) async -> CLAuthorizationStatus {
        let currentStatus = authorizationStatus
        if currentStatus != .notDetermined {
            return currentStatus
        }

        return await withCheckedContinuation { continuation in
            authorizationContinuation?.resume(returning: manager.authorizationStatus)
            authorizationContinuation = continuation
            requestAuthorization(always: always)
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
        var currentStatus = authorizationStatus
        if currentStatus == .notDetermined {
            currentStatus = await awaitAuthorization()
        }

        if currentStatus == .denied || currentStatus == .restricted {
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
        
        return await requestSingleLocation(timeoutNanoseconds: 15_000_000_000)
    }
    
    private func reverseGeocode(location: CLLocation) {
        geocodingTask?.cancel()
        geocodingTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                if let address = try await Self.resolveAddress(for: location), !Task.isCancelled {
                    self.currentAddress = address
                    Logger(subsystem: "a-do", category: "Location").info("Address resolved: \(address)")
                }
            } catch {
                guard !Task.isCancelled else { return }
                Logger(subsystem: "a-do", category: "Location").error("Reverse geocoding failed: \(String(describing: error))")
            }
        }
    }

    nonisolated private static func resolveAddress(for location: CLLocation) async throws -> String? {
        #if canImport(MapKit)
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        let mapItems = try await request.mapItems
        guard let mapItem = mapItems.first else { return nil }

        if let formatted = mapItem.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true),
           !formatted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return formatted
        }

        let fallbackParts = [
            mapItem.name,
            mapItem.addressRepresentations?.cityWithContext,
            mapItem.addressRepresentations?.regionName
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return fallbackParts.isEmpty ? nil : fallbackParts.joined(separator: ", ")
        #else
        return nil
        #endif
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
            if let continuation = self.authorizationContinuation,
               manager.authorizationStatus != .notDetermined {
                self.authorizationContinuation = nil
                continuation.resume(returning: manager.authorizationStatus)
            }
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
            self.isUpdatingLocation = false
            Logger(subsystem: "a-do", category: "Location").info("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude) (accuracy: \(location.horizontalAccuracy)m)")
            if let continuation = self.locationContinuation {
                self.locationContinuation = nil
                continuation.resume(returning: location)
            }
            
            // Reverse geocode to get address
            self.reverseGeocode(location: location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            let errorMsg = "Location update failed: \(String(describing: error))"
            Logger(subsystem: "a-do", category: "Location").error("\(errorMsg)")
            self.lastLocationError = errorMsg
            self.isUpdatingLocation = false
            if let continuation = self.locationContinuation {
                self.locationContinuation = nil
                continuation.resume(returning: nil)
            }
        }
    }
    
    deinit {
        // Clean up resources synchronously to avoid deinit issues
        // Note: We can't call async methods in deinit, so we'll just clean up what we can
        geocodingTask?.cancel()
        geocodingTask = nil
        authorizationContinuation?.resume(returning: manager.authorizationStatus)
        authorizationContinuation = nil
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil

        // Stop monitoring all regions
        // Create a copy of the set to avoid mutating while iterating
        let regionsToStop = Array(manager.monitoredRegions)
        for region in regionsToStop {
            manager.stopMonitoring(for: region)
        }
    }

    private func requestSingleLocation(timeoutNanoseconds: UInt64) async -> CLLocation? {
        await withTaskGroup(of: CLLocation?.self) { group in
            group.addTask { @MainActor in
                await withCheckedContinuation { continuation in
                    self.locationContinuation?.resume(returning: self.currentLocation)
                    self.locationContinuation = continuation
                    self.isUpdatingLocation = true
                    self.lastLocationError = nil
                    self.manager.requestLocation()
                }
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                return nil
            }

            let location = await group.next() ?? nil
            group.cancelAll()

            if location == nil {
                await MainActor.run {
                    self.isUpdatingLocation = false
                    self.lastLocationError = "Failed to get location after \(timeoutNanoseconds / 1_000_000_000) seconds"
                    Logger(subsystem: "a-do", category: "Location").error("\(self.lastLocationError ?? "Location request timed out")")
                    if let continuation = self.locationContinuation {
                        self.locationContinuation = nil
                        continuation.resume(returning: nil)
                    }
                }
            }

            return location
        }
    }
}
