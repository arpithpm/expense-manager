import SwiftUI

struct UpgradePromptView: View {
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingPricingView = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                Text("Daily Scan Limit Reached")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("You've used all 10 free scans today! Your limit resets at midnight.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Reset time info
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.orange)
                    Text("Resets at midnight")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Text(timeUntilMidnight)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            
            // Upgrade options
            VStack(spacing: 16) {
                Text("Continue Scanning Now")
                    .font(.headline)
                
                Button(action: {
                    showingPricingView = true
                }) {
                    VStack(spacing: 8) {
                        Text("Upgrade to Premium")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("$1.99/month • Unlimited daily scans")
                            .font(.subheadline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    // This would show API key input
                    showingPricingView = true
                }) {
                    VStack(spacing: 4) {
                        Text("Use Your Own API Key")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Pay only for what you use")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            // Comparison highlight
            VStack(spacing: 8) {
                Text("💎 60x More Generous Than Competitors")
                    .font(.headline)
                    .foregroundColor(.accentColor)
                
                Text("Other apps: 5 scans per month\nReceiptRadar: 10 scans per day!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
            
            // Dismiss button
            Button("Continue with Free Plan") {
                dismiss()
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .sheet(isPresented: $showingPricingView) {
            PricingView()
        }
    }
    
    private var timeUntilMidnight: String {
        let calendar = Calendar.current
        let now = Date()
        
        // Get tomorrow at midnight
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
              let midnight = calendar.dateInterval(of: .day, for: tomorrow)?.start else {
            return "Resets at midnight"
        }
        
        let timeInterval = midnight.timeIntervalSince(now)
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        if hours > 0 {
            return "Resets in \(hours)h \(minutes)m"
        } else {
            return "Resets in \(minutes) minutes"
        }
    }
}

#Preview {
    UpgradePromptView()
}
