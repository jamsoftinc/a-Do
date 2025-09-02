//
//  ContentView.swift
//  a-do
//
//  Created by Ahmad Hamilton on 8/10/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        HomeView()
            .task {
                // Safely initialize the cleanup manager
                ReminderCleanupManager.shared.setupPeriodicCleanup()
            }
    }
}

#Preview {
    ContentView()
}
