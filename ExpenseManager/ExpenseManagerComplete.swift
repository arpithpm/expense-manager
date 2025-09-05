import Foundation
import SwiftUI
import Combine
import PhotosUI
import UIKit
import Security

// MARK: - Models and Data Structures

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


// MARK: - Services

class KeychainService {
    static let shared = KeychainService()
    private init() {}
    
    private let service = "com.yourcompany.ExpenseManager"
    
    enum KeychainKey: String {
        case openaiKey = "openai_key"
    }
    
    func save(_ value: String, for key: KeychainKey) -> Bool {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func retrieve(for key: KeychainKey) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
    
    func delete(for key: KeychainKey) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
    
    func deleteAll() -> Bool {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(deleteQuery as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // Convenience methods for API key management
    func saveAPIKey(_ key: String) -> Bool {
        return save(key, for: .openaiKey)
    }
    
    func getAPIKey() -> String? {
        return retrieve(for: .openaiKey)
    }
    
    func deleteAPIKey() throws {
        let success = delete(for: .openaiKey)
        if !success {
            throw NSError(domain: "KeychainError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to delete API key from keychain"])
        }
    }
    
    func hasValidAPIKey() -> Bool {
        return getAPIKey() != nil
    }
}

@MainActor
class ConfigurationManager: ObservableObject {
    @Published var isConfigured: Bool = false
    @Published var isTestingConnection: Bool = false
    @Published var connectionStatus: ConnectionStatus = .notTested
    
    private let keychain = KeychainService.shared
    
    enum ConnectionStatus {
        case notTested, testing, success, failure(String)
    }
    
    init() {
        checkConfiguration()
    }
    
    private func checkConfiguration() {
        let hasOpenAIKey = keychain.retrieve(for: .openaiKey) != nil
        isConfigured = hasOpenAIKey
    }
    
    func saveConfiguration(openaiKey: String) async -> Bool {
        let trimmedOpenAIKey = openaiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedOpenAIKey.isEmpty else {
            return false
        }
        
        let openaiKeySaved = keychain.save(trimmedOpenAIKey, for: .openaiKey)
        
        if openaiKeySaved {
            checkConfiguration()
            return true
        }
        return false
    }
    
    func testConnections() async {
        connectionStatus = .testing
        isTestingConnection = true
        
        let openaiResult = await testOpenAIConnection()
        
        isTestingConnection = false
        
        if openaiResult.success {
            connectionStatus = .success
        } else {
            connectionStatus = .failure(openaiResult.error ?? "Unknown error")
        }
    }
    
    
    private func testOpenAIConnection() async -> (success: Bool, error: String?) {
        guard let key = keychain.retrieve(for: .openaiKey),
              let url = URL(string: "https://api.openai.com/v1/models") else {
            return (false, "Invalid OpenAI credentials")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    return (true, nil)
                } else if httpResponse.statusCode == 401 {
                    return (false, "Invalid OpenAI API key")
                } else {
                    return (false, "OpenAI connection failed (Status: \(httpResponse.statusCode))")
                }
            }
            return (false, "Invalid response from OpenAI")
        } catch {
            return (false, "OpenAI connection error: \(error.localizedDescription)")
        }
    }
    
    func clearConfiguration() {
        _ = keychain.deleteAll()
        checkConfiguration()
        connectionStatus = .notTested
    }
    
    func getOpenAIKey() -> String? { keychain.retrieve(for: .openaiKey) }
}


class OpenAIService {
    static let shared = OpenAIService()
    private init() {}
    
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    func extractExpenseFromReceipt(_ image: UIImage) async throws -> OpenAIExpenseExtraction {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw OpenAIError.imageProcessingFailed
        }
        
