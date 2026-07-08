//
//  DataTrackerApp.swift
//  DataTracker
//
//  Created by Alex on 2025/11/13.
//

import SwiftUI
import CoreData

@main
struct DataTrackerApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var themeManager = AppThemeManager.shared
    @StateObject private var appLockManager = AppLockManager.shared
    @Environment(\.scenePhase) var scenePhase
    
    // AI Chat State
    @State private var showAIChat = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if appLockManager.isLocked {
                    LockScreenView()
                } else {
                    mainContentView
                }
            }
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .environmentObject(themeManager)
            .preferredColorScheme(themeManager.colorScheme)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    appLockManager.authenticate()
                } else if newPhase == .background {
                    appLockManager.lockApp()
                }
            }
        }
    }
    
    var mainContentView: some View {
        ZStack {
            TabView {
                DashboardView()
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("首页")
                    }
                
                EntryView()
                    .tabItem {
                        Image(systemName: "square.and.pencil")
                        Text("记录")
                    }
                
                InsightView()
                    .tabItem {
                        Image(systemName: "chart.xyaxis.line")
                        Text("洞察")
                    }
                
                SettingsView()
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("我的")
                    }
            }
            
            // Floating AI Button (Positioned over the middle tab)
            VStack {
                Spacer()
                Button {
                    showAIChat = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Theme.accentGradient)
                            .frame(width: 56, height: 56)
                            .shadow(color: Theme.accent.opacity(0.3), radius: 10, x: 0, y: 4)
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 4)
            }
            
            // AI Chat Sheet
            .fullScreenCover(isPresented: $showAIChat, onDismiss: {
                // Refresh Dashboard Data when AI Chat is closed
                NotificationCenter.default.post(name: NSNotification.Name("ReloadDashboardData"), object: nil)
            }) {
                AIChatView(isPresented: $showAIChat)
            }
        }
    }
}
