# Technical Implementation Guide

## Overview

This guide provides detailed technical information about the implementation of item-level expense tracking with comprehensive multi-currency support (50+ currencies) in ReceiptRadar.

## Architecture Changes

### Data Layer Enhancements

#### New Models

```swift
// Enhanced ExpenseItem for detailed item tracking
struct ExpenseItem: Identifiable, Codable {
    let id: UUID
    let name: String               // Item name/description
    let quantity: Double?          // Number of items (optional)
    let unitPrice: Double?         // Price per unit (calculated)
    let totalPrice: Double         // Total price for this item
    let category: String?          // Item-specific category
    let description: String?       // Additional details (size, flavor, etc.)
    
    init(id: UUID = UUID(), name: String, quantity: Double? = nil, 
         unitPrice: Double? = nil, totalPrice: Double, 
         category: String? = nil, description: String? = nil) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice
        self.category = category
        self.description = description
    }
}
```

```swift
// Extended Expense model with financial breakdown
struct Expense: Identifiable, Codable {
    // Existing fields...
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
    
    // NEW: Enhanced item-level tracking
    let items: [ExpenseItem]?       // Array of individual items
    let subtotal: Double?           // Amount before taxes/tips/fees
    let discounts: Double?          // Any discounts applied
    let fees: Double?              // Service fees, delivery fees, etc.
    let tip: Double?               // Tip amount
    let itemsTotal: Double?        // Sum of all item prices
}
```

### AI Processing Enhancements

#### OpenAI Request Structure

```swift
// Enhanced request with increased token limit
let requestBody: [String: Any] = [
    "model": "gpt-4o",
    "messages": [[
        "role": "user",
        "content": [
            ["type": "text", "text": enhancedPrompt],
            ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]]
        ]
    ]],
    "max_tokens": 1000,  // Increased from 500
    "temperature": 0.1
]
```

#### Enhanced AI Prompt

The AI prompt has been optimized for comprehensive extraction:

```swift
private func createExpenseExtractionPrompt() -> String {
    return """
    Extract detailed expense information from this receipt image. Return ONLY valid JSON.

    REQUIRED: date (YYYY-MM-DD), merchant, amount (final total), currency, category
    OPTIONAL: description, paymentMethod, taxAmount, confidence (0.0-1.0)
    
    ITEMS (if clearly visible): Extract individual items with:
    - name: Item name/description
    - quantity: Number of items (if specified)
    - unitPrice: Price per unit (if calculable)
    - totalPrice: Total price for this item
    - category: Item-specific category (Food/Beverage/Product/etc.)
    - description: Additional details
    
    FINANCIAL: subtotal, discounts, fees, tip, itemsTotal
    
    RULES:
    - Extract items ONLY if clearly itemized
    - Use final total for "amount"
    - Ensure financial breakdown adds up
    - Set items to null if unclear
    
    [JSON FORMAT EXAMPLE...]
    """
}
```

#### Error Handling & Recovery

```swift
private func parseExpenseExtraction(from content: String) throws -> OpenAIExpenseExtraction {
    var cleanedContent = content
        .replacingOccurrences(of: "```json", with: "")
        .replacingOccurrences(of: "```", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Check for truncation and attempt repair
    if !cleanedContent.hasSuffix("}") {
        cleanedContent = attemptJSONRepair(cleanedContent)
    }
    
    // Parse with fallback to basic extraction
    do {
        return try JSONDecoder().decode(OpenAIExpenseExtraction.self, from: jsonData)
    } catch {
        if let basicExpense = tryParseBasicExpense(from: cleanedContent) {
            return basicExpense
        }
        throw OpenAIError.responseParsingFailed
    }
}
```

### Enhanced Multi-Currency System Implementation

#### Comprehensive Currency Support
ReceiptRadar now supports 50+ global currencies with intelligent recognition and proper locale formatting.

**Supported Currency Regions:**
- **Americas**: USD, CAD, MXN, BRL, ARS, CLP, COP, PEN, UYU
- **Europe**: EUR, GBP, CHF, SEK, NOK, DKK, PLN, CZK, HUF, RON, BGN, HRK, RSD, TRY
- **Asia-Pacific**: INR, JPY, CNY, SGD, HKD, AUD, NZD, MYR, THB, IDR, PHP, VND, KRW, TWD
- **Middle East & Africa**: AED, SAR, QAR, KWD, BHD, OMR, ILS, EGP, ZAR, NGN, KES, GHS
- **Others**: RUB, UAH, KZT, UZS

#### Advanced Currency Formatting Extension

```swift
extension Double {
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
        // ... 40+ more currency locales
        default:
            formatter.locale = Locale(identifier: "en_US_POSIX")
        }

        // Fallback to symbol if locale formatting fails
        if let formatted = formatter.string(from: NSNumber(value: self)) {
            return formatted
        } else {
            let symbol = CurrencyHelper.symbol(for: currency)
            return "\(symbol)\(String(format: "%.2f", self))"
        }
    }
}
```

#### Currency Helper Implementation

```swift
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
        case "TRY":
            return "₺"
        case "RUB":
            return "₽"
        case "NGN":
            return "₦"
        // ... 30+ more currency symbols
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
}
```

#### Expense Currency Extensions

```swift
extension Expense {
    var formattedAmount: String {
        return amount.formatted(currency: currency)
    }
    
