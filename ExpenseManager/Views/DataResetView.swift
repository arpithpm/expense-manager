import SwiftUI

struct DataResetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var resetManager = DataResetManager.shared
    @State private var selectedCategories: Set<DataResetManager.ResetCategory> = []
    @State private var showingConfirmation = false
    @State private var showingProgress = false
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var resetProgress = 0.0
    @State private var categoryItemCounts: [DataResetManager.ResetCategory: Int] = [:]
    @State private var resetSummary = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    categoriesSection
                    actionButtons
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Reset App Data")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .confirmationDialog("Confirm Data Reset", isPresented: $showingConfirmation) {
            Button("Yes, Delete Selected Data", role: .destructive) {
                performReset()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You are about to delete:\n\n\(resetSummary)\n\nThis action cannot be undone.")
        }
        .alert("Reset Complete", isPresented: $showingSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Selected data has been successfully reset. Consider restarting the app to see all changes.")
        }
        .alert("Reset Failed", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if showingProgress {
                resetProgressOverlay
            }
        }
        .onAppear {
            loadItemCounts()
        }
        .onChange(of: selectedCategories) { _ in
            updateResetSummary()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "trash.circle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Select Data to Reset")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Choose which data you want to remove from the app. Be careful - most actions cannot be undone.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }
    
    private var categoriesSection: some View {
        VStack(spacing: 16) {
            // Expense Data Group
            categoryGroup(
                title: "💰 Expense Data",
                categories: [.allExpenses, .sampleExpenses, .analyticsCache]
            )
            
            // OpenAI Configuration Group
            categoryGroup(
                title: "🤖 OpenAI Configuration", 
                categories: [.openAIKey, .openAIHistory]
            )
            
            // App Settings Group
            categoryGroup(
                title: "⚙️ App Settings",
                categories: [.userPreferences, .firstLaunchFlag, .backupData]
            )
            
            // Complete Reset Group
            categoryGroup(
                title: "🧹 Complete Reset",
                categories: [.completeReset]
            )
        }
    }
    
    private func categoryGroup(title: String, categories: [DataResetManager.ResetCategory]) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            VStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    categoryRow(category: category)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        }
    }
    
    private func categoryRow(category: DataResetManager.ResetCategory) -> some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.title3)
                .foregroundColor(category.isDestructive ? .red : .blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(category.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(category.isDestructive ? .red : .primary)
                    
                    if let itemCount = categoryItemCounts[category], itemCount > 0 {
                        Text("(\(itemCount))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Text(category.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { selectedCategories.contains(category) },
                set: { isSelected in
                    if isSelected {
                        selectedCategories.insert(category)
                        // If complete reset is selected, deselect others
                        if category == .completeReset {
                            selectedCategories = [.completeReset]
                        }
                    } else {
                        selectedCategories.remove(category)
                    }
                    
                    // If any other category is selected, deselect complete reset
                    if category != .completeReset && isSelected {
                        selectedCategories.remove(.completeReset)
                    }
                }
            ))
            .toggleStyle(SwitchToggleStyle(tint: category.isDestructive ? .red : .accentColor))
        }
        .padding(.vertical, 4)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                showingConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Reset Selected Data")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedCategories.isEmpty ? Color.gray : Color.red)
                .cornerRadius(12)
            }
            .disabled(selectedCategories.isEmpty)
            
            if !selectedCategories.isEmpty {
                Text("Selected: \(selectedCategories.count) item\(selectedCategories.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var resetProgressOverlay: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("Resetting Data...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(40)
                .background(Color.black.opacity(0.8))
                .cornerRadius(16)
            }
    }
    
    private func performReset() {
        showingProgress = true
        
        Task {
            do {
                try await resetManager.resetData(categories: selectedCategories)
                
                await MainActor.run {
                    showingProgress = false
                    showingSuccess = true
                    selectedCategories.removeAll()
                }
            } catch {
                await MainActor.run {
                    showingProgress = false
                    errorMessage = "Failed to reset data: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    @MainActor
    private func loadItemCounts() {
        for category in DataResetManager.ResetCategory.allCases {
            categoryItemCounts[category] = resetManager.getItemCount(for: category)
        }
    }
    
    @MainActor
    private func updateResetSummary() {
        resetSummary = resetManager.getResetSummary(for: selectedCategories)
    }
}

#Preview {
    DataResetView()
}
