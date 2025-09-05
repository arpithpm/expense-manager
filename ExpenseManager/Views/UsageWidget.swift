import SwiftUI

struct UsageWidget: View {
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPricingView = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "camera.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Scans")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(usageText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if subscriptionManager.currentTier == .free {
                    Button("Upgrade") {
                        showingPricingView = true
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            if subscriptionManager.currentTier == .free {
                ProgressView(value: Double(subscriptionManager.dailyScansUsed), total: 10.0)
                    .tint(progressColor)
                    .background(Color(.systemGray5))
                
                HStack {
                    Text("\(subscriptionManager.dailyScansUsed) used")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(subscriptionManager.scansRemainingToday) remaining")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showingPricingView) {
            PricingView()
        }
    }
    
    private var usageText: String {
        switch subscriptionManager.currentTier {
        case .free:
            return "Free tier • Resets at midnight"
        case .premium:
            return "Premium • Unlimited"
        case .userAPIKey:
            return "Using your API key"
        }
    }
    
    private var progressColor: Color {
        let remaining = subscriptionManager.scansRemainingToday
        if remaining <= 2 {
            return .red
        } else if remaining <= 5 {
            return .orange
        } else {
            return .accentColor
        }
    }
}

#Preview {
    UsageWidget()
        .padding()
}
