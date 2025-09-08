import Foundation
import SwiftUI

class DataResetManager: ObservableObject {
    static let shared = DataResetManager()
    
    enum ResetCategory: String, CaseIterable {
        case allExpenses = "All Expenses"
        case sampleExpenses = "Sample Expenses Only"
        case openAIKey = "OpenAI API Key"
        case completeReset = "Complete Reset (Everything)"
        
        var description: String {
            switch self {
            case .allExpenses:
                return "Remove all stored expenses from the app"
            case .sampleExpenses:
                return "Remove only the sample/demo expenses"
            case .openAIKey:
                return "Remove stored OpenAI API key from Keychain"
            case .completeReset:
                return "Reset everything - returns app to fresh install state"
            }
        }
        
        var icon: String {
            switch self {
            case .allExpenses, .sampleExpenses:
                return "trash"
            case .openAIKey:
                return "key"
            case .completeReset:
                return "exclamationmark.triangle"
            }
        }
        
        var isDestructive: Bool {
            switch self {
            case .allExpenses, .completeReset:
                return true
            case .sampleExpenses, .openAIKey:
                return false
            }
        }
    }
    
    private let keychainService = KeychainService.shared
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    @MainActor
    func resetData(categories: Set<ResetCategory>) async throws {
        let expenseService = CoreDataExpenseService.shared
        for category in categories {
            try await resetCategory(category, expenseService: expenseService)
        }
    }
    
    @MainActor
    private func resetCategory(_ category: ResetCategory, expenseService: ExpenseService) async throws {
        switch category {
        case .allExpenses:
            expenseService.expenses.removeAll()
            try? expenseService.saveExpensesToUserDefaults()
            
        case .sampleExpenses:
            expenseService.expenses.removeAll { expense in
                ExpenseService.sampleMerchants.contains(expense.merchant)
            }
            try? expenseService.saveExpensesToUserDefaults()
            
        case .openAIKey:
            try keychainService.deleteAPIKey()
            
        case .completeReset:
            // Reset everything
            expenseService.expenses.removeAll()
            try? expenseService.saveExpensesToUserDefaults()
            try? keychainService.deleteAPIKey()
            
            // Clear all UserDefaults for this app
            let allKeys = ["SavedExpenses", "HasLaunchedBefore", "LastBackupDate",
                          "OpenAIUsageHistory", "OpenAILastUsed", "UserSelectedCurrency",
                          "NotificationsEnabled", "AppTheme", "BackupStatus"]
            for key in allKeys {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
    
    @MainActor
    func getItemCount(for category: ResetCategory) -> Int {
        let expenseService = CoreDataExpenseService.shared
        switch category {
        case .allExpenses:
            return expenseService.expenses.count
        case .sampleExpenses:
            return expenseService.expenses.filter { expense in
                ExpenseService.sampleMerchants.contains(expense.merchant)
            }.count
        case .openAIKey:
            return keychainService.hasValidAPIKey() ? 1 : 0
        case .completeReset:
            return expenseService.expenses.count + (keychainService.hasValidAPIKey() ? 1 : 0)
        }
    }
    
    @MainActor
    func getResetSummary(for categories: Set<ResetCategory>) -> String {
        var summary: [String] = []
        
        for category in categories.sorted(by: { $0.rawValue < $1.rawValue }) {
            let count = getItemCount(for: category)
            if count > 0 {
                summary.append("• \(category.rawValue) (\(count) item\(count == 1 ? "" : "s"))")
            } else {
                summary.append("• \(category.rawValue)")
            }
        }
        
        return summary.joined(separator: "\n")
    }
}