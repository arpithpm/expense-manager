import SwiftUI
import Foundation
import CoreData

@main
struct ExpenseManagerApp: App {
    @StateObject private var configurationManager = ConfigurationManager()
    
    init() {
        // Perform migration from UserDefaults to Core Data on startup
        performDataMigration()
    }
    
    var body: some Scene {
        WindowGroup {
            if configurationManager.isConfigured {
                ContentView()
                    .environmentObject(configurationManager)
            } else {
                ConfigurationView()
                    .environmentObject(configurationManager)
            }
        }
    }
    
    private func performDataMigration() {
        do {
            try CoreDataExpenseService.shared.migrateFromUserDefaults()
        } catch {
            print("Migration failed: \(error)")
        }
    }
}