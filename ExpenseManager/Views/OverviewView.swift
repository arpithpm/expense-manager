import SwiftUI
import PhotosUI
import Foundation
import Photos

struct OverviewView: View {
    @EnvironmentObject var configurationManager: ConfigurationManager
    @StateObject private var expenseService = ExpenseService()
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isProcessingReceipts = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var recentExpenses: [Expense] = []
    @State private var totalExpenses: Double = 0
    @State private var monthlyTotal: Double = 0
    
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
            .navigationTitle("Expense Manager")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadExpenses()
            }
        }
        .onAppear {
            Task {
                await loadExpenses()
            }
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
                        // TODO: Navigate to all expenses view
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
                    }
                }
            }
        }
    }
    
    private func processSelectedPhotos() async {
        isProcessingReceipts = true
        
        let processedCount = await expenseService.processReceiptPhotos(selectedPhotos)
        
        selectedPhotos.removeAll()
        await loadExpenses()
        
        if processedCount > 0 {
            alertMessage = "Successfully processed \(processedCount) receipt\(processedCount == 1 ? "" : "s") and added to your expenses.\n\nYou can now manually delete the original photo\(processedCount == 1 ? "" : "s") from your Photos app if desired."
        } else {
            alertMessage = "Failed to process receipts. Please check your API credentials and try again."
        }
        showingAlert = true
        
        isProcessingReceipts = false
    }
    
    private func loadExpenses() async {
        do {
            recentExpenses = try await expenseService.fetchRecentExpenses(limit: 10)
            totalExpenses = try await expenseService.getTotalExpenses()
            monthlyTotal = try await expenseService.getMonthlyTotal()
        } catch {
            print("Failed to load expenses: \(error)")
        }
    }
    
    private func openPhotosApp() {
        if let photosURL = URL(string: "photos-redirect://") {
            UIApplication.shared.open(photosURL)
        }
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
                
                Text("Delete manually from Photos")
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

#Preview {
    OverviewView()
        .environmentObject(ConfigurationManager())
}