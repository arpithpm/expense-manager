import SwiftUI
import PhotosUI
import Foundation

struct OverviewView: View {
    @EnvironmentObject var configurationManager: ConfigurationManager
    @ObservedObject private var expenseService = ExpenseService.shared
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isProcessingReceipts = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var expenseToDelete: Expense?
    @State private var showingDeleteConfirmation = false
    @State private var showingAllExpenses = false
    @State private var showingUpgradePrompt = false
    // Computed properties that automatically update when expenseService.expenses changes
    private var totalExpenses: Double {
        expenseService.getTotalInPrimaryCurrency()
    }
    
    private var monthlyTotal: Double {
        expenseService.getMonthlyTotalInPrimaryCurrency()
    }
    
    private var recentExpenses: [Expense] {
        Array(expenseService.expenses.sorted { $0.createdAt > $1.createdAt }.prefix(5))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    summaryCards
                    UsageWidget()
                    addReceiptSection
                    recentExpensesSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("ReceiptRadar")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                // Data refreshes automatically through @Published properties
            }
        }
        .onAppear {
            // Expenses are automatically loaded from ExpenseService init
        }
        .alert("Processing Result", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .alert("Delete Expense", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                expenseToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let expense = expenseToDelete {
                    expenseService.deleteExpense(expense)
                    expenseToDelete = nil
                }
            }
        } message: {
            if let expense = expenseToDelete {
                Text("Are you sure you want to delete the expense from \(expense.merchant) for \(expense.formattedAmount)?")
            }
        }
        .sheet(isPresented: $showingAllExpenses) {
            AllExpensesView()
        }
        .sheet(isPresented: $showingUpgradePrompt) {
            UpgradePromptView()
        }
        .onChange(of: selectedPhotos) { oldValue, newValue in
            if !newValue.isEmpty {
                // Check subscription limits first
                if !SubscriptionManager.shared.canScanToday {
                    // Clear selection and show upgrade prompt
                    selectedPhotos.removeAll()
                    showingUpgradePrompt = true
                } else {
                    Task {
                        await processSelectedPhotos()
                    }
                }
            }
        }
    }
    
    private var summaryCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            SummaryCard(
                title: "This Month",
                amount: expenseService.getMonthlyTotalInPrimaryCurrency(),
                icon: "calendar",
                color: .blue,
                currency: expenseService.getPrimaryCurrency()
            )
            
            SummaryCard(
                title: "Total Expenses",
                amount: expenseService.getTotalInPrimaryCurrency(),
                icon: "dollarsign.circle",
                color: .green,
                currency: expenseService.getPrimaryCurrency()
            )
        }
    }
    
    private var addReceiptSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Add New Expenses")
                    .font(.headline)
                Spacer()
                if SubscriptionManager.shared.currentTier == .free {
                    Text("\(SubscriptionManager.shared.scansRemainingToday) left today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 10,
                matching: .images
            ) {
                HStack {
                    if isProcessingReceipts {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Processing receipts...")
                            .font(.subheadline)
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                        Text("Select Receipt Photos")
                            .font(.headline)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(12)
            }
            .disabled(isProcessingReceipts)
            
            if !selectedPhotos.isEmpty {
                Text("Selected \(selectedPhotos.count) photo\(selectedPhotos.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var recentExpensesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recent Expenses")
                    .font(.headline)
                Spacer()
                if !recentExpenses.isEmpty {
                    Button("View All") {
                        showingAllExpenses = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                }
            }
            
            if recentExpenses.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "receipt")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No expenses yet")
                        .font(.title3)
                        .fontWeight(.medium)
                    Text("Use the camera button above to scan your first receipt")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 32)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(recentExpenses.prefix(5)) { expense in
                        ExpenseRowView(expense: expense) {
                            deleteExpense(expense)
                        }
                    }
                }
            }
        }
    }
    
    private func processSelectedPhotos() async {
        isProcessingReceipts = true
        
        let processedCount = await expenseService.processReceiptPhotos(selectedPhotos)
        
        selectedPhotos.removeAll()
        // No need to manually load expenses - the computed properties will automatically update
        
        if processedCount > 0 {
            alertMessage = "Successfully processed \(processedCount) receipt\(processedCount == 1 ? "" : "s") and added to your expenses."
        } else {
            alertMessage = "Failed to process receipts. Please check your API credentials and try again."
        }
        showingAlert = true
        
        isProcessingReceipts = false
    }
    
    
    
    private func deleteExpense(_ expense: Expense) {
        expenseToDelete = expense
        showingDeleteConfirmation = true
    }
}

