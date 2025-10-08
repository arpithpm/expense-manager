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
    
    // Automatic correction tracking
    let appliedCorrections: [AutomaticCorrection]
    
    init(date: String, merchant: String, amount: Double, currency: String, category: String, description: String?, paymentMethod: String?, taxAmount: Double?, confidence: Double, items: [OpenAIExpenseItem]?, subtotal: Double?, discounts: Double?, fees: Double?, tip: Double?, itemsTotal: Double?, appliedCorrections: [AutomaticCorrection] = []) {
        self.date = date
        self.merchant = merchant
        self.amount = amount
        self.currency = currency
        self.category = category
        self.description = description
        self.paymentMethod = paymentMethod
        self.taxAmount = taxAmount
        self.confidence = confidence
        self.items = items
        self.subtotal = subtotal
        self.discounts = discounts
        self.fees = fees
        self.tip = tip
        self.itemsTotal = itemsTotal
        self.appliedCorrections = appliedCorrections
    }
}

// MARK: - Automatic Correction Tracking

struct AutomaticCorrection: Codable {
    let field: CorrectionField
    let originalValue: String?
    let correctedValue: String
    let reason: String
    let confidence: Double
    let timestamp: Date
    
    init(field: CorrectionField, originalValue: String?, correctedValue: String, reason: String, confidence: Double = 1.0) {
        self.field = field
        self.originalValue = originalValue
        self.correctedValue = correctedValue
        self.reason = reason
        self.confidence = confidence
        self.timestamp = Date()
    }
}

enum CorrectionField: String, Codable {
    case date
    case currency
    case merchant
    case amount
    case category
}

extension AutomaticCorrection {
    var userFriendlyMessage: String {
        switch field {
        case .date:
            if let original = originalValue {
                return "Date was unclear (\(original)), used \(correctedValue)"
            } else {
                return "Date was not visible, used today's date (\(correctedValue))"
            }
        case .currency:
            if let original = originalValue {
                return "Currency changed from \(original) to \(correctedValue) based on business location"
            } else {
                return "Currency determined from business location: \(correctedValue)"
            }
        case .merchant:
            return "Merchant name corrected: \(correctedValue)"
        case .amount:
            return "Amount corrected: \(correctedValue)"
        case .category:
            return "Category assigned: \(correctedValue)"
        }
    }
    
    var icon: String {
        switch field {
        case .date: return "calendar.badge.exclamationmark"
        case .currency: return "globe.badge.chevron.backward"
        case .merchant: return "building.2.crop.circle.badge.plus"
        case .amount: return "dollarsign.circle.fill"
        case .category: return "tag.circle.fill"
        }
    }
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

// MARK: - Currency Helper

struct CurrencyHelper {
    static func symbol(for currencyCode: String) -> String {
        switch currencyCode.uppercased() {
        case "USD", "CAD", "AUD", "NZD", "MXN", "ARS", "CLP", "COP", "UYU", "SGD", "HKD", "TWD":
            return "$"
        case "EUR":
            return "€"
        case "GBP":
            return "£"
        case "INR":
            return "₹"
        case "JPY", "CNY":
            return "¥"
        case "CHF":
            return "CHF"
        case "SEK", "NOK", "DKK":
            return "kr"
        case "PLN":
            return "zł"
        case "CZK":
            return "Kč"
        case "HUF":
            return "Ft"
        case "RON":
            return "lei"
        case "BGN":
            return "лв"
        case "HRK":
            return "kn"
        case "RSD":
            return "дин"
        case "TRY":
            return "₺"
        case "ILS":
            return "₪"
        case "AED":
            return "د.إ"
        case "SAR":
            return "ر.س"
        case "QAR":
            return "ر.ق"
        case "KWD":
            return "د.ك"
        case "BHD":
            return ".د.ب"
        case "OMR":
            return "ر.ع"
        case "EGP":
            return "ج.م"
        case "ZAR":
            return "R"
        case "NGN":
            return "₦"
        case "KES":
            return "KSh"
        case "GHS":
            return "₵"
        case "BRL":
            return "R$"
        case "PEN":
            return "S/"
        case "MYR":
            return "RM"
        case "THB":
            return "฿"
        case "IDR":
            return "Rp"
        case "PHP":
            return "₱"
        case "VND":
            return "₫"
        case "KRW":
            return "₩"
        case "RUB":
            return "₽"
        case "UAH":
            return "₴"
        case "KZT":
            return "₸"
        case "UZS":
            return "soʻm"
        default:
            return currencyCode
        }
    }

