//
//  WritingToolsModifier.swift
//  a-do
//
//  SwiftUI view modifiers for Apple Intelligence Writing Tools integration
//  Writing Tools are automatically available in TextField/TextEditor
//
//  Requires: iOS 26+
//

import SwiftUI
import FoundationModels

// MARK: - Writing Tools Behavior Configuration

/// Configuration for Writing Tools behavior in text views
enum WritingToolsMode: String, CaseIterable {
    case automatic  // Full Writing Tools support
    case limited    // Limited support (basic proofreading only)
    case disabled   // Disable Writing Tools

    var displayName: String {
        switch self {
        case .automatic: return "Full Support"
        case .limited: return "Limited"
        case .disabled: return "Disabled"
        }
    }

    var description: String {
        switch self {
        case .automatic: return "All Writing Tools features available"
        case .limited: return "Only basic proofreading available"
        case .disabled: return "Writing Tools disabled for this field"
        }
    }
}

// MARK: - Writing Tools View Modifier

/// View modifier to configure Writing Tools behavior for text views
struct WritingToolsViewModifier: ViewModifier {
    let mode: WritingToolsMode
    @State private var isProUser = EntitlementManager.shared.isProUser

    func body(content: Content) -> some View {
        content
            .writingToolsBehavior(writingToolsBehavior)
    }

    private var writingToolsBehavior: WritingToolsBehavior {
        // Require Pro for full Writing Tools access
        guard isProUser else {
            return .limited
        }

        switch mode {
        case .automatic:
            return .automatic
        case .limited:
            return .limited
        case .disabled:
            return .disabled
        }
    }
}

// MARK: - View Extension

extension View {
    /// Configure Writing Tools behavior for text input views
    ///
    /// Usage:
    /// ```swift
    /// TextField("Title", text: $title)
    ///     .intelligentWritingTools(.automatic)
    /// ```
    func intelligentWritingTools(_ mode: WritingToolsMode = .automatic) -> some View {
        modifier(WritingToolsViewModifier(mode: mode))
    }
}

// MARK: - Enhanced Text Editor with Writing Tools

/// A TextEditor enhanced with Writing Tools and AI features
struct IntelligentTextEditor: View {
    @Binding var text: String
    let placeholder: String
    let writingToolsMode: WritingToolsMode

    @State private var showAIAssist = false
    @State private var isProUser = EntitlementManager.shared.isProUser

    init(
        text: Binding<String>,
        placeholder: String = "Enter text...",
        writingTools: WritingToolsMode = .automatic
    ) {
        self._text = text
        self.placeholder = placeholder
        self.writingToolsMode = writingTools
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }

            // Text editor with Writing Tools
            TextEditor(text: $text)
                .intelligentWritingTools(writingToolsMode)
                .scrollContentBackground(.hidden)
        }
        .overlay(alignment: .topTrailing) {
            // AI assist button (Pro feature)
            if isProUser && AppleIntelligenceManager.shared.isAppleIntelligenceAvailable {
                Button {
                    showAIAssist = true
                } label: {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showAIAssist) {
            AITextAssistView(text: $text)
        }
    }
}

// MARK: - Enhanced Text Field with Writing Tools

/// A TextField enhanced with Writing Tools support
struct IntelligentTextField: View {
    @Binding var text: String
    let title: String
    let prompt: String?
    let writingToolsMode: WritingToolsMode

    init(
        _ title: String,
        text: Binding<String>,
        prompt: String? = nil,
        writingTools: WritingToolsMode = .automatic
    ) {
        self.title = title
        self._text = text
        self.prompt = prompt
        self.writingToolsMode = writingTools
    }

    var body: some View {
        TextField(title, text: $text, prompt: prompt.map { Text($0) })
            .intelligentWritingTools(writingToolsMode)
    }
}

// MARK: - AI Text Assist Sheet

/// Sheet view for AI-powered text assistance
struct AITextAssistView: View {
    @Binding var text: String
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAction: AITextAction = .improve
    @State private var isProcessing = false
    @State private var result: String = ""
    @State private var error: String?

