import SwiftUI
import Foundation

struct ContentView: View {
    @EnvironmentObject var configurationManager: ConfigurationManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            OverviewView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "chart.pie")
                    Text("Overview")
                }
                .tag(0)
            
            AllExpensesView(isModal: false)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("All Expenses")
                }
                .tag(1)
            
            SpendingInsightsView()
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("AI Insights")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)
        }
        .environmentObject(configurationManager)
    }
}

#Preview {
    ContentView()
        .environmentObject(ConfigurationManager())
}