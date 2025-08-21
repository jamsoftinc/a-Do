//
//  ADoApp.swift
//  a-do
//
//  Created by Ahmad Hamilton on 8/10/25.
//

import SwiftUI
import SwiftData

@main
struct ADoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @State private var router = AppRouter()
    
    var body: some View {
        LaunchScreenWrapper {
            ContentView()
                .modelContainer(for: [
                    Reminder.self,
                    Tag.self,
                    ReminderList.self,
                    ReminderNotification.self,
                    LocationTrigger.self,
                    ListSection.self,
                    TaggedContact.self,
                    AppleNoteAttachment.self
                ])
                .environment(router)
                .onOpenURL { url in router.handle(url: url) }
                .task { router.checkGroupDeeplinkFlag() }
        }
    }
}