    enum AITextAction: String, CaseIterable {
        case improve = "Improve"
        case shorten = "Make Shorter"
        case expand = "Make Longer"
        case professional = "More Professional"
        case casual = "More Casual"
        case summarize = "Summarize"

        var prompt: String {
            switch self {
            case .improve: return "Improve this text while keeping the meaning"
            case .shorten: return "Make this text shorter and more concise"
            case .expand: return "Expand this text with more details"
            case .professional: return "Rewrite this text in a more professional tone"
            case .casual: return "Rewrite this text in a more casual, friendly tone"
            case .summarize: return "Summarize the key points of this text"
            }
        }

        var icon: String {
            switch self {
            case .improve: return "sparkles"
            case .shorten: return "arrow.down.right.and.arrow.up.left"
            case .expand: return "arrow.up.left.and.arrow.down.right"
            case .professional: return "briefcase"
            case .casual: return "face.smiling"
            case .summarize: return "text.alignleft"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Original text preview
                GroupBox("Original") {
                    Text(text)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }

                // Action picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(AITextAction.allCases, id: \.rawValue) { action in
                            Button {
                                selectedAction = action
                                processText()
                            } label: {
                                Label(action.rawValue, systemImage: action.icon)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedAction == action
                                            ? Color.accentColor.opacity(0.2)
                                            : Color.secondary.opacity(0.1)
                                    )
                                    .foregroundStyle(selectedAction == action ? .primary : .secondary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                // Result
                if isProcessing {
                    ProgressView("Processing...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !result.isEmpty {
                    GroupBox("Result") {
                        Text(result)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    }

                    Button {
                        text = result
                        dismiss()
                    } label: {
                        Label("Use This Version", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else if let error = error {
                    ContentUnavailableView(
                        "Error",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                }

                Spacer()
            }
            .padding()
            .navigationTitle("AI Text Assist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if result.isEmpty {
                processText()
            }
        }
    }

    private func processText() {
        guard !text.isEmpty else { return }

        isProcessing = true
        error = nil

        Task {
            // Use Foundation Models if available
            if FoundationModelsManager.shared.canUseAI {
                let prompt = "\(selectedAction.prompt):\n\n\(text)"

                if let response = await FoundationModelsManager.shared.continueConversation(prompt) {
                    await MainActor.run {
                        result = response
                        isProcessing = false
                    }
                    return
                }
            }

            // Fallback: basic transformations
            await MainActor.run {
                result = performBasicTransform(text, action: selectedAction)
                isProcessing = false
            }
        }
    }

    private func performBasicTransform(_ input: String, action: AITextAction) -> String {
        switch action {
        case .improve:
            return input.trimmingCharacters(in: .whitespacesAndNewlines)
        case .shorten:
            let sentences = input.components(separatedBy: ". ")
            return sentences.prefix(sentences.count / 2 + 1).joined(separator: ". ")
        case .expand:
            return input // Can't expand without AI
        case .professional:
            return input
                .replacingOccurrences(of: "!", with: ".")
                .replacingOccurrences(of: "gonna", with: "going to")
                .replacingOccurrences(of: "wanna", with: "want to")
        case .casual:
            return input
        case .summarize:
            let sentences = input.components(separatedBy: ". ")
            if sentences.count > 2 {
                return sentences.prefix(2).joined(separator: ". ") + "."
            }
            return input
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var text = "This is some sample text to demonstrate the Writing Tools integration."

        var body: some View {
            Form {
                Section("Text Editor") {
                    IntelligentTextEditor(
                        text: $text,
                        placeholder: "Enter your notes...",
                        writingTools: .automatic
                    )
                    .frame(height: 100)
                }

                Section("Text Field") {
                    IntelligentTextField(
                        "Title",
                        text: $text,
                        writingTools: .automatic
                    )
                }
            }
        }
    }

    return PreviewWrapper()
}
