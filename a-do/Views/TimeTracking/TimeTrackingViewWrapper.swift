//
//  TimeTrackingViewWrapper.swift
//  a-do
//
//  Wrapper for Time Tracking View
//

import SwiftUI

struct TimeTrackingViewWrapper: View {
    var body: some View {
        TimeTrackingView()
    }
}

#Preview {
    NavigationStack {
        TimeTrackingViewWrapper()
    }
}
