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
        Array(expenseService.expenses.sorted { $0.date > $1.date }.prefix(5))
    }
    
    private var customAppHeader: some View {
        HStack(spacing: 12) {
            // Radar icon with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: "wave.3.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            
            // App name with styled text
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Receipt")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Radar")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("1")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.blue.opacity(0.1))
                        )
                }
                
                Text("Smart Expense Tracking")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.top, 8)
    }
    
    private var demoBanner: some View {
        VStack(spacing: 0) {
            if expenseService.hasDemoData() {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Demo Mode")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button("Clear Demo Data") {
                                withAnimation(.spring(duration: 0.5)) {
                                    expenseService.clearDemoData()
                                }
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        }
                        
                        Text("You're viewing sample expenses to explore the app. Clear this data to start tracking your own expenses.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    customAppHeader
                    demoBanner
                    summaryCards
                    addReceiptSection
                    recentExpensesSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationBarHidden(true)
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

enum ExpenseSortOption: String, CaseIterable {
    case dateNewest = "Date (Newest First)"
    case dateOldest = "Date (Oldest First)"
    case amountHighest = "Amount (Highest First)"
    case amountLowest = "Amount (Lowest First)"
    case merchantAZ = "Merchant (A-Z)"
    case merchantZA = "Merchant (Z-A)"
    
    var systemImage: String {
        switch self {
        case .dateNewest: return "calendar.badge.minus"
        case .dateOldest: return "calendar.badge.plus"
        case .amountHighest: return "dollarsign.arrow.circlepath"
        case .amountLowest: return "dollarsign.circle"
        case .merchantAZ: return "textformat.abc"
        case .merchantZA: return "textformat.abc.dottedunderline"
        }
    }
}

struct AllExpensesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var expenseService = ExpenseService.shared
    @State private var expenseToDelete: Expense?
    @State private var showingDeleteConfirmation = false
    @State private var searchText = ""
    @State private var sortOption: ExpenseSortOption = .dateNewest
    @State private var showingSortOptions = false
    
    let isModal: Bool
    
    private var filteredExpenses: [Expense] {
        let expenses = searchText.isEmpty ? expenseService.expenses : expenseService.expenses.filter { expense in
            expense.merchant.localizedCaseInsensitiveContains(searchText) ||
            expense.category.localizedCaseInsensitiveContains(searchText) ||
            (expense.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (expense.items?.contains { item in
                item.name.localizedCaseInsensitiveContains(searchText) ||
                (item.category?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (item.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            } ?? false)
        }
        
        return expenses.sorted { expense1, expense2 in
            switch sortOption {
            case .dateNewest:
                return expense1.date > expense2.date
            case .dateOldest:
                return expense1.date < expense2.date
            case .amountHighest:
                return expense1.amount > expense2.amount
            case .amountLowest:
                return expense1.amount < expense2.amount
            case .merchantAZ:
                return expense1.merchant.localizedCaseInsensitiveCompare(expense2.merchant) == .orderedAscending
            case .merchantZA:
                return expense1.merchant.localizedCaseInsensitiveCompare(expense2.merchant) == .orderedDescending
            }
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingSortOptions = true
                    }) {
                        HStack(spacing: 4) {
                            ZStack {
                                Image(systemName: "arrow.up.arrow.down")
                                
                                // Show indicator dot when not using default sort
                                if sortOption != .dateNewest {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 8, y: -8)
                                }
                            }
                            Text("Sort")
                        }
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                    }
                }
                
                if isModal {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
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
        .sheet(isPresented: $showingSortOptions) {
            SortOptionsView(selectedSort: $sortOption)
        }
    }
    
    
    
    private func deleteExpense(_ expense: Expense) {
        expenseToDelete = expense
        showingDeleteConfirmation = true
    }
}

struct SortOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSort: ExpenseSortOption
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(ExpenseSortOption.allCases, id: \.self) { option in
                        HStack(spacing: 16) {
                            // Icon with colored background
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(option == selectedSort ? Color.accentColor : Color.gray.opacity(0.2))
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: option.systemImage)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(option == selectedSort ? .white : .primary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(option.rawValue)
                                        .font(.body)
                                        .fontWeight(option == selectedSort ? .semibold : .regular)
                                    
                                    if option == .dateNewest {
                                        Text("(Default)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color.blue.opacity(0.1))
                                            )
                                    }
                                    
                                    Spacer()
                                }
                                
                                Text(option.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if option == selectedSort {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.title3)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSort = option
                            dismiss()
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    }
                } header: {
                    Text("Sort Options")
                } footer: {
                    Text("Choose how to organize your expenses. The default sorting shows newest expenses first.")
                }
            }
            .navigationTitle("Sort Expenses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

extension ExpenseSortOption {
    var description: String {
        switch self {
        case .dateNewest:
            return "Most recent expenses appear first"
        case .dateOldest:
            return "Oldest expenses appear first"
        case .amountHighest:
            return "Largest amounts appear first"
        case .amountLowest:
            return "Smallest amounts appear first"
        case .merchantAZ:
            return "Merchants sorted alphabetically A-Z"
        case .merchantZA:
            return "Merchants sorted alphabetically Z-A"
        }
    }
}

#Preview {
    OverviewView(selectedTab: .constant(0))
        .environmentObject(ConfigurationManager())
}
