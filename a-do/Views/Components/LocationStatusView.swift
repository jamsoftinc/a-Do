import SwiftUI
import CoreLocation

struct LocationStatusView: View {
    let locationManager = LocationManager.shared
    @State private var showingLocationAlert = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: locationIcon)
                .foregroundColor(locationColor)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(locationStatusText)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let location = locationManager.currentLocation {
                    if let address = locationManager.currentAddress {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("\(location.coordinate.latitude, specifier: "%.4f"), \(location.coordinate.longitude, specifier: "%.4f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if locationManager.authorizationStatus == .notDetermined {
                    Text("Tap to enable location access")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                    Text("Tap to open Settings")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            if locationManager.isUpdatingLocation {
                ProgressView()
                    .scaleEffect(0.8)
            } else if locationManager.authorizationStatus == .notDetermined || locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                Image(systemName: "chevron.right")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .onTapGesture {
            handleLocationAccess()
        }
        .alert("Location Access", isPresented: $showingLocationAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Open Settings") {
                openAppSettings()
            }
        } message: {
            Text("Location access is required for location-based reminders. Please enable location access in Settings.")
        }
    }
    
    private var locationIcon: String {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return locationManager.currentLocation != nil ? "location.fill" : "location"
        case .denied, .restricted:
            return "location.slash"
        case .notDetermined:
            return "location.circle"
        @unknown default:
            return "location.circle"
        }
    }
    
    private var locationColor: Color {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return locationManager.currentLocation != nil ? .green : .blue
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }
    
    private var locationStatusText: String {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if locationManager.currentLocation != nil {
                return "Location Available"
            } else if locationManager.isUpdatingLocation {
                return "Detecting Location..."
            } else {
                return "Location Access Granted"
            }
        case .denied, .restricted:
            return "Location Access Denied"
        case .notDetermined:
            return "Location Access Required"
        @unknown default:
            return "Location Status Unknown"
        }
    }
    
    private func handleLocationAccess() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestAuthorization()
        case .denied, .restricted:
            showingLocationAlert = true
        case .authorizedWhenInUse, .authorizedAlways:
            // Start location updates if not already running
            if !locationManager.isUpdatingLocation {
                locationManager.startLocationUpdates()
            }
        @unknown default:
            break
        }
    }
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

#Preview {
    LocationStatusView()
        .padding()
}
