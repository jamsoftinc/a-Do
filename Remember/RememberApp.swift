//
//  RememberApp.swift
//  Remember
//
//  Created by Ahmad Hamilton on 8/10/25.
//

import SwiftUI
import SwiftData

@main
struct RememberApp: App {
    var sharedModelContainer: ModelContainer = AppContainer.container
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedModelContainer)
                .environment(router)
                .onOpenURL { url in router.handle(url: url) }
                .task { router.checkGroupDeeplinkFlag() }
        }
    }
}
