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
                // Initialize the cleanup manager
                _ = ReminderCleanupManager.shared
            }
    }
}

#Preview {
    ContentView()
}
