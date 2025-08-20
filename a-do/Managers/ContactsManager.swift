import Foundation
import Contacts
import UIKit

@MainActor
final class ContactsManager {
    static let shared = ContactsManager()
    private let store = CNContactStore()

    private init() {}

    func requestAccess() async -> Bool {
        do {
            return try await store.requestAccess(for: .contacts)
        } catch {
            return false
        }
    }

    func searchContacts(matching query: String) async -> [CNContact] {
        let keys: [CNKeyDescriptor] = [CNContactGivenNameKey as CNKeyDescriptor, CNContactFamilyNameKey as CNKeyDescriptor, CNContactPhoneNumbersKey as CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        var results: [CNContact] = []
        do {
            try store.enumerateContacts(with: request) { contact, _ in
                let full = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                if full.localizedCaseInsensitiveContains(query) || contact.phoneNumbers.contains(where: { $0.value.stringValue.contains(query) }) {
                    results.append(contact)
                }
            }
        } catch {}
        return results
    }

    func myDisplayName() async -> String {
        // Fallback to device name; using CNContactStore unifiedMeContact isn't available across all environments
        return UIDevice.current.name
    }

    func myPhoneNumber() async -> String? {
        let defaults = UserDefaults(suiteName: "group.JAMSoft.Remember") ?? .standard
        return defaults.string(forKey: "my_phone_number")
    }

    func setMyPhoneNumber(_ number: String?) {
        let defaults = UserDefaults(suiteName: "group.JAMSoft.Remember") ?? .standard
        if let number, !number.isEmpty {
            defaults.set(number, forKey: "my_phone_number")
        } else {
            defaults.removeObject(forKey: "my_phone_number")
        }
    }
}


