import LocalAuthentication
import Foundation
import SwiftUI
import Combine

class BiometricAuthManager: ObservableObject {
    static let shared = BiometricAuthManager()
    
    @Published var isUnlocked: Bool = false
    
    func authenticateUser(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        
        // check whether authentication is possible (biometric or passcode)
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            
            do {
                // validation
                 let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthentication, // Allows fallback to device passcode
                    localizedReason: reason
                 )
                await MainActor.run {
                    self.isUnlocked = success
                }
                return success
            } catch {
                print("Biometric auth failed: \(error.localizedDescription)")
                return false
            }
        } else {
            // no biometrics
            print("Biometrics not available")
            return false // Strict security: If auth is unavailable, deny access.
        }
    }
}
