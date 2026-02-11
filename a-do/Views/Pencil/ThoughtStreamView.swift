//
//  ThoughtStreamView.swift
//  a-do
//
//  Created for iOS 26+ Thought Stream Feature
//

import SwiftUI
import PencilKit
import SwiftData
import Vision
import UIKit

struct ThoughtStreamView: View {
    @Binding var isActive: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var canvasView = PKCanvasView()
    @State private var recognizedText = ""
    @State private var isProcessing = false
    @State private var processingError: String?
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isActive = false
                }
            
            // Floating Glass Pane
            VStack(spacing: 20) {
                HStack {
                    Image(systemName: "pencil.and.scribble")
                        .foregroundStyle(.white)
                    Text("Thought Stream")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        isActive = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                
                // Canvas
                CanvasWrapper(canvasView: $canvasView)
                    .frame(height: 300)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal)
                
                // Actions
                if isProcessing {
                    ProgressView("Processing Thought...")
                        .tint(.white)
                } else {
                    Button(action: processThought) {
                        Text("Process")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal)
                }
                
                if !recognizedText.isEmpty {
                    Text("Recognized: \(recognizedText)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal)
                }
                
                if let processingError {
                    Text(processingError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
            }
            .padding(.bottom)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding()
            .shadow(radius: 20)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private func processThought() {
        isProcessing = true
        Task {
            defer {
                Task { @MainActor in
                    isProcessing = false
                }
            }
            
            guard let drawingImage = renderDrawingImage() else {
                await MainActor.run {
                    processingError = "Write something before processing."
                }
                return
            }
            
            let extractedText = await recognizeText(from: drawingImage)
            let cleanedText = extractedText
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !cleanedText.isEmpty else {
                await MainActor.run {
                    processingError = "Could not recognize handwriting. Try writing larger."
                }
                return
            }
            
            let requests = await AIManager.shared.buildCaptureRequests(from: cleanedText)
            guard !requests.isEmpty else {
                await MainActor.run {
                    processingError = "Could not parse recognized text into tasks."
                }
                return
            }

            var createdCount = 0
            for request in requests {
                do {
                    _ = try await ReminderCreationService.shared.createReminder(request: request, in: modelContext)
                    createdCount += 1
                } catch {
                    await MainActor.run {
                        processingError = "Failed to create reminder."
                    }
                }
            }

            if createdCount > 0 {
                await MainActor.run {
                    recognizedText = cleanedText
                    processingError = nil
                    canvasView.drawing = PKDrawing()
                    isActive = false

                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } else {
                await MainActor.run {
                    processingError = "Failed to create reminder."

                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }
    
    private func renderDrawingImage() -> UIImage? {
        let drawing = canvasView.drawing
        let bounds = drawing.bounds.insetBy(dx: -16, dy: -16)
        
        guard !bounds.isEmpty, bounds.width > 1, bounds.height > 1 else {
            return nil
        }
        
        return drawing.image(from: bounds, scale: UIScreen.main.scale)
    }
    
    private func recognizeText(from image: UIImage) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let cgImage = image.cgImage else {
                    continuation.resume(returning: "")
                    return
                }
                
                let request = VNRecognizeTextRequest { request, _ in
                    let observations = request.results as? [VNRecognizedTextObservation] ?? []
                    let recognized = observations
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: " ")
                    continuation.resume(returning: recognized)
                }
                
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["en-US"]
                
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }
}

struct CanvasWrapper: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.tool = PKInkingTool(.pen, color: .white, width: 10)
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
