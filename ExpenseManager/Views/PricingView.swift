import SwiftUI
import StoreKit

struct PricingView: View {
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingAPIKeySheet = false
    @State private var tempAPIKey = ""
    @State private var isProcessingPurchase = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    currentUsageSection
                    pricingTiersSection
                    comparisonSection
                    footerSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Pricing Plans")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAPIKeySheet) {
            APIKeyInputView(apiKey: $tempAPIKey) {
                subscriptionManager.setUserAPIKey(tempAPIKey)
                showingAPIKeySheet = false
            }
        }
        .alert("Purchase Status", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "receipt.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text("Choose Your Plan")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Start with 10 free scans daily, or upgrade for unlimited processing")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    private var currentUsageSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Today's Usage")
                    .font(.headline)
                Spacer()
                Text("Current Plan: \(subscriptionManager.currentTier.displayName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if subscriptionManager.currentTier == .free {
                ProgressView(value: Double(subscriptionManager.dailyScansUsed), total: 10.0)
                    .tint(.accentColor)
                
                HStack {
                    Text("\(subscriptionManager.scansRemainingToday) scans remaining today")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Resets at midnight")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Image(systemName: "infinity")
                        .foregroundColor(.green)
                    Text("Unlimited scans available")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var pricingTiersSection: some View {
        VStack(spacing: 16) {
            ForEach(SubscriptionTier.allCases, id: \.self) { tier in
                PricingTierCard(
                    tier: tier,
                    isSelected: subscriptionManager.currentTier == tier,
                    onSelect: {
                        handleTierSelection(tier)
                    }
                )
            }
        }
    }
    
    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Why Choose ReceiptRadar?")
                .font(.headline)
            
            ComparisonRow(
                feature: "Daily Free Scans",
                ourValue: "10 per day",
                competitorValue: "5 per month",
                isAdvantage: true
            )
            
            ComparisonRow(
                feature: "Monthly Free Volume",
                ourValue: "300+ scans",
                competitorValue: "5-15 scans",
                isAdvantage: true
            )
            
            ComparisonRow(
                feature: "Premium Price",
                ourValue: "$1.99/month",
                competitorValue: "$4.99-9.99/month",
                isAdvantage: true
            )
            
            ComparisonRow(
                feature: "AI Technology",
                ourValue: "GPT-4o",
                competitorValue: "Basic OCR",
                isAdvantage: true
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var footerSection: some View {
        VStack(spacing: 12) {
            Text("🎯 60x more generous than competitors")
                .font(.headline)
                .foregroundColor(.accentColor)
            
            Text("While other apps limit you to 5 scans per month, we give you 10 per day!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("• No credit card required for free tier\n• Cancel anytime\n• All features included in free plan")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 20)
    }
    
    private func handleTierSelection(_ tier: SubscriptionTier) {
        switch tier {
        case .free:
            subscriptionManager.setTier(.free)
            subscriptionManager.setPremiumSubscription(false)
            
        case .premium:
            // In a real app, this would integrate with StoreKit
            isProcessingPurchase = true
            
            // Simulate purchase process
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                // For demo purposes, we'll simulate a successful purchase
                subscriptionManager.setPremiumSubscription(true)
                isProcessingPurchase = false
                alertMessage = "Welcome to Premium! You now have unlimited daily scans."
                showingAlert = true
            }
            
        case .userAPIKey:
            tempAPIKey = subscriptionManager.userAPIKey
            showingAPIKeySheet = true
        }
    }
}

struct PricingTierCard: View {
    let tier: SubscriptionTier
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tier.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(tier.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(tier.monthlyPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(tier == .premium ? .accentColor : .primary)
                    
                    if tier == .premium {
                        Text("Best Value")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .cornerRadius(4)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(tier.features, id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Text(feature)
                            .font(.subheadline)
                        
                        Spacer()
                    }
                }
            }
            
            Button(action: onSelect) {
                Text(buttonText)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(buttonColor)
                    .cornerRadius(8)
            }
            .disabled(isSelected)
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
        )
    }
    
    private var buttonText: String {
        if isSelected {
            return "Current Plan"
        }
        
        switch tier {
        case .free:
            return "Select Free Plan"
        case .premium:
            return "Upgrade to Premium"
        case .userAPIKey:
            return "Set API Key"
        }
    }
    
    private var buttonColor: Color {
        if isSelected {
            return Color(.systemGray3)
        }
        
        switch tier {
        case .free:
            return Color(.systemGray2)
        case .premium:
            return Color.accentColor
        case .userAPIKey:
            return Color.orange
        }
    }
}

struct ComparisonRow: View {
    let feature: String
    let ourValue: String
    let competitorValue: String
    let isAdvantage: Bool
    
    var body: some View {
        HStack {
            Text(feature)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Us")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(ourValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isAdvantage ? .green : .primary)
            }
            .frame(width: 80)
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Others")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(competitorValue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(width: 80)
        }
    }
}

struct APIKeyInputView: View {
    @Binding var apiKey: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Enter Your OpenAI API Key")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Use your own OpenAI credits for unlimited scanning. Your key is stored securely on your device.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                SecureField("sk-...", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(.body, design: .monospaced))
                
                Button("Save API Key") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.isEmpty)
                
                Spacer()
            }
            .padding()
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    PricingView()
}
