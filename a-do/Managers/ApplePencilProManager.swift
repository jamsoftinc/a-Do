//
//  ApplePencilProManager.swift
//  a-do
//
//  Apple Pencil Pro support with squeeze gestures and drawing
//

import Foundation
import PencilKit
import SwiftData
import Observation
import UIKit
import os

@MainActor
@Observable
final class ApplePencilProManager {
    static let shared = ApplePencilProManager()

    private let logger = Logger(subsystem: "a-do", category: "ApplePencilPro")

    // Pro feature check
    var isProEnabled: Bool {
        return EntitlementManager.shared.isProUser
    }

    // Pencil availability
    var isPencilAvailable: Bool = false
    var isPencilProAvailable: Bool = false
    var preferredPencilAction: PencilAction = .sketch

    // Current drawing state
    var currentDrawing: PKDrawing?
    var isDrawing: Bool = false

    // Squeeze gesture settings
    var squeezeGestureEnabled: Bool = true
    var squeezeAction: SqueezeAction = .quickNote

    private init() {
        checkPencilAvailability()
    }

    // MARK: - Pencil Detection

    func checkPencilAvailability() {
        #if targetEnvironment(macCatalyst)
        isPencilAvailable = false
        isPencilProAvailable = false
        #else
        // Check if device supports Apple Pencil
        isPencilAvailable = UIDevice.current.userInterfaceIdiom == .pad

        // Apple Pencil Pro is available on iPad Pro M4 and later
        // For now, we'll check if PencilKit supports hover
        if #available(iOS 17.5, *) {
            isPencilProAvailable = isPencilAvailable
        } else {
            isPencilProAvailable = false
        }
        #endif

        logger.info("Pencil availability - Standard: \(self.isPencilAvailable), Pro: \(self.isPencilProAvailable)")
    }

    // MARK: - Drawing Management

    func createNewDrawing() -> PKDrawing {
        guard isProEnabled else {
            logger.warning("Apple Pencil Pro is a Pro feature")
            return PKDrawing()
        }

        let drawing = PKDrawing()
        currentDrawing = drawing
        isDrawing = true

        logger.info("Created new drawing")
        return drawing
    }

    func saveDrawing(_ drawing: PKDrawing, for reminder: Reminder, context: ModelContext) {
        guard isProEnabled else {
            logger.warning("Saving drawings is a Pro feature")
            return
        }

        do {
            // Convert drawing to data
            let drawingData = drawing.dataRepresentation()

            // Create a sketch attachment
            let sketch = Sketch(
                drawingData: drawingData,
                thumbnail: generateThumbnail(from: drawing),
                createdAt: Date()
            )

            context.insert(sketch)

            // Add to reminder's sketches
            if reminder.sketches == nil {
                reminder.sketches = []
            }
            reminder.sketches?.append(sketch)

            try context.save()

            currentDrawing = nil
            isDrawing = false

            logger.info("Saved drawing for reminder: \(reminder.title)")
        } catch {
            logger.error("Failed to save drawing: \(error.localizedDescription)")
        }
    }

    func loadDrawing(from sketch: Sketch) -> PKDrawing? {
        guard isProEnabled else {
            logger.warning("Loading drawings is a Pro feature")
            return nil
        }

        do {
            let drawing = try PKDrawing(data: sketch.drawingData)
            return drawing
        } catch {
            logger.error("Failed to load drawing: \(error.localizedDescription)")
            return nil
        }
    }

    private func generateThumbnail(from drawing: PKDrawing) -> Data? {
        let scale: CGFloat = 2.0
        let thumbnailRect = CGRect(x: 0, y: 0, width: 200, height: 200)
        let image = drawing.image(from: drawing.bounds, scale: scale)

        // Resize to thumbnail
        UIGraphicsBeginImageContextWithOptions(thumbnailRect.size, false, scale)
        image.draw(in: thumbnailRect)
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return thumbnail?.pngData()
    }

    // MARK: - Squeeze Gesture Handling

    func handleSqueezeGesture(in context: SqueezeContext) {
        guard isProEnabled else {
            logger.warning("Squeeze gestures are a Pro feature")
            return
        }

        guard squeezeGestureEnabled else {
            logger.info("Squeeze gestures are disabled")
            return
        }

        logger.info("Handling squeeze gesture with action: \(self.squeezeAction.rawValue)")

        switch squeezeAction {
        case .quickNote:
            context.triggerQuickNote()
        case .newReminder:
            context.createNewReminder()
        case .sketch:
            context.openSketchPad()
        case .colorPicker:
            context.showColorPicker()
        case .toolPicker:
            context.showToolPicker()
        }
    }

    // MARK: - Tool Preferences

    func getDefaultToolConfiguration() -> PKToolPicker {
        let toolPicker = PKToolPicker()
        toolPicker.showsDrawingPolicyControls = true
        return toolPicker
    }

    func createInkingTool(color: UIColor, width: CGFloat) -> PKInkingTool {
        return PKInkingTool(.pen, color: color, width: width)
    }

    // MARK: - Export

    func exportDrawingAsImage(_ drawing: PKDrawing) -> UIImage? {
        guard isProEnabled else {
            logger.warning("Exporting drawings is a Pro feature")
            return nil
        }

        let scale: CGFloat = UIScreen.main.scale
        return drawing.image(from: drawing.bounds, scale: scale)
    }

    func exportDrawingAsPDF(_ drawing: PKDrawing) -> Data? {
        guard isProEnabled else {
            logger.warning("Exporting drawings is a Pro feature")
            return nil
        }

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: drawing.bounds)
        let pdfData = pdfRenderer.pdfData { context in
            context.beginPage()
            drawing.image(from: drawing.bounds, scale: 2.0).draw(in: drawing.bounds)
        }

        return pdfData
    }
}

// MARK: - Supporting Types

enum PencilAction: String, CaseIterable {
    case sketch = "sketch"
    case annotate = "annotate"
    case signature = "signature"
    case none = "none"

    var displayName: String {
        switch self {
        case .sketch: return "Sketch"
        case .annotate: return "Annotate"
        case .signature: return "Add Signature"
        case .none: return "None"
        }
    }
}

enum SqueezeAction: String, CaseIterable {
    case quickNote = "quick_note"
    case newReminder = "new_reminder"
    case sketch = "sketch"
    case colorPicker = "color_picker"
    case toolPicker = "tool_picker"

    var displayName: String {
        switch self {
        case .quickNote: return "Quick Note"
        case .newReminder: return "New Reminder"
        case .sketch: return "Open Sketch Pad"
        case .colorPicker: return "Show Color Picker"
        case .toolPicker: return "Show Tool Picker"
        }
    }

    var icon: String {
        switch self {
        case .quickNote: return "note.text"
        case .newReminder: return "plus.circle"
        case .sketch: return "scribble"
        case .colorPicker: return "paintpalette"
        case .toolPicker: return "pencil.and.ruler"
        }
    }
}

struct SqueezeContext {
    let triggerQuickNote: () -> Void
    let createNewReminder: () -> Void
    let openSketchPad: () -> Void
    let showColorPicker: () -> Void
    let showToolPicker: () -> Void
}

// MARK: - Sketch Model

@Model
final class Sketch {
    var id: UUID = UUID()
    var drawingData: Data
    var thumbnail: Data?
    var createdAt: Date
    var modifiedAt: Date?

    init(drawingData: Data, thumbnail: Data?, createdAt: Date) {
        self.drawingData = drawingData
        self.thumbnail = thumbnail
        self.createdAt = createdAt
    }
}