        let base64Image = imageData.base64EncodedString()
        let prompt = createExpenseExtractionPrompt()
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "text", "text": prompt],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]]
                ]
            ]],
            "max_tokens": 1000,  // Increased from 500 to handle item-level details
            "temperature": 0.1
        ]
        
        guard let apiKey = KeychainService.shared.retrieve(for: .openaiKey),
              let url = URL(string: baseURL) else {
            throw OpenAIError.missingAPIKey
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw OpenAIError.requestEncodingFailed
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw OpenAIError.invalidAPIKey
        } else if httpResponse.statusCode != 200 {
            // Log the response body for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("OpenAI API Error (\(httpResponse.statusCode)): \(responseString)")
            }
            throw OpenAIError.apiError(httpResponse.statusCode)
        }
        
        do {
            let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            guard let content = openAIResponse.choices.first?.message.content else {
                throw OpenAIError.noResponseContent
            }
            
            // Check if the response was truncated due to token limit
            if let finishReason = openAIResponse.choices.first?.finishReason, finishReason == "length" {
                print("Warning: OpenAI response was truncated due to token limit")
                // Continue processing but with awareness that it might be incomplete
            }
            
            print("OpenAI Response Content: \(content)")
            return try parseExpenseExtraction(from: content)
        } catch {
            // Log the raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw OpenAI Response: \(responseString)")
            }
            if error is OpenAIError { throw error }
            print("JSON Parsing Error: \(error)")
            throw OpenAIError.responseParsingFailed
        }
    }
    
    private func createExpenseExtractionPrompt() -> String {
        return """
        Extract detailed expense information from this receipt image. Return ONLY valid JSON (no markdown, no text).

        REQUIRED: date (YYYY-MM-DD), merchant, amount (final total), currency (default USD), category from: Food & Dining, Transportation, Shopping, Entertainment, Bills & Utilities, Healthcare, Travel, Education, Business, Other

        OPTIONAL: description, paymentMethod, taxAmount, confidence (0.0-1.0)

        ITEMS (if clearly visible): Extract individual items with: name, quantity, unitPrice, totalPrice, category (Food/Beverage/Product/Service/etc), description

        FINANCIAL: subtotal, discounts, fees, tip, itemsTotal

        RULES:
        - Extract items ONLY if clearly itemized
        - Use final total for "amount"
        - Item categories: Food, Beverage, Product, Service, Electronics, Household, etc.
        - If unclear, set items to null
        - Ensure financial breakdown adds up

        JSON FORMAT:
        {
            "date": "YYYY-MM-DD",
            "merchant": "Store Name",
            "amount": 99.99,
            "currency": "USD",
            "category": "Shopping",
            "description": "Brief description",
            "paymentMethod": "Credit Card",
            "taxAmount": 8.25,
            "confidence": 0.85,
            "items": [
                {
                    "name": "Item Name",
                    "quantity": 1,
                    "unitPrice": 10.00,
                    "totalPrice": 10.00,
                    "category": "Product",
                    "description": "Additional details"
                }
            ],
            "subtotal": 91.74,
            "discounts": null,
            "fees": null,
            "tip": null,
            "itemsTotal": 91.74
        }

        For unclear receipts, set items/breakdown to null and extract basic expense info only.
        """
    }
    
    private func parseExpenseExtraction(from content: String) throws -> OpenAIExpenseExtraction {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code blocks if present
        var cleanedContent = trimmedContent
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("Cleaned content for parsing: \(cleanedContent)")
        
        // Check if the JSON might be truncated (common issue with token limits)
        if !cleanedContent.hasSuffix("}") {
            print("Warning: JSON appears to be truncated. Attempting to fix...")
            
            // Try to fix common truncation issues
            var fixedContent = cleanedContent
            
            // If it ends with a quote and comma, likely truncated in the middle of an item
            if fixedContent.hasSuffix("\",") || fixedContent.hasSuffix("\"") {
                // Find the last complete item and close the array properly
                if let lastCompleteItemIndex = fixedContent.lastIndex(of: "}") {
                    let truncationPoint = fixedContent.index(after: lastCompleteItemIndex)
                    fixedContent = String(fixedContent[..<truncationPoint])
                    
                    // Close the items array and main object
                    if fixedContent.contains("\"items\": [") && !fixedContent.contains("]") {
                        fixedContent += "\n    ],\n    \"subtotal\": null,\n    \"discounts\": null,\n    \"fees\": null,\n    \"tip\": null,\n    \"itemsTotal\": null\n}"
                    } else {
                        fixedContent += "\n}"
                    }
                    
                    print("Attempted to fix truncated JSON: \(fixedContent)")
                }
            }
            
            cleanedContent = fixedContent
        }
        
        guard let jsonData = cleanedContent.data(using: .utf8) else {
            print("Failed to convert to data")
            throw OpenAIError.responseParsingFailed
        }
        
        do {
            let decoder = JSONDecoder()
            // Handle potential null values gracefully
            return try decoder.decode(OpenAIExpenseExtraction.self, from: jsonData)
        } catch {
            print("JSON Decoding Error: \(error)")
            
            // If we still have parsing issues, try to extract basic expense info without items
            if let basicExpense = tryParseBasicExpense(from: cleanedContent) {
                print("Falling back to basic expense extraction without items")
                return basicExpense
            }
            
            throw OpenAIError.responseParsingFailed
        }
    }
    
    // Fallback method to extract basic expense info if item parsing fails
    private func tryParseBasicExpense(from content: String) -> OpenAIExpenseExtraction? {
        // Try to extract just the basic fields without items using regex or simple parsing
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // Extract required fields
        guard let date = json["date"] as? String,
              let merchant = json["merchant"] as? String,
              let amount = json["amount"] as? Double,
              let currency = json["currency"] as? String,
              let category = json["category"] as? String else {
            return nil
        }
        
        // Create basic expense without items
        return OpenAIExpenseExtraction(
            date: date,
            merchant: merchant,
            amount: amount,
            currency: currency,
            category: category,
            description: json["description"] as? String,
            paymentMethod: json["paymentMethod"] as? String,
            taxAmount: json["taxAmount"] as? Double,
            confidence: json["confidence"] as? Double ?? 0.7,
            items: nil, // No items due to parsing failure
            subtotal: json["subtotal"] as? Double,
            discounts: json["discounts"] as? Double,
            fees: json["fees"] as? Double,
            tip: json["tip"] as? Double,
            itemsTotal: json["itemsTotal"] as? Double
        )
    }
}