struct SummaryCard: View {
    let title: String
    let amount: Double
    let icon: String
    let color: Color
    let currency: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(amount.formatted(currency: currency))
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct ExpenseRowView: View {
    let expense: Expense
    let onDelete: () -> Void
    @State private var showingItemDetails = false
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack {
                    Image(systemName: categoryIcon(for: expense.category))
                        .font(.title2)
                        .foregroundColor(.accentColor)
                        .frame(width: 40, height: 40)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(expense.merchant)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(expense.category)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(expense.date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let itemCount = expense.items?.count, itemCount > 0 {
                            Text("• \(itemCount) item\(itemCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.blue)
                            
                            Text("• Tap to expand")
                                .font(.caption2)
                                .foregroundColor(.blue.opacity(0.7))
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(expense.formattedAmount)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let paymentMethod = expense.paymentMethod {
                        Text(paymentMethod)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Hold to delete")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    if expense.items != nil && !expense.items!.isEmpty {
                        Image(systemName: showingItemDetails ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .onTapGesture {
                print("Row tapped for expense: \(expense.merchant), current state: \(showingItemDetails)")
                print("Expense has items: \(expense.items?.count ?? 0)")
                
                // Always toggle for debugging - later we'll add back the condition
                // Haptic feedback for tap
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingItemDetails.toggle()
                }
                print("New state: \(showingItemDetails)")
            }
            .onLongPressGesture(minimumDuration: 0.5, maximumDistance: 50) {
                print("Long press detected for expense: \(expense.merchant)")
                
                // Haptic feedback for long press
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                onDelete()
            } onPressingChanged: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            }
            
            // Item details section - Debug version
            if showingItemDetails {
                VStack(spacing: 8) {
                    Divider()
                        .padding(.horizontal)
                    
                    if let items = expense.items, !items.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(items) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        if let description = item.description {
                                            Text(description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        if let category = item.category {
                                            Text(category)
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(4)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        if let quantity = item.quantity, quantity != 1 {
                                            Text("\(quantity, specifier: "%.1f")x")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Text(item.formattedTotalPrice(currency: expense.currency))
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        if let unitPriceFormatted = item.formattedUnitPrice(currency: expense.currency), let quantity = item.quantity, quantity > 1 {
                                            Text("\(unitPriceFormatted) each")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    } else {
                        // Debug: Show message when no items
                        Text("No items found for this expense (Debug Mode)")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding()
                    }
                    
                    // Financial breakdown if available
                    if expense.subtotal != nil || expense.tip != nil || expense.fees != nil || expense.discounts != nil {
                        Divider()
                            .padding(.horizontal)
                        
                        VStack(spacing: 4) {
                            if let formattedSubtotal = expense.formattedSubtotal {
                                HStack {
                                    Text("Subtotal")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(formattedSubtotal)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let formattedDiscounts = expense.formattedDiscounts {
                                HStack {
                                    Text("Discounts")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(formattedDiscounts)
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                            
                            if let formattedFees = expense.formattedFees {
                                HStack {
                                    Text("Fees")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(formattedFees)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let formattedTaxAmount = expense.formattedTaxAmount {
                                HStack {
                                    Text("Tax")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(formattedTaxAmount)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let formattedTip = expense.formattedTip {
                                HStack {
                                    Text("Tip")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(formattedTip)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("Total")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(expense.formattedAmount)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        .id("expense-\(expense.id)-\(showingItemDetails)")
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Food & Dining": return "fork.knife"
        case "Transportation": return "car"
        case "Shopping": return "bag"
        case "Entertainment": return "tv"
        case "Bills & Utilities": return "lightbulb"
        case "Healthcare": return "cross.case"
        case "Travel": return "airplane"
        case "Education": return "book"
        case "Business": return "briefcase"
        default: return "doc.text"
        }
    }
}

struct AllExpensesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var expenseService = ExpenseService.shared
    @State private var expenseToDelete: Expense?
    @State private var showingDeleteConfirmation = false
    @State private var searchText = ""
    @State private var showSwipeHint = false
    
    private var filteredExpenses: [Expense] {
        if searchText.isEmpty {
            return expenseService.expenses.sorted { $0.createdAt > $1.createdAt }
        } else {
            return expenseService.expenses.filter { expense in
                expense.merchant.localizedCaseInsensitiveContains(searchText) ||
                expense.category.localizedCaseInsensitiveContains(searchText) ||
                (expense.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (expense.items?.contains { item in
                    item.name.localizedCaseInsensitiveContains(searchText) ||
                    (item.category?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                    (item.description?.localizedCaseInsensitiveContains(searchText) ?? false)
                } ?? false)
            }.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                if filteredExpenses.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "receipt")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No expenses found")
                            .font(.title3)
                            .fontWeight(.medium)
                        if !searchText.isEmpty {
                            Text("Try adjusting your search")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(filteredExpenses) { expense in
                        ExpenseRowView(expense: expense) {
                            deleteExpense(expense)
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("All Expenses")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search expenses...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay(
                // Swipe hint overlay
                swipeHintOverlay
            )
            .onAppear {
                checkAndShowSwipeHint()
            }
        }
        .alert("Delete Expense", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                expenseToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let expense = expenseToDelete {
                    expenseService.deleteExpense(expense)
                    expenseToDelete = nil
                }
            }
        } message: {
            if let expense = expenseToDelete {
                Text("Are you sure you want to delete the expense from \(expense.merchant) for \(expense.formattedAmount)?")
            }
        }
    }
    
    @ViewBuilder
    private var swipeHintOverlay: some View {
        if showSwipeHint && !filteredExpenses.isEmpty {
            VStack {
                Spacer()
                    .frame(height: 120) // Account for navigation bar
                
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.point.right.fill")
                            .foregroundColor(.white)
                            .font(.caption)
                        Text("💡 Swipe left on any expense to delete it")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        Image(systemName: "trash")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.accentColor.opacity(0.9))
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .allowsHitTesting(false) // Allow taps to pass through
        }
    }
    
    private func checkAndShowSwipeHint() {
        let hasShownHint = UserDefaults.standard.bool(forKey: "hasShownSwipeToDeleteHint")
        
        if !hasShownHint && !filteredExpenses.isEmpty {
            // Show hint after a brief delay to let the view settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSwipeHint = true
                }
                
                // Auto-hide after 4 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    hideSwipeHint()
                }
            }
        }
    }
    
    private func hideSwipeHint() {
        if showSwipeHint {
            withAnimation(.easeInOut(duration: 0.3)) {
                showSwipeHint = false
            }
            
            // Mark as shown so it doesn't appear again
            UserDefaults.standard.set(true, forKey: "hasShownSwipeToDeleteHint")
        }
    }
    
    private func deleteExpense(_ expense: Expense) {
        // Hide hint when user performs an action
        hideSwipeHint()
        expenseToDelete = expense
        showingDeleteConfirmation = true
    }
}

// MARK: - SubscriptionTier Extensions

// MARK: - Usage Widget
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

// MARK: - Upgrade Prompt View
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

// MARK: - Pricing View
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

// MARK: - Supporting Views
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
    OverviewView()
        .environmentObject(ConfigurationManager())
}