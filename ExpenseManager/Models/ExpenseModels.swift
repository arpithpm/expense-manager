import Foundation
import SwiftUI

// MARK: - Error Handling

enum ExpenseManagerError: LocalizedError, Equatable {
    case invalidAmount
    case invalidDate
    case networkError(underlying: Error)
    case dataCorruption
    case apiKeyMissing
    case imageProcessingFailed
    case persistenceError(underlying: Error)
    case invalidExpenseData
    
    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return "Invalid expense amount"
        case .invalidDate:
            return "Invalid expense date"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .dataCorruption:
            return "Data corruption detected"
        case .apiKeyMissing:
            return "OpenAI API key is missing"
        case .imageProcessingFailed:
            return "Failed to process receipt image"
        case .persistenceError(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .invalidExpenseData:
            return "Invalid expense data"
        }
    }
    
    var recoveryDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "Please add your OpenAI API key in Settings"
        case .networkError:
            return "Check your internet connection and try again"
        case .dataCorruption:
            return "Your data may need to be reset"
        case .invalidAmount, .invalidDate, .invalidExpenseData:
            return "Please check your input and try again"
        case .imageProcessingFailed:
            return "Try selecting a clearer image of your receipt"
        case .persistenceError:
            return "Try restarting the app"
        }
    }
    
    static func == (lhs: ExpenseManagerError, rhs: ExpenseManagerError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidAmount, .invalidAmount),
             (.invalidDate, .invalidDate),
             (.dataCorruption, .dataCorruption),
             (.apiKeyMissing, .apiKeyMissing),
             (.imageProcessingFailed, .imageProcessingFailed),
             (.invalidExpenseData, .invalidExpenseData):
            return true
        case (.networkError(let lhsError), .networkError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.persistenceError(let lhsError), .persistenceError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - Core Data Models

struct ExpenseItem: Identifiable, Codable {
    let id: UUID
    let name: String
    let quantity: Double?
    let unitPrice: Double?
    let totalPrice: Double
    let category: String?
    let description: String?
    
    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double? = nil,
        unitPrice: Double? = nil,
        totalPrice: Double,
        category: String? = nil,
        description: String? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice
        self.category = category
        self.description = description
    }
}

struct Expense: Identifiable, Codable {
    let id: UUID
    let date: Date
    let merchant: String
    let amount: Double
    let currency: String
    let category: String
    let description: String?
    let paymentMethod: String?
    let taxAmount: Double?
    let receiptImageUrl: String?
    let createdAt: Date
    let updatedAt: Date
    
    // Enhanced item-level tracking
    let items: [ExpenseItem]?
    let subtotal: Double?
    let discounts: Double?
    let fees: Double?
    let tip: Double?
    let itemsTotal: Double?
    
    init(
        id: UUID = UUID(),
        date: Date,
        merchant: String,
        amount: Double,
        currency: String = "USD",
        category: String,
        description: String? = nil,
        paymentMethod: String? = nil,
        taxAmount: Double? = nil,
        receiptImageUrl: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        items: [ExpenseItem]? = nil,
        subtotal: Double? = nil,
        discounts: Double? = nil,
        fees: Double? = nil,
        tip: Double? = nil,
        itemsTotal: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.merchant = merchant
        self.amount = amount
        self.currency = currency
        self.category = category
        self.description = description
        self.paymentMethod = paymentMethod
        self.taxAmount = taxAmount
        self.receiptImageUrl = receiptImageUrl
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.items = items
        self.subtotal = subtotal
        self.discounts = discounts
        self.fees = fees
        self.tip = tip
        self.itemsTotal = itemsTotal
    }
}

// MARK: - Static Data

struct ExpenseCategory {
    static let categories = [
        "Food & Dining", "Transportation", "Shopping", "Entertainment",
        "Bills & Utilities", "Healthcare", "Travel", "Education", "Business", "Other"
    ]
}

struct PaymentMethod {
    static let methods = [
        "Cash", "Credit Card", "Debit Card", "Digital Payment", "Bank Transfer", "Check", "Other"
    ]
}

// MARK: - OpenAI API Models

struct OpenAIExpenseExtraction: Codable {
    let date: String
    let merchant: String
    let amount: Double
    let currency: String
    let category: String
    let description: String?
    let paymentMethod: String?
    let taxAmount: Double?
    let confidence: Double
    
    // Enhanced item-level tracking
    let items: [OpenAIExpenseItem]?
    let subtotal: Double?
    let discounts: Double?
    let fees: Double?
    let tip: Double?
    let itemsTotal: Double?
}

struct OpenAIExpenseItem: Codable {
    let name: String
    let quantity: Double?
    let unitPrice: Double?
    let totalPrice: Double
    let category: String?
    let description: String?
}

struct OpenAIResponse: Codable {
    let choices: [Choice]
    struct Choice: Codable {
        let message: Message
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }
    struct Message: Codable {
        let content: String
    }
}

