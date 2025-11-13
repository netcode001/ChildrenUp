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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
