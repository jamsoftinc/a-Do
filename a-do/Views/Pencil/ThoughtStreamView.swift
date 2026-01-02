//
//  ThoughtStreamView.swift
//  a-do
//
//  Created for iOS 26+ Thought Stream Feature
//

import SwiftUI
import PencilKit
import SwiftData

struct ThoughtStreamView: View {
    @Binding var isActive: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var canvasView = PKCanvasView()
    @State private var recognizedText = ""
    @State private var isProcessing = false
    
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
        
        // 1. Handwriting Recognition (Simulated for brevity, normally uses PKDrawing.image + Vision)
        // In a real app, we'd export image and run VNRecognizeTextRequest
        let simulatedText = "Buy milk tomorrow at 5pm" 
        
        // 2. Mock AI Classification
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Create Reminder based on text
            let reminder = Reminder(
                title: simulatedText,
                dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())
            )
            modelContext.insert(reminder)
            
            await MainActor.run {
                isProcessing = false
                isActive = false
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
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