enum OpenAIError: LocalizedError {
    case missingAPIKey, invalidURL, requestEncodingFailed, invalidResponse
    case invalidAPIKey, apiError(Int), noResponseContent, responseParsingFailed, imageProcessingFailed
    case responseTruncated
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "OpenAI API key not found"
        case .invalidURL: return "Invalid OpenAI API URL"
        case .requestEncodingFailed: return "Failed to encode request"
        case .invalidResponse: return "Invalid response from OpenAI"
        case .invalidAPIKey: return "Invalid OpenAI API key"
        case .apiError(let code): return "OpenAI API error (Status: \(code))"
        case .noResponseContent: return "No content in OpenAI response"
        case .responseParsingFailed: return "Failed to parse OpenAI response"
        case .imageProcessingFailed: return "Failed to process image"
        case .responseTruncated: return "Response was truncated - try with a simpler receipt"
        }
    }
}


@MainActor
class ExpenseService: ObservableObject {
    static let shared = ExpenseService()
    
    @Published var expenses: [Expense] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let openAIService = OpenAIService.shared
    private let userDefaults = UserDefaults.standard
    private let expensesKey = "SavedExpenses"
    private let lastBackupKey = "LastBackupDate"
    private let firstLaunchKey = "HasLaunchedBefore"
    
    private init() {
        loadExpensesFromUserDefaults()
        // Set initial backup timestamp if we have data but no backup date
        if !expenses.isEmpty && userDefaults.object(forKey: lastBackupKey) == nil {
            userDefaults.set(Date(), forKey: lastBackupKey)
        }
        
        // Add sample data on first launch if no expenses exist
        if expenses.isEmpty && !hasLaunchedBefore() {
            addSampleExpenses()
            markFirstLaunchComplete()
        }
    }
    
