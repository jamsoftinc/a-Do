//
//  ProBadge.swift
//  a-do
//
//  Pro badge component for feature gating
//

import SwiftUI

struct ProBadge: View {
    let showIcon: Bool

    init(showIcon: Bool = false) {
        self.showIcon = showIcon
    }

    var body: some View {
        HStack(spacing: 3) {
            if showIcon {
                Image(systemName: "lock.fill")
                    .font(.system(size: 8, weight: .bold))
            }
            Text("PRO")
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.accentColor, in: Capsule())
    }
}

struct ProFeaturesAvailableBadge: View {
    var body: some View {
        Text("PRO")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.accentColor, in: Capsule())
    }
}

struct ProFeatureLock: View {
    let featureName: String
    let description: String
    let onUnlock: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(featureName, systemImage: "lock.fill")
        } description: {
            Text(description)
        } actions: {
            Button("Upgrade to Pro", action: onUnlock)
                .buttonStyle(.borderedProminent)
        }
    }
}

#Preview("Pro Badge") {
    VStack(spacing: 20) {
        ProBadge()
        ProBadge(showIcon: true)
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
}
