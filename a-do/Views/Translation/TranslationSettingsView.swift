//
//  TranslationSettingsView.swift
//  a-do
//
//  Translation settings and language preferences
//

import SwiftUI
import SwiftData

struct TranslationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var translationManager = TranslationManager.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Auto-Translate", isOn: $translationManager.autoTranslateEnabled)

                    NavigationLink {
                        LanguagePickerView(selectedLanguage: $translationManager.preferredLanguage)
                    } label: {
                        HStack {
                            Text("Preferred Language")
                            Spacer()
                            Text(translationManager.preferredLanguage.flag)
                            Text(translationManager.preferredLanguage.displayName)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Translation")
                } footer: {
                    Text("Automatically translate content to your preferred language when viewing shared reminders from other users.")
                }

                Section {
                    Toggle("Translate Shared Reminders", isOn: $translationManager.translateSharedReminders)
                    Toggle("Translate Comments", isOn: $translationManager.translateComments)
                } header: {
                    Text("Collaboration")
                } footer: {
                    Text("Enable translation for collaboration features to communicate with team members in different languages.")
                }

                Section {
                    Button {
                        translationManager.clearExpiredCache()
                    } label: {
                        Label("Clear Expired Cache", systemImage: "clock.badge.xmark")
                    }

                    Button(role: .destructive) {
                        translationManager.clearCache()
                    } label: {
                        Label("Clear All Cache", systemImage: "trash")
                    }
                } header: {
                    Text("Cache Management")
                } footer: {
                    Text("Translation cache improves performance by storing recent translations. Cache entries expire after 1 hour.")
                }

                Section {
                    NavigationLink {
                        SupportedLanguagesView()
                    } label: {
                        Label("Supported Languages", systemImage: "globe")
                    }
                } header: {
                    Text("Information")
                }
            }
            .navigationTitle("Translation Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        translationManager.savePreferences()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Language Picker

struct LanguagePickerView: View {
    @Binding var selectedLanguage: SupportedLanguage

    var body: some View {
        List(SupportedLanguage.allCases, id: \.self) { language in
            Button {
                selectedLanguage = language
            } label: {
                HStack {
                    Text(language.flag)
                        .font(.title2)

                    Text(language.displayName)
                        .foregroundStyle(.primary)

                    Spacer()

                    if language == selectedLanguage {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .navigationTitle("Select Language")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Supported Languages

struct SupportedLanguagesView: View {
    private let languages = SupportedLanguage.allCases

    var body: some View {
        List(languages, id: \.self) { language in
            HStack {
                Text(language.flag)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(language.displayName)
                        .font(.body)

                    Text(language.code.uppercased())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Supported Languages")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Translate Reminder View

struct TranslateReminderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let reminder: Reminder

    @State private var translationManager = TranslationManager.shared
    @State private var selectedLanguage: SupportedLanguage = .english
    @State private var isTranslating = false
    @State private var showingSuccess = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Original Title")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(reminder.title)
                            .font(.body)
                    }

                    if let details = reminder.details {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Original Details")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(details)
                                .font(.body)
                        }
                    }
                } header: {
                    Text("Source Content")
                }

                Section {
                    Picker("Target Language", selection: $selectedLanguage) {
                        ForEach(SupportedLanguage.allCases, id: \.self) { language in
                            HStack {
                                Text(language.flag)
                                Text(language.displayName)
                            }
                            .tag(language)
                        }
                    }
                } header: {
                    Text("Translation")
                } footer: {
                    Text("A translated copy of this reminder will be created in the selected language.")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        translateReminder()
                    } label: {
                        if isTranslating {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Translating...")
                                Spacer()
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text("Create Translation")
                                Spacer()
                            }
                        }
                    }
                    .disabled(isTranslating)
                }
            }
            .navigationTitle("Translate Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Translation Created", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("A translated copy of this reminder has been created in \(selectedLanguage.displayName).")
            }
        }
    }

    private func translateReminder() {
        isTranslating = true
        errorMessage = nil

        Task {
            if #available(iOS 17.4, *) {
                if let _ = await translationManager.translateReminder(
                    reminder,
                    to: selectedLanguage,
                    context: modelContext
                ) {
                    await MainActor.run {
                        isTranslating = false
                        showingSuccess = true
                    }
                } else {
                    await MainActor.run {
                        isTranslating = false
                        errorMessage = "Translation failed. Please try again."
                    }
                }
            } else {
                await MainActor.run {
                    isTranslating = false
                    errorMessage = "Translation requires iOS 17.4 or later."
                }
            }
        }
    }
}

// MARK: - Translation Feature Card

struct TranslationFeatureCard: View {
    @State private var translationManager = TranslationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "globe")
                    .font(.title2)
                    .foregroundStyle(.blue)

                Text("Translation")
                    .font(.headline)

                Spacer()

                if translationManager.autoTranslateEnabled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            Text("Communicate with team members in \(SupportedLanguage.allCases.count) languages with automatic translation.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Text(translationManager.preferredLanguage.flag)
                Text(translationManager.preferredLanguage.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Pro Feature Wrapper

struct TranslationSettingsViewWrapper: View {
    @State private var entitlementManager = EntitlementManager.shared
    @State private var showPaywall = false

    var body: some View {
        if entitlementManager.isProUser {
            TranslationSettingsView()
        } else {
            ProUpgradePromptView(
                feature: .translation,
                title: "Translation",
                description: "Break language barriers with automatic translation in \(SupportedLanguage.allCases.count) languages. Perfect for international teams and multilingual collaboration.",
                icon: "globe"
            ) {
                showPaywall = true
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
}

#Preview {
    TranslationSettingsView()
}
