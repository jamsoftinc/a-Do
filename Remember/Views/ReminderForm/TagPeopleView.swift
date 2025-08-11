import SwiftUI
import Contacts
import SwiftData
import MessageUI
import UIKit

struct TagPeopleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var reminders: [Reminder]

    @State private var query: String = ""
    @State private var results: [CNContact] = []
    @State private var selectedContacts: [TaggedContact] = []
    @State private var myName: String = ""

    let reminderTitle: String

    var body: some View {
        List {
            Section {
                TextField("Search Contacts", text: $query)
                    .onChange(of: query) { _, newValue in
                        Task { await search(newValue) }
                    }
            }
            Section("Matches") {
                ForEach(results, id: \.identifier) { contact in
                    Button {
                        let phone = contact.phoneNumbers.first?.value.stringValue
                        let tagged = TaggedContact(identifier: contact.identifier, givenName: contact.givenName, familyName: contact.familyName, phoneNumber: phone)
                        if !selectedContacts.contains(where: { $0.identifier == tagged.identifier }) {
                            selectedContacts.append(tagged)
                        }
                    } label: {
                        HStack {
                            Text("\(contact.givenName) \(contact.familyName)")
                            Spacer()
                            if results.first?.identifier == contact.identifier { Image(systemName: "plus.circle") }
                        }
                    }
                }
            }
            Section("Selected") {
                ForEach(selectedContacts, id: \.identifier) { tc in
                    HStack {
                        Text("\(tc.givenName) \(tc.familyName)")
                        Spacer()
                        if let phone = tc.phoneNumber {
                            Button { sendMessage(to: phone) } label: { Image(systemName: "message.fill") }
                        }
                    }
                }
                .onDelete { indexSet in selectedContacts.remove(atOffsets: indexSet) }
            }
        }
        .navigationTitle("Tag People")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .task { 
            _ = await ContactsManager.shared.requestAccess()
            myName = await ContactsManager.shared.myDisplayName()
        }
    }

    private func search(_ term: String) async {
        guard !term.isEmpty else { results = []; return }
        results = await ContactsManager.shared.searchContacts(matching: term)
    }

    private func sendMessage(to phone: String) {
        let thing = messageBodyText()
        let text = "Remember to \(thing) thanks \(myName)"
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let sms = "sms:\(phone)&body=\(encoded)"
        if let url = URL(string: sms) {
            UIApplication.shared.open(url)
        }
    }

    private func messageBodyText() -> String {
        // Prefer the provided reminder title; fall back to search query, then a generic phrase
        if !reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return reminderTitle }
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return query }
        return "your task"
    }
}


