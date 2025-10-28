//
//  ProBadge.swift
//  a-do
//
//  Pro badge component for feature gating
//

import SwiftUI

struct ProBadge: View {
    let showIcon: Bool
    
    init(showIcon: Bool = true) {
        self.showIcon = showIcon
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if showIcon {
                Image(systemName: "crown.fill")
                    .font(.caption2)
            }
            Text("PRO")
                .font(.system(size: 9, weight: .bold, design: .rounded))
        }
        .foregroundColor(.yellow)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.yellow.opacity(0.2), .orange.opacity(0.2)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.yellow.opacity(0.4), lineWidth: 0.5)
                )
        )
    }
}

struct ProFeaturesAvailableBadge: View {
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "crown.fill")
                .font(.system(size: 8, weight: .bold))
            Text("PRO")
                .font(.system(size: 7, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.purple, .purple.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                )
        )
        .shadow(color: .purple.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}

struct ProFeatureLock: View {
    let featureName: String
    let description: String
    let onUnlock: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.title)
                .foregroundColor(.secondary)
            
            Text(featureName)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onUnlock) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                    Text("Upgrade to Pro")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
            }
        }
        .padding(24)
        .frame(maxWidth: 280)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview("Pro Badge") {
    VStack(spacing: 20) {
        ProBadge()
        ProBadge(showIcon: false)
    }
    .padding()
}

#Preview("Pro Lock") {
    ProFeatureLock(
        featureName: "Advanced AI",
        description: "Get smarter suggestions with Apple Intelligence"
    ) {
        print("Unlock tapped")
    }
    .padding()
    .background(AppTheme.Gradients.background)
}