enum OpenAIError: LocalizedError {
    case invalidAPIKey
    case networkError(Error)
    case decodingError(Error)
    case invalidResponse
    case rateLimitExceeded
    case insufficientTokens
    case modelNotAvailable
    case imageProcessingFailed
    case invalidImageFormat
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid OpenAI API key"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from OpenAI"
        case .rateLimitExceeded:
            return "API rate limit exceeded"
        case .insufficientTokens:
            return "Insufficient tokens in your account"
        case .modelNotAvailable:
            return "The requested model is not available"
        case .imageProcessingFailed:
            return "Failed to process the image"
        case .invalidImageFormat:
            return "Unsupported image format"
        }
    }
}

// MARK: - Backup and Export Models

enum BackupUploadStatus {
    case idle
    case preparing
    case uploading
    case completed
    case failed(Error)
    
    var isInProgress: Bool {
        switch self {
        case .preparing, .uploading:
            return true
        default:
            return false
        }
    }
}

enum BackupStatus {
    case noData
    case current      
    case recent       
    case outdated     
    case notBackedUp  
    
    var displayText: String {
        switch self {
        case .noData: return "No data to backup"
        case .current: return "Backed up recently"
        case .recent: return "Backed up today"
        case .outdated: return "Backup outdated"
        case .notBackedUp: return "Not backed up"
        }
    }
    
    var color: Color {
        switch self {
        case .noData: return .secondary
        case .current: return .green
        case .recent: return .blue
        case .outdated: return .orange
        case .notBackedUp: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .noData: return "doc"
        case .current: return "checkmark.icloud.fill"
        case .recent: return "checkmark.icloud"
        case .outdated: return "exclamationmark.icloud"
        case .notBackedUp: return "xmark.icloud"
        }
    }
}


// MARK: - Insights Models

struct SpendingInsights: Codable {
    let totalSpent: Double
    let averageExpense: Double
    let topCategories: [String: Double]
    let spendingTrend: String
    let savingsOpportunities: [SavingsOpportunity]
    let categoryInsights: [CategoryInsight]
    let spendingPatterns: [SpendingPattern]
    let regionalInsights: [RegionalInsight]
    let monthlyComparison: Double
    let actionItems: [ActionItem]
    let generatedAt: Date
}

struct SavingsOpportunity: Codable {
    let title: String
    let description: String
    let potentialSavings: Double
    let category: String
    let difficulty: InsightDifficulty
    let impact: InsightImpact
    let actionSteps: [String]
}

struct CategoryInsight: Codable {
    let category: String
    let totalSpent: Double
    let percentageOfTotal: Double
    let comparison: String
    let recommendation: String
    let trendAnalysis: String
    let seasonalPattern: String?
}

struct SpendingPattern: Codable {
    let pattern: String
    let frequency: String
    let impact: String
    let recommendation: String
}

struct RegionalInsight: Codable {
    let region: String
    let comparison: RegionalComparison
    let insight: String
}

struct RegionalComparison: Codable {
    let userSpending: Double
    let regionalAverage: Double
    let percentageDifference: Double
}

struct ActionItem: Codable {
    let title: String
    let description: String
    let priority: InsightSeverity
}

enum InsightDifficulty: String, Codable {
    case easy = "Easy"
    case moderate = "Moderate"
    case hard = "Hard"
    
    var color: Color {
        switch self {
        case .easy: return .green
        case .moderate: return .orange
        case .hard: return .red
        }
    }
}

enum InsightImpact: String, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .purple
        }
    }
}

enum InsightSeverity: String, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

enum InsightsError: LocalizedError {
    case noExpenseData
    case calculationError
    case apiError(Error)
    case invalidResponse
    case insufficientData
    
    var errorDescription: String? {
        switch self {
        case .noExpenseData:
            return "No expense data available for analysis"
        case .calculationError:
            return "Error calculating spending insights"
        case .apiError(let error):
            return "API error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from insights service"
        case .insufficientData:
            return "Insufficient data for meaningful insights"
        }
    }
}

// MARK: - Extensions

extension Double {
    var formatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: self)) ?? "$\(self)"
    }
}

extension Expense {
    var hasDetailedBreakdown: Bool {
        return items?.isEmpty == false || subtotal != nil || taxAmount != nil
    }
    
    var calculatedTotal: Double {
        let itemsSum = items?.reduce(0) { $0 + $1.totalPrice } ?? 0
        let subtotalValue = subtotal ?? itemsSum
        let taxValue = taxAmount ?? 0
        let feesValue = fees ?? 0
        let tipValue = tip ?? 0
        let discountValue = discounts ?? 0
        
        return subtotalValue + taxValue + feesValue + tipValue - discountValue
    }
    
    var isComplexExpense: Bool {
        return (items?.count ?? 0) > 1 || taxAmount != nil || fees != nil || tip != nil || discounts != nil
    }
}

extension ExpenseItem {
    var unitPriceFormatted: String? {
        guard let unitPrice = unitPrice else { return nil }
        return String(format: "$%.2f", unitPrice)
    }
}