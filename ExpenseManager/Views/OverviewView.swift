import SwiftUI
import PhotosUI
import Foundation
import Photos

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
    // Computed properties that automatically update when expenseService.expenses changes
    private var totalExpenses: Double {
        expenseService.expenses.reduce(0) { $0 + $1.amount }
    }
    
    private var monthlyTotal: Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
        
        return expenseService.expenses.filter { expense in
            expense.date >= startOfMonth && expense.date < endOfMonth
        }.reduce(0) { $0 + $1.amount }
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
                    processedPhotosSection
                    recentExpensesSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("My Expenses")
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
        .alert("Photos Processed Successfully", isPresented: $expenseService.showProcessingCompletionDialog) {
            Button("Not Now") {
                expenseService.showProcessingCompletionDialog = false
            }
            Button("Go to Photos") {
                expenseService.showProcessingCompletionDialog = false
                openPhotosApp()
            }
        } message: {
            Text("Successfully processed \(expenseService.processedPhotoCount) photo\(expenseService.processedPhotoCount == 1 ? "" : "s"). Would you like to delete the original\(expenseService.processedPhotoCount == 1 ? "" : "s") from your Photos library?")
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
                Text("Are you sure you want to delete the expense from \(expense.merchant) for $\(expense.amount, specifier: "%.2f")?")
            }
        }
        .sheet(isPresented: $showingAllExpenses) {
            AllExpensesView()
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
                amount: monthlyTotal,
                icon: "calendar",
                color: .blue
            )
            
            SummaryCard(
                title: "Total Expenses",
                amount: totalExpenses,
                icon: "dollarsign.circle",
                color: .green
            )
        }
    }
    
    private var addReceiptSection: some View {
        VStack(spacing: 16) {
            Text("Add New Expenses")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
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
    
    private var processedPhotosSection: some View {
        Group {
            if !expenseService.processedPhotos.isEmpty {
                VStack(spacing: 16) {
                    HStack {
                        Text("Processed Photos")
                            .font(.headline)
                        Spacer()
                        Button("Clear All") {
                            expenseService.clearProcessedPhotos()
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    
                    LazyVStack(spacing: 12) {
                        ForEach(expenseService.processedPhotos) { processedPhoto in
                            ProcessedPhotoRowView(processedPhoto: processedPhoto)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("Delete", role: .destructive) {
                                        deleteExpense(processedPhoto.expense)
                                    }
                                }
                                .contextMenu {
                                    Button("Delete Expense", role: .destructive) {
                                        deleteExpense(processedPhoto.expense)
                                    }
                                }
                        }
                    }
                }
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
                        ExpenseRowView(expense: expense)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) {
                                    deleteExpense(expense)
                                }
                            }
                            .contextMenu {
                                Button("Delete Expense", role: .destructive) {
                                    deleteExpense(expense)
                                }
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
    
    
    private func openPhotosApp() {
        if let photosURL = URL(string: "photos-redirect://") {
            UIApplication.shared.open(photosURL)
        }
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
            
            Text("$\(amount, specifier: "%.2f")")
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
    
    var body: some View {
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
                
                Text(expense.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(expense.amount, specifier: "%.2f")")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let paymentMethod = expense.paymentMethod {
                    Text(paymentMethod)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
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

struct ProcessedPhotoRowView: View {
    let processedPhoto: ExpenseService.ProcessedPhoto
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(processedPhoto.expense.merchant)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("$\(processedPhoto.expense.amount, specifier: "%.2f") • \(processedPhoto.expense.category)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Processed: \(processedPhoto.processingDate, style: .time)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("✓ Processed")
                    .font(.caption)
                    .foregroundColor(.green)
                    .fontWeight(.medium)
                
                Text("Swipe to delete")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

struct AllExpensesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var expenseService = ExpenseService.shared
    @State private var expenseToDelete: Expense?
    @State private var showingDeleteConfirmation = false
    @State private var searchText = ""
    
    private var filteredExpenses: [Expense] {
        if searchText.isEmpty {
            return expenseService.expenses.sorted { $0.createdAt > $1.createdAt }
        } else {
            return expenseService.expenses.filter { expense in
                expense.merchant.localizedCaseInsensitiveContains(searchText) ||
                expense.category.localizedCaseInsensitiveContains(searchText) ||
                (expense.description?.localizedCaseInsensitiveContains(searchText) ?? false)
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
                        ExpenseRowView(expense: expense)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) {
                                    deleteExpense(expense)
                                }
                            }
                            .contextMenu {
                                Button("Delete Expense", role: .destructive) {
                                    deleteExpense(expense)
                                }
                            }
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
                Text("Are you sure you want to delete the expense from \(expense.merchant) for $\(expense.amount, specifier: "%.2f")?")
            }
        }
    }
    
    private func deleteExpense(_ expense: Expense) {
        expenseToDelete = expense
        showingDeleteConfirmation = true
    }
}

#Preview {
    OverviewView()
        .environmentObject(ConfigurationManager())
}