import SwiftUI
import CoreLocation

struct LocationStatusView: View {
    let locationManager = LocationManager.shared
    
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
                }
            }
            
            Spacer()
            
            if locationManager.isUpdatingLocation {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
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
}

#Preview {
    LocationStatusView()
        .padding()
}
