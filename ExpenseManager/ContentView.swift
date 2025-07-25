import SwiftUI
import Foundation

struct ContentView: View {
    @EnvironmentObject var configurationManager: ConfigurationManager
    
    var body: some View {
        TabView {
            OverviewView()
                .tabItem {
                    Image(systemName: "chart.pie")
                    Text("Overview")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
        .environmentObject(configurationManager)
    }
}

#Preview {
    ContentView()
        .environmentObject(ConfigurationManager())
}