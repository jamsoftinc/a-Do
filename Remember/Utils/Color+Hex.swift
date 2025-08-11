import SwiftUI

extension Color {
    init?(hex: String, alpha: Double = 1.0) {
        var formatted = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if formatted.count == 3 {
            let chars = Array(formatted)
            formatted = String([chars[0], chars[0], chars[1], chars[1], chars[2], chars[2]])
        }
        guard formatted.count == 6, let intCode = Int(formatted, radix: 16) else { return nil }
        let red = Double((intCode >> 16) & 0xFF) / 255.0
        let green = Double((intCode >> 8) & 0xFF) / 255.0
        let blue = Double(intCode & 0xFF) / 255.0
        self = Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}


