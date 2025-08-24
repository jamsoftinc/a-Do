//
//  ADoApp.swift
//  a-do
//
//  Created by Ahmad Hamilton on 8/10/25.
//

import SwiftUI
import SwiftData
import UIKit

@main
struct ADoApp: App {
    init() {
        // Configure global navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppTheme.Colors.primary)
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor.white
        
        // Configure toolbar appearance
        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithOpaqueBackground()
        toolbarAppearance.backgroundColor = UIColor(AppTheme.Colors.surface)
        UIToolbar.appearance().standardAppearance = toolbarAppearance
        UIToolbar.appearance().compactAppearance = toolbarAppearance
        UIToolbar.appearance().tintColor = UIColor.white
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(AppTheme.Colors.surface)
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().tintColor = UIColor.white
        UITabBar.appearance().unselectedItemTintColor = UIColor(AppTheme.Colors.textTertiary)
        
        // Initialize location manager
        _ = LocationManager.shared
        print("📍 Location manager initialized")
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @State private var router = AppRouter()
    @State private var container: ModelContainer? = nil
    
    var body: some View {
        Group {
            if let container = container {
                LaunchScreenWrapper {
                    ContentView()
                        .modelContainer(container)
                        .environment(router)
                        .onOpenURL { url in router.handle(url: url) }
                        .task { router.checkGroupDeeplinkFlag() }
                }
            } else {
                ProgressView("Loading...")
                    .onAppear {
                        setupContainer()
                    }
            }
        }
    }
    
    private func setupContainer() {
        do {
            let schema = Schema([
                Reminder.self,
                Tag.self,
                ReminderList.self,
                ReminderNotification.self,
                LocationTrigger.self,
                ListSection.self,
                TaggedContact.self,
                AppleNoteAttachment.self,
                VoiceReminder.self
            ])
            
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            print("✅ Container created successfully")
            print("🔍 Container: \(container)")
            
            self.container = container
        } catch {
            print("❌ Failed to create container: \(error)")
        }
    }
}

// Removed createPersistentContainer - using simpler approach
/*
private func createPersistentContainer() -> ModelContainer {
        let schema = Schema([
            Reminder.self,
            Tag.self,
            ReminderList.self,
            ReminderNotification.self,
            LocationTrigger.self,
            ListSection.self,
            TaggedContact.self,
            AppleNoteAttachment.self
        ])
        
        #if DEBUG
        print("🔄 Creating SwiftData container...")
        #endif
        
        // Try different configurations in order of preference
        
        // 1. Try simple default configuration first
        do {
            let container = try ModelContainer(for: schema)
            #if DEBUG
            print("✅ Default SwiftData container created successfully")
            #endif
            return container
        } catch {
            #if DEBUG
            print("⚠️ Default container failed: \(error)")
            #endif
        }
        
        // 2. Try explicit persistent configuration
        do {
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            let container = try ModelContainer(for: schema, configurations: configuration)
            #if DEBUG
            print("✅ Explicit persistent SwiftData container created successfully")
            #endif
            return container
        } catch {
            #if DEBUG
            print("⚠️ Persistent container failed: \(error)")
            #endif
        }
        
        // 3. Fall back to in-memory
        do {
            let memoryConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
            let memoryContainer = try ModelContainer(for: schema, configurations: memoryConfiguration)
            #if DEBUG
            print("⚠️ Using in-memory container (data won't persist between app launches)")
            #endif
            return memoryContainer
        } catch {
            #if DEBUG
            print("❌ Even in-memory container failed: \(error)")
            #endif
        }
        
        // 4. Last resort - try the built-in SwiftUI approach
        #if DEBUG
        print("🔄 Trying built-in SwiftUI container as last resort...")
        #endif
        
        do {
            // This is what SwiftUI's .modelContainer(for:) does internally
            return try ModelContainer(for: Reminder.self, Tag.self, ReminderList.self, ReminderNotification.self, LocationTrigger.self, ListSection.self, TaggedContact.self, AppleNoteAttachment.self)
        } catch {
            #if DEBUG
            print("❌ All container creation methods failed: \(error)")
            #endif
            fatalError("Unable to create any SwiftData container. Please restart the app. Error: \(error)")
        }
    }
}
*/