    func processReceiptPhotos(_ photoItems: [PhotosPickerItem]) async -> Int {
        var processedCount = 0
        
        for photoItem in photoItems {
            do {
                // Debug PhotosPickerItem properties
                let assetIdentifier = photoItem.itemIdentifier
                print("Captured asset identifier during processing: \(assetIdentifier ?? "nil")")
                print("PhotosPickerItem supportedContentTypes: \(photoItem.supportedContentTypes)")
                
                if let imageData = try await loadImageData(from: photoItem),
                   let image = UIImage(data: imageData) {
                    
                    let extractedData = try await openAIService.extractExpenseFromReceipt(image)
                    let expense = try createExpenseFromExtraction(extractedData)
                    
                    // Save expense locally
                    _ = addExpense(expense)
                    
                    processedCount += 1
                }
            } catch {
                print("Failed to process photo: \(error)")
                // Provide more specific error messages based on error type
                if let openAIError = error as? OpenAIError {
                    switch openAIError {
                    case .invalidAPIKey:
                        errorMessage = "Invalid OpenAI API key. Please check your credentials."
                    case .apiError(let code):
                        errorMessage = "OpenAI API error (Status \(code)). Check your API key and quota."
                    case .missingAPIKey:
                        errorMessage = "OpenAI API key not found. Please configure in settings."
                    case .responseParsingFailed:
                        errorMessage = "Failed to parse receipt data. The response may be incomplete - try a clearer image or simpler receipt."
                    case .responseTruncated:
                        errorMessage = "Receipt has too many items for processing. Try processing a simpler receipt."
                    default:
                        errorMessage = "OpenAI processing failed: \(openAIError.localizedDescription)"
                    }
                } else {
                    errorMessage = "Processing failed: \(error.localizedDescription)"
                }
            }
        }
        
        
        return processedCount
    }
    