    var formattedTaxAmount: String? {
        guard let taxAmount = taxAmount else { return nil }
        return taxAmount.formatted(currency: currency)
    }
    
    // Additional formatting methods for all financial fields...
}
```

#### Primary Currency Logic

```swift
func getPrimaryCurrency() -> String {
    let currencyGroups = Dictionary(grouping: expenses) { $0.currency }
    let mostCommonCurrency = currencyGroups.max { a, b in 
        a.value.count < b.value.count 
    }?.key
    return mostCommonCurrency ?? "USD"
}
```

### User Interface Enhancements

#### Expandable Expense Row

```swift
struct ExpenseRowView: View {
    let expense: Expense
    @State private var showingItemDetails = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main expense summary
            HStack {
                // Category icon and expense details
                // Amount display with proper currency formatting
                Text(expense.formattedAmount)
                
                // Expand/collapse button
                if expense.items != nil && !expense.items!.isEmpty {
                    Button(action: { showingItemDetails.toggle() }) {
                        Image(systemName: showingItemDetails ? "chevron.up" : "chevron.down")
                    }
                }
            }
            
            // Expandable item details
            if showingItemDetails, let items = expense.items {
                ItemDetailsView(items: items, currency: expense.currency)
                FinancialBreakdownView(expense: expense)
            }
        }
    }
}
```

#### Item Details Component

```swift
struct ItemDetailsView: View {
    let items: [ExpenseItem]
    let currency: String
    