    static func isSupported(_ currencyCode: String) -> Bool {
        let supportedCurrencies = [
            "USD", "EUR", "GBP", "INR", "JPY", "CNY", "CAD", "AUD", "CHF", "SEK", "NOK", "DKK",
            "PLN", "CZK", "HUF", "RON", "BGN", "HRK", "RSD", "TRY", "ILS", "AED", "SAR", "QAR",
            "KWD", "BHD", "OMR", "EGP", "ZAR", "NGN", "KES", "GHS", "MXN", "BRL", "ARS", "CLP",
            "COP", "PEN", "UYU", "SGD", "MYR", "THB", "IDR", "PHP", "VND", "KRW", "TWD", "HKD",
            "NZD", "RUB", "UAH", "KZT", "UZS"
        ]
        return supportedCurrencies.contains(currencyCode.uppercased())
    }

    static func name(for currencyCode: String) -> String {
        switch currencyCode.uppercased() {
        case "USD": return "US Dollar"
        case "EUR": return "Euro"
        case "GBP": return "British Pound"
        case "INR": return "Indian Rupee"
        case "JPY": return "Japanese Yen"
        case "CNY": return "Chinese Yuan"
        case "CAD": return "Canadian Dollar"
        case "AUD": return "Australian Dollar"
        case "CHF": return "Swiss Franc"
        case "SEK": return "Swedish Krona"
        case "NOK": return "Norwegian Krone"
        case "DKK": return "Danish Krone"
        case "PLN": return "Polish Złoty"
        case "CZK": return "Czech Koruna"
        case "HUF": return "Hungarian Forint"
        case "RON": return "Romanian Leu"
        case "BGN": return "Bulgarian Lev"
        case "HRK": return "Croatian Kuna"
        case "RSD": return "Serbian Dinar"
        case "TRY": return "Turkish Lira"
        case "ILS": return "Israeli Shekel"
        case "AED": return "UAE Dirham"
        case "SAR": return "Saudi Riyal"
        case "QAR": return "Qatari Riyal"
        case "KWD": return "Kuwaiti Dinar"
        case "BHD": return "Bahraini Dinar"
        case "OMR": return "Omani Rial"
        case "EGP": return "Egyptian Pound"
        case "ZAR": return "South African Rand"
        case "NGN": return "Nigerian Naira"
        case "KES": return "Kenyan Shilling"
        case "GHS": return "Ghanaian Cedi"
        case "MXN": return "Mexican Peso"
        case "BRL": return "Brazilian Real"
        case "ARS": return "Argentine Peso"
        case "CLP": return "Chilean Peso"
        case "COP": return "Colombian Peso"
        case "PEN": return "Peruvian Sol"
        case "UYU": return "Uruguayan Peso"
        case "SGD": return "Singapore Dollar"
        case "MYR": return "Malaysian Ringgit"
        case "THB": return "Thai Baht"
        case "IDR": return "Indonesian Rupiah"
        case "PHP": return "Philippine Peso"
        case "VND": return "Vietnamese Dong"
        case "KRW": return "South Korean Won"
        case "TWD": return "Taiwan Dollar"
        case "HKD": return "Hong Kong Dollar"
        case "NZD": return "New Zealand Dollar"
        case "RUB": return "Russian Ruble"
        case "UAH": return "Ukrainian Hryvnia"
        case "KZT": return "Kazakhstani Tenge"
        case "UZS": return "Uzbekistani Som"
        default: return currencyCode
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

    func formatted(currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency

        // Set locale based on currency for proper formatting
        switch currency {
        case "USD", "CAD", "AUD", "NZD", "MXN":
            formatter.locale = Locale(identifier: "en_US")
        case "EUR":
            formatter.locale = Locale(identifier: "en_DE")
        case "GBP":
            formatter.locale = Locale(identifier: "en_GB")
        case "INR":
            formatter.locale = Locale(identifier: "en_IN")
        case "JPY":
            formatter.locale = Locale(identifier: "ja_JP")
        case "CNY":
            formatter.locale = Locale(identifier: "zh_CN")
        case "CHF":
            formatter.locale = Locale(identifier: "de_CH")
        case "SEK":
            formatter.locale = Locale(identifier: "sv_SE")
        case "NOK":
            formatter.locale = Locale(identifier: "nb_NO")
        case "DKK":
            formatter.locale = Locale(identifier: "da_DK")
        case "PLN":
            formatter.locale = Locale(identifier: "pl_PL")
        case "CZK":
            formatter.locale = Locale(identifier: "cs_CZ")
        case "HUF":
            formatter.locale = Locale(identifier: "hu_HU")
        case "RON":
            formatter.locale = Locale(identifier: "ro_RO")
        case "BGN":
            formatter.locale = Locale(identifier: "bg_BG")
        case "HRK":
            formatter.locale = Locale(identifier: "hr_HR")
        case "RSD":
            formatter.locale = Locale(identifier: "sr_RS")
        case "TRY":
            formatter.locale = Locale(identifier: "tr_TR")
        case "ILS":
            formatter.locale = Locale(identifier: "he_IL")
        case "AED":
            formatter.locale = Locale(identifier: "ar_AE")
        case "SAR":
            formatter.locale = Locale(identifier: "ar_SA")
        case "QAR":
            formatter.locale = Locale(identifier: "ar_QA")
        case "KWD":
            formatter.locale = Locale(identifier: "ar_KW")
        case "BHD":
            formatter.locale = Locale(identifier: "ar_BH")
        case "OMR":
            formatter.locale = Locale(identifier: "ar_OM")
        case "EGP":
            formatter.locale = Locale(identifier: "ar_EG")
        case "ZAR":
            formatter.locale = Locale(identifier: "en_ZA")
        case "NGN":
            formatter.locale = Locale(identifier: "en_NG")
        case "KES":
            formatter.locale = Locale(identifier: "en_KE")
        case "GHS":
            formatter.locale = Locale(identifier: "en_GH")
        case "BRL":
            formatter.locale = Locale(identifier: "pt_BR")
        case "ARS":
            formatter.locale = Locale(identifier: "es_AR")
        case "CLP":
            formatter.locale = Locale(identifier: "es_CL")
        case "COP":
            formatter.locale = Locale(identifier: "es_CO")
        case "PEN":
            formatter.locale = Locale(identifier: "es_PE")
        case "UYU":
            formatter.locale = Locale(identifier: "es_UY")
        case "SGD":
            formatter.locale = Locale(identifier: "en_SG")
        case "MYR":
            formatter.locale = Locale(identifier: "ms_MY")
        case "THB":
            formatter.locale = Locale(identifier: "th_TH")
        case "IDR":
            formatter.locale = Locale(identifier: "id_ID")
        case "PHP":
            formatter.locale = Locale(identifier: "en_PH")
        case "VND":
            formatter.locale = Locale(identifier: "vi_VN")
        case "KRW":
            formatter.locale = Locale(identifier: "ko_KR")
        case "TWD":
            formatter.locale = Locale(identifier: "zh_TW")
        case "HKD":
            formatter.locale = Locale(identifier: "zh_HK")
        case "RUB":
            formatter.locale = Locale(identifier: "ru_RU")
        case "UAH":
            formatter.locale = Locale(identifier: "uk_UA")
        case "KZT":
            formatter.locale = Locale(identifier: "kk_KZ")
        case "UZS":
            formatter.locale = Locale(identifier: "uz_UZ")
        default:
            formatter.locale = Locale(identifier: "en_US_POSIX")
        }

        // Fallback to symbol if locale formatting fails
        if let formatted = formatter.string(from: NSNumber(value: self)) {
            return formatted
        } else {
            // Manual fallback with currency symbols
            let symbol = CurrencyHelper.symbol(for: currency)
            return "\(symbol)\(String(format: "%.2f", self))"
        }
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

    var formattedAmount: String {
        return amount.formatted(currency: currency)
    }

    var formattedTaxAmount: String? {
        guard let taxAmount = taxAmount else { return nil }
        return taxAmount.formatted(currency: currency)
    }

    var formattedSubtotal: String? {
        guard let subtotal = subtotal else { return nil }
        return subtotal.formatted(currency: currency)
    }

    var formattedDiscounts: String? {
        guard let discounts = discounts else { return nil }
        return discounts.formatted(currency: currency)
    }

    var formattedFees: String? {
        guard let fees = fees else { return nil }
        return fees.formatted(currency: currency)
    }

    var formattedTip: String? {
        guard let tip = tip else { return nil }
        return tip.formatted(currency: currency)
    }
}

extension ExpenseItem {
    var unitPriceFormatted: String? {
        guard let unitPrice = unitPrice else { return nil }
        return String(format: "$%.2f", unitPrice)
    }

    func formattedUnitPrice(currency: String) -> String? {
        guard let unitPrice = unitPrice else { return nil }
        return unitPrice.formatted(currency: currency)
    }

    func formattedTotalPrice(currency: String) -> String {
        return totalPrice.formatted(currency: currency)
    }
}
