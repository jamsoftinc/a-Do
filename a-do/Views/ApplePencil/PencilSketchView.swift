//
//  PencilSketchView.swift
//  a-do
//
//  Apple Pencil Pro sketch view with drawing canvas and tool picker
//

import SwiftUI
import PencilKit
import SwiftData

struct PencilSketchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let reminder: Reminder

    @State private var pencilManager = ApplePencilProManager.shared
    @State private var canvas = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    @State private var drawing = PKDrawing()

    var body: some View {
        NavigationStack {
            ZStack {
                // Canvas
                PencilCanvasView(
                    canvasView: $canvas,
                    drawing: $drawing,
                    toolPicker: toolPicker
                )
                .navigationTitle("Sketch")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            pencilManager.saveDrawing(drawing, for: reminder, context: modelContext)
                            dismiss()
                        }
                        .disabled(drawing.bounds.isEmpty)
                    }

                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            drawing = PKDrawing()
                        } label: {
                            Label("Clear", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Canvas View

struct PencilCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var drawing: PKDrawing
    let toolPicker: PKToolPicker

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawing = drawing
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .systemBackground

        // Show tool picker
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()

        // Set delegate
        canvasView.delegate = context.coordinator

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.drawing = drawing
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilCanvasView

        init(_ parent: PencilCanvasView) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}

// MARK: - Sketch Gallery View

struct SketchGalleryView: View {
    let reminder: Reminder
    @State private var selectedSketch: Sketch?
    @State private var showingSketchDetail = false

    var body: some View {
        Group {
            if let sketches = reminder.sketches, !sketches.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(sketches, id: \.id) { sketch in
                            SketchThumbnailView(sketch: sketch)
                                .onTapGesture {
                                    selectedSketch = sketch
                                    showingSketchDetail = true
                                }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 120)
            } else {
                Text("No sketches yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .sheet(isPresented: $showingSketchDetail) {
            if let sketch = selectedSketch {
                SketchDetailView(sketch: sketch)
            }
        }
    }
}

// MARK: - Sketch Thumbnail

struct SketchThumbnailView: View {
    let sketch: Sketch

    var body: some View {
        ZStack {
            if let thumbnailData = sketch.thumbnail,
               let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .overlay {
                        Image(systemName: "scribble")
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }
}

// MARK: - Sketch Detail View

struct SketchDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let sketch: Sketch
    @State private var pencilManager = ApplePencilProManager.shared
    @State private var showingShareSheet = false
    @State private var exportImage: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                if let drawing = pencilManager.loadDrawing(from: sketch) {
                    SketchImageView(drawing: drawing)
                        .navigationTitle("Sketch")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    dismiss()
                                }
                            }

                            ToolbarItem(placement: .primaryAction) {
                                Menu {
                                    Button {
                                        exportAsImage(drawing)
                                    } label: {
                                        Label("Export as Image", systemImage: "photo")
                                    }

                                    Button {
                                        exportAsPDF(drawing)
                                    } label: {
                                        Label("Export as PDF", systemImage: "doc.fill")
                                    }

                                    Divider()

                                    Button(role: .destructive) {
                                        deleteSketch()
                                    } label: {
                                        Label("Delete Sketch", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                }
                            }
                        }
                } else {
                    ContentUnavailableView(
                        "Cannot Load Sketch",
                        systemImage: "exclamationmark.triangle",
                        description: Text("This sketch could not be loaded.")
                    )
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let image = exportImage {
                ShareSheet(items: [image])
            }
        }
    }

    private func exportAsImage(_ drawing: PKDrawing) {
        if let image = pencilManager.exportDrawingAsImage(drawing) {
            exportImage = image
            showingShareSheet = true
        }
    }

    private func exportAsPDF(_ drawing: PKDrawing) {
        if let pdfData = pencilManager.exportDrawingAsPDF(drawing) {
            // Save to temporary file and share
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("sketch.pdf")
            do {
                try pdfData.write(to: tempURL)
                showingShareSheet = true
            } catch {
                print("Failed to save PDF: \(error)")
            }
        }
    }

    private func deleteSketch() {
        modelContext.delete(sketch)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Sketch Image View

struct SketchImageView: View {
    let drawing: PKDrawing

    var body: some View {
        GeometryReader { geometry in
            if let image = UIImage(data: drawing.dataRepresentation()) {
                Image(uiImage: drawing.image(from: drawing.bounds, scale: UIScreen.main.scale))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "No Drawing",
                    systemImage: "scribble",
                    description: Text("Start drawing with Apple Pencil")
                )
            }
        }
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Pro Feature Wrapper

struct PencilSketchViewWrapper: View {
    let reminder: Reminder

    @State private var entitlementManager = EntitlementManager.shared
    @State private var showPaywall = false

    var body: some View {
        if entitlementManager.isProUser {
            PencilSketchView(reminder: reminder)
        } else {
            ProUpgradePromptView(
                feature: .applePencilPro,
                title: "Apple Pencil Pro",
                description: "Create sketches and drawings attached to your reminders with full Apple Pencil Pro support including squeeze gestures and advanced tools.",
                icon: "pencil.tip.crop.circle"
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
    PencilSketchView(reminder: Reminder(title: "Test"))
        .modelContainer(for: [Reminder.self, Sketch.self])
}
