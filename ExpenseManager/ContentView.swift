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
                .accessibilityLabel("Overview Tab")
                .accessibilityHint("Shows your expense overview and recent transactions")
            
            AllExpensesView(isModal: false)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("All Expenses")
                }
                .tag(1)
                .accessibilityLabel("All Expenses Tab")
                .accessibilityHint("Shows complete list of all your expenses")
            
            SpendingInsightsView()
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("AI Insights")
                }
                .tag(2)
                .accessibilityLabel("AI Insights Tab")
                .accessibilityHint("Shows AI-powered spending analysis and recommendations")
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)
                .accessibilityLabel("Settings Tab")
                .accessibilityHint("Access app settings and data management options")
        }
        .environmentObject(configurationManager)
    }
}

#Preview {
    ContentView()
        .environmentObject(ConfigurationManager())
}