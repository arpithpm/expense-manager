import SwiftUI
import Foundation

@main
struct ExpenseManagerApp: App {
    @StateObject private var configurationManager = ConfigurationManager()
    
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
}