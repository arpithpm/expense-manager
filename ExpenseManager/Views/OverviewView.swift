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
    
    @Binding var selectedTab: Int
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
        .onChange(of: selectedPhotos) { oldValue, newValue in
            if !newValue.isEmpty {
                Task {
                    await processSelectedPhotos()
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
                        selectedTab = 1
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
    
    let isModal: Bool
    
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
                if isModal {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
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

#Preview {
    OverviewView(selectedTab: .constant(0))
        .environmentObject(ConfigurationManager())
}