    private func loadImageData(from photoItem: PhotosPickerItem) async throws -> Data? {
        return try await withCheckedThrowingContinuation { continuation in
            photoItem.loadTransferable(type: Data.self) { result in
                switch result {
                case .success(let data): continuation.resume(returning: data)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func createExpenseFromExtraction(_ extraction: OpenAIExpenseExtraction) throws -> Expense {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let expenseDate = dateFormatter.date(from: extraction.date) ?? Date()
        
        // Convert OpenAI items to ExpenseItems
        let expenseItems: [ExpenseItem]? = extraction.items?.map { openAIItem in
            ExpenseItem(
                name: openAIItem.name,
                quantity: openAIItem.quantity,
                unitPrice: openAIItem.unitPrice,
                totalPrice: openAIItem.totalPrice,
                category: openAIItem.category,
                description: openAIItem.description
            )
        }
        
        return Expense(
            date: expenseDate,
            merchant: extraction.merchant,
            amount: extraction.amount,
            currency: extraction.currency,
            category: extraction.category,
            description: extraction.description,
            paymentMethod: extraction.paymentMethod,
            taxAmount: extraction.taxAmount,
            items: expenseItems,
            subtotal: extraction.subtotal,
            discounts: extraction.discounts,
            fees: extraction.fees,
            tip: extraction.tip,
            itemsTotal: extraction.itemsTotal
        )
    }
    
    func fetchRecentExpenses(limit: Int = 10) async throws -> [Expense] {
        isLoading = true
        errorMessage = nil
        
        let recentExpenses = Array(expenses.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
        isLoading = false
        return recentExpenses
    }
    
    func getTotalExpenses() -> Double {
        return expenses.reduce(0) { $0 + $1.amount }
    }
    
    func getMonthlyTotal() -> Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
        
        return expenses.filter { expense in
            expense.date >= startOfMonth && expense.date < endOfMonth
        }.reduce(0) { $0 + $1.amount }
    }
    
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
    
    func getItemFrequency() -> [String: Int] {
        let allItems = getItemsFromExpenses()
        let itemGroups = Dictionary(grouping: allItems) { $0.name.lowercased() }
        
        return itemGroups.mapValues { $0.count }
    }
    
    // MARK: - Currency Handling
    
    func getPrimaryCurrency() -> String {
        // Get the most common currency in expenses
        let currencyGroups = Dictionary(grouping: expenses) { $0.currency }
        let mostCommonCurrency = currencyGroups.max { a, b in a.value.count < b.value.count }?.key
        return mostCommonCurrency ?? "USD"
    }
    
    func getTotalInPrimaryCurrency() -> Double {
        // For simplicity, we'll just sum all expenses regardless of currency
        // In a real app, you'd want to convert currencies
        return expenses.reduce(0) { $0 + $1.amount }
    }
    
    func getMonthlyTotalInPrimaryCurrency() -> Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
        
        return expenses.filter { expense in
            expense.date >= startOfMonth && expense.date < endOfMonth
        }.reduce(0) { $0 + $1.amount }
    }
    
    // MARK: - Local Storage Methods
    
    private func loadExpensesFromUserDefaults() {
        if let data = userDefaults.data(forKey: expensesKey),
           let decodedExpenses = try? JSONDecoder().decode([Expense].self, from: data) {
            self.expenses = decodedExpenses
        }
    }
    
    func saveExpensesToUserDefaults() {
        if let data = try? JSONEncoder().encode(expenses) {
            userDefaults.set(data, forKey: expensesKey)
            // Update backup timestamp when data is saved
            userDefaults.set(Date(), forKey: lastBackupKey)
        }
    }
    
    func addExpense(_ expense: Expense) -> Expense {
        expenses.append(expense)
        saveExpensesToUserDefaults()
        return expense
    }
    
    func deleteExpense(_ expense: Expense) {
        expenses.removeAll { $0.id == expense.id }
        saveExpensesToUserDefaults()
    }
    
    // MARK: - Backup Status Methods
    
    func getLastBackupDate() -> Date? {
        return userDefaults.object(forKey: lastBackupKey) as? Date
    }
    
    func isDataBackedUp() -> Bool {
        // Consider data backed up if there's a recent backup (within last 24 hours) and we have expenses
        guard let lastBackup = getLastBackupDate() else { return false }
        let twentyFourHoursAgo = Date().addingTimeInterval(-24 * 60 * 60)
        return lastBackup > twentyFourHoursAgo && !expenses.isEmpty
    }
    
    func getBackupStatus() -> BackupStatus {
        if expenses.isEmpty {
            return .noData
        }
        
        guard let lastBackup = getLastBackupDate() else {
            return .notBackedUp
        }
        
        let now = Date()
        let timeSinceBackup = now.timeIntervalSince(lastBackup)
        
        if timeSinceBackup < 60 * 60 { // Less than 1 hour
            return .current
        } else if timeSinceBackup < 24 * 60 * 60 { // Less than 24 hours
            return .recent
        } else {
            return .outdated
        }
    }
    
    // MARK: - First Launch Tracking
    
    private func hasLaunchedBefore() -> Bool {
        return userDefaults.bool(forKey: firstLaunchKey)
    }
    
    private func markFirstLaunchComplete() {
        userDefaults.set(true, forKey: firstLaunchKey)
    }
    
    // MARK: - Sample Data for First Launch
    
    private func addSampleExpenses() {
        let calendar = Calendar.current
        let now = Date()
        
        let sampleExpenses = [
            Expense(
                date: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                merchant: "Starbucks Coffee",
                amount: 4.75,
                currency: "USD",
                category: "Food & Dining",
                description: "Morning coffee and pastry",
                paymentMethod: "Credit Card",
                taxAmount: 0.38,
                items: [
                    ExpenseItem(name: "Grande Latte", quantity: 1, unitPrice: 4.75, totalPrice: 4.75, category: "Beverage", description: "Oat milk"),
                    ExpenseItem(name: "Blueberry Muffin", quantity: 1, unitPrice: 2.95, totalPrice: 2.95, category: "Food", description: "Warmed")
                ],
                subtotal: 7.70,
                tip: 1.15,
                itemsTotal: 7.70
            ),
            Expense(
                date: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
                merchant: "Shell Gas Station",
                amount: 45.20,
                currency: "USD",
                category: "Transportation",
                description: "Fuel",
                paymentMethod: "Debit Card",
                taxAmount: 3.62,
                items: [
                    ExpenseItem(name: "Regular Gasoline", quantity: 12.5, unitPrice: 3.45, totalPrice: 43.13, category: "Fuel", description: "12.5 gallons")
                ],
                subtotal: 43.13,
                fees: 2.07,
                itemsTotal: 43.13
            ),
            Expense(
                date: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
                merchant: "Tesco Extra",
                amount: 28.50,
                currency: "EUR",
                category: "Shopping",
                description: "Grocery shopping",
                paymentMethod: "Credit Card",
                taxAmount: 2.85,
                items: [
                    ExpenseItem(name: "Organic Bananas", quantity: 1.2, unitPrice: 2.99, totalPrice: 3.59, category: "Food", description: "1.2 kg"),
                    ExpenseItem(name: "Whole Milk", quantity: 2, unitPrice: 1.25, totalPrice: 2.50, category: "Food", description: "1L cartons"),
                    ExpenseItem(name: "Bread Loaf", quantity: 1, unitPrice: 1.89, totalPrice: 1.89, category: "Food", description: "Whole grain")
                ],
                subtotal: 25.65,
                itemsTotal: 7.98
            ),
            Expense(
                date: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
                merchant: "Target",
                amount: 23.99,
                currency: "USD",
                category: "Shopping",
                description: "Household items",
                paymentMethod: "Credit Card",
                taxAmount: 1.92,
                items: [
                    ExpenseItem(name: "Tide Laundry Detergent", quantity: 1, unitPrice: 12.99, totalPrice: 12.99, category: "Household", description: "64 oz"),
                    ExpenseItem(name: "Paper Towels", quantity: 2, unitPrice: 4.50, totalPrice: 9.00, category: "Household", description: "6-pack")
                ],
                subtotal: 21.99,
                itemsTotal: 21.99
            ),
            Expense(
                date: calendar.date(byAdding: .day, value: -5, to: now) ?? now,
                merchant: "Chipotle Mexican Grill",
                amount: 12.85,
                currency: "USD",
                category: "Food & Dining",
                description: "Burrito bowl and drink",
                paymentMethod: "Digital Payment",
                taxAmount: 1.03,
                items: [
                    ExpenseItem(name: "Chicken Burrito Bowl", quantity: 1, unitPrice: 9.45, totalPrice: 9.45, category: "Food", description: "Brown rice, black beans, mild salsa"),
                    ExpenseItem(name: "Fountain Drink", quantity: 1, unitPrice: 2.75, totalPrice: 2.75, category: "Beverage", description: "Large")
                ],
                subtotal: 12.20,
                itemsTotal: 12.20
            ),
            Expense(
                date: calendar.date(byAdding: .day, value: -7, to: now) ?? now,
                merchant: "Amazon.com",
                amount: 89.99,
                currency: "USD",
                category: "Shopping",
                description: "Office supplies",
                paymentMethod: "Credit Card",
                taxAmount: 7.20,
                items: [
                    ExpenseItem(name: "Wireless Mouse", quantity: 1, unitPrice: 29.99, totalPrice: 29.99, category: "Electronics", description: "Logitech MX Master 3"),
                    ExpenseItem(name: "USB-C Hub", quantity: 1, unitPrice: 45.99, totalPrice: 45.99, category: "Electronics", description: "7-in-1"),
                    ExpenseItem(name: "Notebook", quantity: 3, unitPrice: 4.99, totalPrice: 14.97, category: "Office", description: "Lined, A5 size")
                ],
                subtotal: 90.95,
                discounts: -8.16,
                itemsTotal: 90.95
            )
        ]
        
        for expense in sampleExpenses {
            expenses.append(expense)
        }
        
        saveExpensesToUserDefaults()
        print("Added \(sampleExpenses.count) sample expenses with item details for first launch")
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

// MARK: - Currency Formatting Extension

extension Double {
    func formatted(currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        
        return formatter.string(from: NSNumber(value: self)) ?? "\(currency) \(String(format: "%.2f", self))"
    }
}

extension Expense {
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
    func formattedTotalPrice(currency: String) -> String {
        return totalPrice.formatted(currency: currency)
    }
    
    func formattedUnitPrice(currency: String) -> String? {
        guard let unitPrice = unitPrice else { return nil }
        return unitPrice.formatted(currency: currency)
    }
}

// MARK: - Data Reset Manager
class DataResetManager: ObservableObject {
    static let shared = DataResetManager()
    
    enum ResetCategory: String, CaseIterable {
        case allExpenses = "All Expenses"
        case sampleExpenses = "Sample Expenses Only"
        case analyticsCache = "Analytics Cache"
        case openAIKey = "OpenAI API Key"
        case openAIHistory = "OpenAI Usage History"
        case userPreferences = "User Preferences"
        case firstLaunchFlag = "First Launch Flag"
        case backupData = "Backup Timestamps"
        case completeReset = "Complete Reset (Everything)"
        
        var description: String {
            switch self {
            case .allExpenses:
                return "Remove all stored expenses from the app"
            case .sampleExpenses:
                return "Remove only the sample/demo expenses"
            case .analyticsCache:
                return "Clear cached analytics and calculations"
            case .openAIKey:
                return "Remove stored OpenAI API key from Keychain"
            case .openAIHistory:
                return "Clear OpenAI usage history and cache"
            case .userPreferences:
                return "Reset app settings to defaults"
            case .firstLaunchFlag:
                return "Reset first launch flag (will show sample data again)"
            case .backupData:
                return "Clear backup timestamps and sync data"
            case .completeReset:
                return "Reset everything - returns app to fresh install state"
            }
        }
        
        var icon: String {
            switch self {
            case .allExpenses, .sampleExpenses:
                return "trash"
            case .analyticsCache:
                return "chart.bar"
            case .openAIKey:
                return "key"
            case .openAIHistory:
                return "clock.arrow.circlepath"
            case .userPreferences:
                return "gearshape"
            case .firstLaunchFlag:
                return "flag"
            case .backupData:
                return "icloud"
            case .completeReset:
                return "trash.circle"
            }
        }
        
        var isDestructive: Bool {
            switch self {
            case .allExpenses, .openAIKey, .completeReset:
                return true
            default:
                return false
            }
        }
    }
    
    private let keychainService = KeychainService.shared
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    @MainActor
    func resetData(categories: Set<ResetCategory>) async throws {
        let expenseService = ExpenseService.shared
        for category in categories {
            try await resetCategory(category, expenseService: expenseService)
        }
    }
    
    @MainActor
    private func resetCategory(_ category: ResetCategory, expenseService: ExpenseService) async throws {
        switch category {
        case .allExpenses:
            expenseService.expenses.removeAll()
            expenseService.saveExpensesToUserDefaults()
            
        case .sampleExpenses:
            let sampleMerchants = ["Sample Grocery Store", "Demo Restaurant", "Test Gas Station", 
                                 "Example Coffee Shop", "Sample Pharmacy"]
            expenseService.expenses.removeAll { expense in
                sampleMerchants.contains(expense.merchant)
            }
            expenseService.saveExpensesToUserDefaults()
            
        case .analyticsCache:
            // Clear any cached analytics (if we had any)
            // For now, this is mostly a placeholder as analytics are calculated on-demand
            break
            
        case .openAIKey:
            try keychainService.deleteAPIKey()
            
        case .openAIHistory:
            // Clear any OpenAI usage history (placeholder for future implementation)
            userDefaults.removeObject(forKey: "OpenAIUsageHistory")
            userDefaults.removeObject(forKey: "OpenAILastUsed")
            
        case .userPreferences:
            // Remove app-specific settings while preserving system settings
            let keysToRemove = ["LastBackupDate", "UserSelectedCurrency", 
                              "NotificationsEnabled", "AppTheme"]
            for key in keysToRemove {
                userDefaults.removeObject(forKey: key)
            }
            
        case .firstLaunchFlag:
            userDefaults.removeObject(forKey: "HasLaunchedBefore")
            
        case .backupData:
            userDefaults.removeObject(forKey: "LastBackupDate")
            userDefaults.removeObject(forKey: "BackupStatus")
            
        case .completeReset:
            // Reset everything
            expenseService.expenses.removeAll()
            expenseService.saveExpensesToUserDefaults()
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
        let expenseService = ExpenseService.shared
        switch category {
        case .allExpenses:
            return expenseService.expenses.count
        case .sampleExpenses:
            let sampleMerchants = ["Sample Grocery Store", "Demo Restaurant", "Test Gas Station", 
                                 "Example Coffee Shop", "Sample Pharmacy"]
            return expenseService.expenses.filter { expense in
                sampleMerchants.contains(expense.merchant)
            }.count
        case .openAIKey:
            return keychainService.hasValidAPIKey() ? 1 : 0
        case .userPreferences, .firstLaunchFlag, .backupData, .analyticsCache, .openAIHistory:
            return 1 // These are single settings
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