    var body: some View {
        VStack(spacing: 6) {
            ForEach(items) { item in
                HStack {
                    VStack(alignment: .leading) {
                        Text(item.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if let description = item.description {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let category = item.category {
                            CategoryBadge(category: category)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        if let quantity = item.quantity, quantity != 1 {
                            Text("\(quantity, specifier: "%.1f")x")
                                .font(.caption)
                        }
                        
                        Text(item.formattedTotalPrice(currency: currency))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
        }
    }
}
```

### Analytics Implementation

#### Item-Level Analytics Methods

```swift
// MARK: - Item-Level Analytics

func getItemsFromExpenses() -> [ExpenseItem] {
    return expenses.compactMap { $0.items }.flatMap { $0 }
}

func getTopItems(limit: Int = 10) -> [(item: String, totalSpent: Double, count: Int)] {
    let allItems = getItemsFromExpenses()
    let itemGroups = Dictionary(grouping: allItems) { $0.name.lowercased() }
    
    return itemGroups.map { (name, items) in
        let totalSpent = items.reduce(0) { $0 + $1.totalPrice }
        let count = items.count
        return (item: items.first?.name ?? name, totalSpent: totalSpent, count: count)
    }
    .sorted { $0.totalSpent > $1.totalSpent }
    .prefix(limit)
    .map { $0 }
}

func getSpendingByItemCategory() -> [String: Double] {
    let allItems = getItemsFromExpenses()
    let categoryGroups = Dictionary(grouping: allItems) { $0.category ?? "Other" }
    
    return categoryGroups.mapValues { items in
        items.reduce(0) { $0 + $1.totalPrice }
    }
}

func getAverageItemPrice(for itemName: String) -> Double? {
    let matchingItems = getItemsFromExpenses().filter { 
        $0.name.lowercased().contains(itemName.lowercased()) 
    }
    
    guard !matchingItems.isEmpty else { return nil }
    
    let totalPrice = matchingItems.reduce(0) { $0 + $1.totalPrice }
    return totalPrice / Double(matchingItems.count)
}
```

### Data Migration Strategy

#### Backward Compatibility

All new fields in the `Expense` model are optional, ensuring existing data continues to work:

```swift
// Existing expenses without items
let oldExpense = Expense(
    date: Date(),
    merchant: "Old Store",
    amount: 10.00,
    currency: "USD",
    category: "Shopping"
    // items: nil (default)
    // subtotal: nil (default)
    // etc.
)

// New expenses with full item details
let newExpense = Expense(
    date: Date(),
    merchant: "New Store",
    amount: 25.50,
    currency: "EUR",
    category: "Food & Dining",
    items: [ExpenseItem(name: "Coffee", totalPrice: 4.50)],
    subtotal: 23.85,
    taxAmount: 1.65
)
```

#### UserDefaults Storage

The existing UserDefaults storage system handles the new fields automatically due to Codable implementation:

```swift
// Storage remains the same
private func saveExpensesToUserDefaults() {
    if let data = try? JSONEncoder().encode(expenses) {
        userDefaults.set(data, forKey: expensesKey)
    }
}

private func loadExpensesFromUserDefaults() {
    if let data = userDefaults.data(forKey: expensesKey),
       let decodedExpenses = try? JSONDecoder().decode([Expense].self, from: data) {
        self.expenses = decodedExpenses
    }
}
```

### Performance Considerations

#### Token Usage Optimization

- **Before**: 300-500 tokens per request
- **After**: 300-1000 tokens per request
- **Optimization**: Compressed prompt while maintaining functionality

#### Memory Management

```swift
// Efficient item processing
func processReceiptPhotos(_ photoItems: [PhotosPickerItem]) async -> Int {
    var processedCount = 0
    
    for photoItem in photoItems {
        // Process one item at a time to manage memory
        autoreleasepool {
            // Image processing and AI calls
        }
        
        // Yield between items for UI responsiveness
        await Task.yield()
    }
    
    return processedCount
}
```

#### UI Performance

```swift
// Lazy loading for large datasets
LazyVStack(spacing: 12) {
    ForEach(filteredExpenses) { expense in
        ExpenseRowView(expense: expense)
            .onAppear {
                // Load additional data if needed
            }
    }
}
```

### Error Handling Strategy

#### Comprehensive Error Types

```swift
enum OpenAIError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case requestEncodingFailed
    case invalidResponse
    case invalidAPIKey
    case apiError(Int)
    case noResponseContent
    case responseParsingFailed
    case imageProcessingFailed
    case responseTruncated  // New error type
    
    var errorDescription: String? {
        switch self {
        case .responseTruncated:
            return "Response was truncated - try with a simpler receipt"
        // ... other cases
        }
    }
}
```

#### User-Friendly Error Messages

```swift
// Specific error handling with user guidance
if let openAIError = error as? OpenAIError {
    switch openAIError {
    case .invalidAPIKey:
        errorMessage = "Invalid OpenAI API key. Please check your credentials."
    case .apiError(let code):
        errorMessage = "OpenAI API error (Status \(code)). Check your API key and quota."
    case .responseParsingFailed:
        errorMessage = "Failed to parse receipt data. The response may be incomplete - try a clearer image."
    case .responseTruncated:
        errorMessage = "Receipt has too many items for processing. Try a simpler receipt."
    default:
        errorMessage = "OpenAI processing failed: \(openAIError.localizedDescription)"
    }
}
```

### Testing Strategy

#### Unit Tests Structure

```swift
class ExpenseServiceTests: XCTestCase {
    func testItemLevelAnalytics() {
        // Test item aggregation and analytics
    }
    
    func testCurrencyFormatting() {
        // Test currency display for various currencies
    }
    
    func testJSONParsing() {
        // Test AI response parsing with various formats
    }
    
    func testErrorRecovery() {
        // Test truncation handling and fallback parsing
    }
}
```

#### Sample Test Data

```swift
let sampleExpenseWithItems = Expense(
    merchant: "Test Store",
    amount: 25.50,
    currency: "EUR",
    category: "Shopping",
    items: [
        ExpenseItem(name: "Test Item 1", quantity: 2, totalPrice: 10.00),
        ExpenseItem(name: "Test Item 2", quantity: 1, totalPrice: 15.50)
    ],
    subtotal: 25.50
)
```

### Future Enhancement Architecture

#### Extensibility Points

1. **Storage Layer**: Ready for Core Data migration
2. **Currency System**: Prepared for real-time exchange rates
3. **Analytics**: Foundation for machine learning insights
4. **Export System**: Structured for multiple export formats

#### Plugin Architecture Preparation

```swift
protocol ExpenseProcessor {
    func processReceipt(_ image: UIImage) async throws -> OpenAIExpenseExtraction
}

protocol AnalyticsProvider {
    func generateInsights(from expenses: [Expense]) -> [Insight]
}

protocol ExportProvider {
    func exportExpenses(_ expenses: [Expense], format: ExportFormat) -> Data
}
```

---

This technical guide provides the foundation for understanding and extending the item-level tracking implementation. The architecture is designed for scalability, maintainability, and future enhancements while maintaining backward compatibility and user privacy.
