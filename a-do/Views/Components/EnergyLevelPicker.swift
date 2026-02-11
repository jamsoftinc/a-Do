import SwiftUI

struct EnergyLevelPicker: View {
    @Binding var selection: EnergyLevel
    
    var body: some View {
        HStack {
            Text("Energy")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Picker("Energy Level", selection: $selection) {
                ForEach(EnergyLevel.allCases) { level in
                    HStack {
                        Image(systemName: level.icon)
                            .foregroundColor(Color(hex: level.color) ?? .secondary)
                        Text(level.title)
                    }
                    .tag(level)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}
