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
        // Initialize app group defaults early to prevent CFPrefsPlistSource errors
        _ = AppGroupDefaults.shared
        
        // Configure global navigation bar appearance
        configureGlobalAppearance()
        
        // Initialize location manager
        _ = LocationManager.shared
    }
    
    private func configureGlobalAppearance() {
        // Navigation bar appearance
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
        
        // Toolbar appearance
        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithOpaqueBackground()
        toolbarAppearance.backgroundColor = UIColor(AppTheme.Colors.surface)
        UIToolbar.appearance().standardAppearance = toolbarAppearance
        UIToolbar.appearance().compactAppearance = toolbarAppearance
        UIToolbar.appearance().tintColor = UIColor.white
        
        // Tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(AppTheme.Colors.surface)
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().tintColor = UIColor.white
        UITabBar.appearance().unselectedItemTintColor = UIColor(AppTheme.Colors.textTertiary)
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @State private var router = AppRouter()
    @State private var container: ModelContainer?
    
    var body: some View {
        LaunchScreenWrapper {
            if let container = container {
                ContentView()
                    .modelContainer(container)
                    .environment(router)
                    .onOpenURL { url in router.handle(url: url) }
                    .task { router.checkGroupDeeplinkFlag() }
            } else {
                // Show loading state while container initializes
                ProgressView("Loading...")
                    .task {
                        // Initialize container on background thread
                        container = AppContainer.shared.getContainer()
                    }
            }
        }
    }
}

