import SwiftUI
import Foundation
import CoreData

@main
struct ExpenseManagerApp: App {
    @StateObject private var configurationManager = ConfigurationManager()
    private let backgroundAnalysisManager = BackgroundAnalysisManager.shared

    var body: some Scene {
        WindowGroup {
            if configurationManager.isConfigured {
                ContentView()
                    .environmentObject(configurationManager)
                    .onAppear {
                        // Start background AI analysis when app opens
                        backgroundAnalysisManager.performBackgroundAnalysisIfNeeded()
                    }
            } else {
                ConfigurationView()
                    .environmentObject(configurationManager)
            }
        }
    }
}