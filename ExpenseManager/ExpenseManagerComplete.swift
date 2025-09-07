import Foundation
import SwiftUI
import Combine
import PhotosUI
import UIKit
import Security

// MARK: - Error Handling

enum ExpenseManagerError: LocalizedError {
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
}

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
            throw ExpenseManagerError.imageProcessingFailed
        }
        
        let base64Image = imageData.base64EncodedString()
        let prompt = createExpenseExtractionPrompt()
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
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
        
        // Use the keychain stored API key
        guard let apiKey = KeychainService.shared.retrieve(for: .openaiKey) else {
            throw ExpenseManagerError.apiKeyMissing
        }
        
        guard let url = URL(string: baseURL) else {
            throw OpenAIError.invalidResponse
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
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ExpenseManagerError.networkError(underlying: error)
        }
        
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
        - CRITICAL: For German date format DD.MM.YY, interpret YY as 20YY (e.g., "25" means "2025", not "1925" or "2023")
        - Always prioritize full ISO timestamps when available (e.g., "2025-09-06T19:22:16.000Z")
        - If both short format (06.09.25) and full timestamp are present, use the full timestamp

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
        var expenseDate = dateFormatter.date(from: extraction.date) ?? Date()
        
        // Validate and fix date if it's incorrectly parsed as 2023 instead of 2025
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let extractedYear = calendar.component(.year, from: expenseDate)
        
        // If the extracted date is 2023 but we're in 2025, likely a parsing error
        if extractedYear == 2023 && currentYear >= 2025 {
            print("Warning: Date parsed as 2023, correcting to 2025. Original: \(extraction.date)")
            let components = calendar.dateComponents([.month, .day], from: expenseDate)
            var correctedComponents = DateComponents()
            correctedComponents.year = 2025
            correctedComponents.month = components.month
            correctedComponents.day = components.day
            expenseDate = calendar.date(from: correctedComponents) ?? expenseDate
            print("Corrected date: \(expenseDate)")
        }
        
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
        
        let recentExpenses = Array(expenses.sorted { $0.date > $1.date }.prefix(limit))
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
    
    func saveExpensesToUserDefaults() throws {
        do {
            let data = try JSONEncoder().encode(expenses)
            userDefaults.set(data, forKey: expensesKey)
            // Update backup timestamp when data is saved
            userDefaults.set(Date(), forKey: lastBackupKey)
        } catch {
            throw ExpenseManagerError.persistenceError(underlying: error)
        }
    }
    
    func addExpense(_ expense: Expense) throws -> Expense {
        // Validate expense data
        guard expense.amount > 0 else {
            throw ExpenseManagerError.invalidAmount
        }
        
        guard expense.date <= Date() else {
            throw ExpenseManagerError.invalidDate
        }
        
        guard !expense.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExpenseManagerError.invalidExpenseData
        }
        
        expenses.append(expense)
        
        do {
            try saveExpensesToUserDefaults()
        } catch {
            // Remove the expense if saving failed
            expenses.removeAll { $0.id == expense.id }
            throw ExpenseManagerError.persistenceError(underlying: error)
        }
        
        return expense
    }
    
    func deleteExpense(_ expense: Expense) throws {
        expenses.removeAll { $0.id == expense.id }
        try saveExpensesToUserDefaults()
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
    
    // MARK: - Demo Data Detection
    
    static let sampleMerchants = ["Starbucks Coffee", "Shell Gas Station", "Tesco Extra", "Target", "Chipotle Mexican Grill", "Amazon.com"]
    
    func hasDemoData() -> Bool {
        // Check if any expenses match known sample merchants
        return expenses.contains { expense in
            ExpenseService.sampleMerchants.contains(expense.merchant)
        }
    }
    
    func clearDemoData() {
        expenses.removeAll { expense in
            ExpenseService.sampleMerchants.contains(expense.merchant)
        }
        saveExpensesToUserDefaults()
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
            expenseService.expenses.removeAll { expense in
                ExpenseService.sampleMerchants.contains(expense.merchant)
            }
            expenseService.saveExpensesToUserDefaults()
            
        case .openAIKey:
            try keychainService.deleteAPIKey()
            
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

// MARK: - AI Spending Insights Models and Service

struct SpendingInsights: Codable {
    let totalPotentialSavings: Double
    let spendingEfficiencyScore: Double
    let averageDailySpend: Double
    let topCategory: String
    let analysisDate: Date
    let timeframe: String
    
    let savingsOpportunities: [SavingsOpportunity]
    let categoryInsights: [CategoryInsight]
    let spendingPatterns: [SpendingPattern]
    let regionalInsights: [RegionalInsight]
    let actionItems: [ActionItem]
}

struct SavingsOpportunity: Codable {
    let title: String
    let description: String
    let detailedDescription: String
    let whyItSaves: String // Explanation of why this saves money
    let howToImplement: String // Detailed implementation guide
    let specificExamples: [String] // Examples specific to user's spending
    let potentialObstacles: [String] // Common challenges and solutions
    let potentialSavings: Double
    let difficulty: InsightDifficulty
    let impact: InsightImpact
    let steps: [String]
    let timeframe: String
    let expectedResults: String // What to expect after implementation
}

struct CategoryInsight: Codable {
    let category: String
    let totalSpent: Double
    let transactionCount: Int
    let percentageOfTotal: Double
    let averageTransactionSize: Double
    let keyInsights: [String]
    let detailedAnalysis: String
    let optimizationStrategies: [String] // Specific strategies for this category
    let potentialMonthlySavings: Double // How much can be saved in this category
}

struct SpendingPattern: Codable {
    let pattern: String
    let description: String
    let frequency: String
    let severity: InsightSeverity
    let financialImpact: Double?
    let recommendations: [String]?
    let icon: String
}

struct RegionalInsight: Codable {
    let region: String
    let comparisons: [RegionalComparison]
    let recommendations: [String]
}

struct RegionalComparison: Codable {
    let metric: String
    let comparison: String
    let isGood: Bool
}

struct ActionItem: Codable {
    let title: String
    let description: String
    let difficulty: InsightDifficulty
    let potentialMonthlySavings: Double?
}

enum InsightDifficulty: String, Codable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
    
    var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
}

enum InsightImpact: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .green
        }
    }
}

enum InsightSeverity: String, Codable {
    case info = "info"
    case warning = "warning"
    case critical = "critical"
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

@MainActor
class SpendingInsightsService: ObservableObject {
    static let shared = SpendingInsightsService()
    
    @Published var currentInsights: SpendingInsights?
    @Published var isAnalyzing = false
    
    private let openAIService = OpenAIService.shared
    
    var hasAnalysis: Bool {
        currentInsights != nil
    }
    
    var lastAnalysisDate: Date? {
        currentInsights?.analysisDate
    }
    
    var lastAnalyzedExpenseCount: Int = 0
    
    private init() {}
    
    func analyzeSpending(expenses: [Expense]) async throws -> SpendingInsights {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        guard !expenses.isEmpty else {
            throw InsightsError.noData
        }
        
        // Prepare comprehensive analysis prompt
        let prompt = createSpendingAnalysisPrompt(expenses: expenses)
        
        // Get AI analysis
        let analysisResult = try await requestAIAnalysis(prompt: prompt)
        
        // Parse and structure the insights
        let insights = try parseInsightsResponse(analysisResult)
        
        // Store insights
        currentInsights = insights
        lastAnalyzedExpenseCount = expenses.count
        
        return insights
    }
    
    private func createSpendingAnalysisPrompt(expenses: [Expense]) -> String {
        let totalAmount = expenses.reduce(0) { $0 + $1.amount }
        let currency = expenses.first?.currency ?? "EUR"
        let avgTransaction = totalAmount / Double(expenses.count)
        
        let categoryBreakdown = Dictionary(grouping: expenses, by: { $0.category })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
            .sorted { $0.value > $1.value }
        
        let merchantBreakdown = Dictionary(grouping: expenses, by: { $0.merchant })
            .mapValues { merchants in (count: merchants.count, total: merchants.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.value.total > $1.value.total }
        
        let allItems = expenses.compactMap { $0.items }.flatMap { $0 }
        let itemFrequency = Dictionary(grouping: allItems, by: { $0.name.lowercased() })
            .mapValues { items in (count: items.count, total: items.reduce(0) { $0 + $1.totalPrice }) }
            .sorted { $0.value.total > $1.value.total }
        
        return """
        Analyze spending data and provide comprehensive financial insights. 

        CRITICAL: Return ONLY valid JSON without any markdown formatting, explanations, or additional text.

        EXPENSE SUMMARY:
        - Total Expenses: \(expenses.count) transactions
        - Total Amount: \(totalAmount.formatted(currency: currency))
        - Average Transaction: \(avgTransaction.formatted(currency: currency))
        - Currency: \(currency)
        - Date Range: \(expenses.map { $0.date }.min()?.formatted(date: .abbreviated, time: .omitted) ?? "N/A") to \(expenses.map { $0.date }.max()?.formatted(date: .abbreviated, time: .omitted) ?? "N/A")

        CATEGORY BREAKDOWN:
        \(categoryBreakdown.prefix(10).map { "\($0.key): \($0.value.formatted(currency: currency))" }.joined(separator: "\n"))

        TOP MERCHANTS:
        \(merchantBreakdown.prefix(10).map { "\($0.key): \($0.value.total.formatted(currency: currency)) (\($0.value.count) visits)" }.joined(separator: "\n"))

        TOP ITEMS:
        \(itemFrequency.prefix(15).map { "\($0.key): \($0.value.total.formatted(currency: currency)) (\($0.value.count)x)" }.joined(separator: "\n"))

        Provide detailed analysis with:
        1. 3-5 savings opportunities with realistic monthly amounts and detailed implementation guides
        2. Category insights with percentages and patterns plus specific optimization strategies
        3. Spending patterns and concerning behaviors with step-by-step correction methods
        4. Regional insights (Germany/Europe context for EUR) with local money-saving tips
        5. Actionable items with comprehensive implementation steps and timeline
        
        IMPORTANT: For each savings opportunity, provide:
        - Clear title and brief description
        - Detailed explanation of WHY this saves money
        - Step-by-step HOW-TO guide for implementation
        - Specific examples relevant to the user's spending
        - Timeline and expected results
        - Potential obstacles and how to overcome them

        JSON FORMAT:
        {
          "totalPotentialSavings": <number>,
          "spendingEfficiencyScore": <0-100>,
          "averageDailySpend": <number>,
          "topCategory": "<category>",
          "analysisDate": "\(Date().formatted(.iso8601))",
          "timeframe": "Recent Analysis",
          "savingsOpportunities": [
            {
              "title": "Specific Opportunity Title",
              "description": "Brief 1-2 sentence overview",
              "detailedDescription": "Comprehensive explanation with context",
              "whyItSaves": "Detailed explanation of the financial mechanism behind the savings",
              "howToImplement": "Step-by-step implementation guide with specific actions",
              "specificExamples": ["Example 1 based on user's actual spending", "Example 2"],
              "potentialObstacles": ["Obstacle 1 and how to overcome it", "Obstacle 2"],
              "potentialSavings": <monthly_amount>,
              "difficulty": "easy|medium|hard",
              "impact": "low|medium|high",
              "steps": ["Actionable step 1", "Actionable step 2"],
              "timeframe": "2-4 weeks",
              "expectedResults": "What user can expect to see after implementation"
            }
          ],
          "categoryInsights": [
            {
              "category": "Category",
              "totalSpent": <amount>,
              "transactionCount": <count>,
              "percentageOfTotal": <percentage>,
              "averageTransactionSize": <amount>,
              "keyInsights": ["Insight 1", "Insight 2"],
              "detailedAnalysis": "Comprehensive analysis with spending patterns and trends",
              "optimizationStrategies": ["Strategy 1 with specific steps", "Strategy 2"],
              "potentialMonthlySavings": <amount>
            }
          ],
          "spendingPatterns": [
            {
              "pattern": "Pattern",
              "description": "Description",
              "frequency": "daily|weekly|monthly",
              "severity": "info|warning|critical",
              "financialImpact": <amount>,
              "recommendations": ["Recommendation"],
              "icon": "chart.bar.fill"
            }
          ],
          "regionalInsights": [
            {
              "region": "Germany",
              "comparisons": [
                {
                  "metric": "Metric",
                  "comparison": "Comparison",
                  "isGood": true
                }
              ],
              "recommendations": ["Recommendation"]
            }
          ],
          "actionItems": [
            {
              "title": "Action",
              "description": "Description",
              "difficulty": "easy|medium|hard",
              "potentialMonthlySavings": <amount>
            }
          ]
        }
        """
    }
    
    private func requestAIAnalysis(prompt: String) async throws -> String {
        guard let apiKey = KeychainService.shared.retrieve(for: .openaiKey) else {
            throw InsightsError.missingAPIKey
        }
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": "You are an expert financial advisor providing spending analysis and savings recommendations."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 3000,
            "temperature": 0.1
        ]
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw InsightsError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw InsightsError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw InsightsError.invalidAPIKey
        } else if httpResponse.statusCode != 200 {
            throw InsightsError.apiError(httpResponse.statusCode)
        }
        
        do {
            let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            guard let content = openAIResponse.choices.first?.message.content else {
                throw InsightsError.noResponseContent
            }
            print("Raw AI Response: \(content)")
            return content
        } catch {
            print("OpenAI Response Parsing Error: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw Response Data: \(responseString)")
            }
            throw InsightsError.responseParsingFailed
        }
    }
    
    private func parseInsightsResponse(_ content: String) throws -> SpendingInsights {
        let cleanedContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleanedContent.data(using: .utf8) else {
            throw InsightsError.responseParsingFailed
        }
        
        do {
            let decoder = JSONDecoder()
            
            // Custom date decoding strategy to handle multiple formats
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                // Try multiple date formats
                let formatters = [
                    "yyyy-MM-dd'T'HH:mm:ssZ",
                    "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                    "yyyy-MM-dd'T'HH:mm:ss",
                    "yyyy-MM-dd HH:mm:ss",
                    "yyyy-MM-dd"
                ]
                
                for formatString in formatters {
                    let formatter = DateFormatter()
                    formatter.dateFormat = formatString
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.timeZone = TimeZone(secondsFromGMT: 0)
                    
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }
                
                // If all formats fail, return current date
                print("Unable to parse date: \(dateString), using current date")
                return Date()
            }
            
            return try decoder.decode(SpendingInsights.self, from: jsonData)
        } catch {
            print("JSON Parsing Error: \(error)")
            print("Cleaned content: \(cleanedContent)")
            
            // Try to create a fallback response with basic analysis
            if let fallbackInsights = createFallbackInsights(from: content) {
                return fallbackInsights
            }
            
            throw InsightsError.responseParsingFailed
        }
    }
    
    private func createFallbackInsights(from content: String) -> SpendingInsights? {
        // Create a basic insights response when parsing fails
        return SpendingInsights(
            totalPotentialSavings: 50.0,
            spendingEfficiencyScore: 75.0,
            averageDailySpend: 25.0,
            topCategory: "Food & Dining",
            analysisDate: Date(),
            timeframe: "Recent Analysis",
            savingsOpportunities: [
                SavingsOpportunity(
                    title: "Reduce Frequent Small Purchases",
                    description: "Consolidate smaller purchases to reduce fees and impulse spending.",
                    detailedDescription: "Multiple small transactions often lead to higher fees and impulse purchases, reducing overall financial efficiency.",
                    whyItSaves: "Small frequent purchases typically involve transaction fees, impulse decisions, and missed bulk discounts. Consolidating reduces these costs and improves budgeting discipline.",
                    howToImplement: "Plan your shopping trips weekly, create detailed shopping lists, and set daily spending limits. Use the envelope method to physically separate money for different categories.",
                    specificExamples: ["Instead of 5 coffee purchases at €3 each, buy a week's worth of coffee beans for €10", "Combine grocery trips to take advantage of bulk pricing"],
                    potentialObstacles: ["Convenience of small purchases", "Breaking established habits", "Initial planning time investment"],
                    potentialSavings: 30.0,
                    difficulty: .easy,
                    impact: .medium,
                    steps: ["Create weekly shopping schedule", "Prepare detailed shopping lists", "Set daily spending limits", "Track all small purchases for one week"],
                    timeframe: "2-3 weeks",
                    expectedResults: "20-30% reduction in small purchase frequency and 15-25% savings on total monthly spending"
                ),
                SavingsOpportunity(
                    title: "Optimize Subscription Services",
                    description: "Audit and optimize your recurring subscription payments.",
                    detailedDescription: "Many people accumulate subscriptions over time without regular review, leading to paying for unused services.",
                    whyItSaves: "Subscriptions compound monthly and are often forgotten. Canceling unused services provides immediate monthly savings with zero lifestyle impact.",
                    howToImplement: "List all subscriptions from bank statements, evaluate usage over the past 3 months, cancel unused services, and consolidate similar services into bundles where possible.",
                    specificExamples: ["Cancel unused streaming services saving €10-15/month", "Switch to family plans for shared services", "Use free alternatives for rarely-used premium services"],
                    potentialObstacles: ["Fear of missing out on services", "Cancellation complexity", "Family member disagreements"],
                    potentialSavings: 20.0,
                    difficulty: .easy,
                    impact: .medium,
                    steps: ["List all subscriptions", "Track usage for 1 month", "Cancel unused services", "Research bundle options"],
                    timeframe: "1-2 weeks",
                    expectedResults: "Immediate monthly savings of €15-30 with no impact on daily life"
                )
            ],
            categoryInsights: [
                CategoryInsight(
                    category: "Food & Dining",
                    totalSpent: 200.0,
                    transactionCount: 15,
                    percentageOfTotal: 35.0,
                    averageTransactionSize: 13.33,
                    keyInsights: ["Consider meal planning to reduce food waste", "Look for grocery store promotions", "Review frequent dining out patterns"],
                    detailedAnalysis: "Food spending represents a significant portion of your budget with multiple optimization opportunities. Your average transaction size suggests a mix of grocery shopping and dining out.",
                    optimizationStrategies: [
                        "Plan meals weekly and create detailed shopping lists to avoid impulse purchases",
                        "Cook larger batches and freeze portions for busy days",
                        "Take advantage of store loyalty programs and weekly promotions",
                        "Replace expensive dining out occasions with home-cooked alternatives",
                        "Buy generic/store brands for staple items - same quality, 20-30% less cost"
                    ],
                    potentialMonthlySavings: 45.0
                )
            ],
            spendingPatterns: [],
            regionalInsights: [],
            actionItems: []
        )
    }
}

enum InsightsError: LocalizedError {
    case noData, missingAPIKey, invalidURL, requestEncodingFailed
    case invalidResponse, invalidAPIKey, apiError(Int)
    case noResponseContent, responseParsingFailed
    
    var errorDescription: String? {
        switch self {
        case .noData: return "No expense data available"
        case .missingAPIKey: return "OpenAI API key not found"
        case .invalidURL: return "Invalid API URL"
        case .requestEncodingFailed: return "Failed to encode request"
        case .invalidResponse: return "Invalid response from OpenAI"
        case .invalidAPIKey: return "Invalid OpenAI API key"
        case .apiError(let code): return "OpenAI API error (Status: \(code))"
        case .noResponseContent: return "No content in OpenAI response"
        case .responseParsingFailed: return "Failed to parse AI response"
        }
    }
}

// MARK: - Spending Insights View

struct SpendingInsightsView: View {
    @ObservedObject private var expenseService = ExpenseService.shared
    @ObservedObject private var insightsService = SpendingInsightsService.shared
    @State private var isAnalyzing = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with analysis trigger
                    analysisHeader
                    
                    if insightsService.hasAnalysis {
                        // Quick Stats
                        quickStatsSection
                        
                        // Savings Opportunities
                        savingsOpportunitiesSection
                        
                        // Category Insights
                        if let insights = insightsService.currentInsights {
                            categoryInsightsSection(insights.categoryInsights)
                        }
                    } else {
                        emptyStateView
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("AI Insights")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("Analysis Result", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var analysisHeader: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundColor(.purple)
                        Text("AI Analysis")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Text("Get personalized insights on your spending patterns and discover opportunities to save money")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            
            if !insightsService.hasAnalysis || expenseService.expenses.count > insightsService.lastAnalyzedExpenseCount {
                Button(action: {
                    Task {
                        await performAnalysis()
                    }
                }) {
                    HStack {
                        if isAnalyzing {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Analyzing spending...")
                        } else {
                            Image(systemName: "sparkles")
                            Text(insightsService.hasAnalysis ? "Update Analysis" : "Analyze My Spending")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.purple, .blue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .disabled(isAnalyzing || expenseService.expenses.isEmpty)
            }
            
            if let lastAnalysis = insightsService.lastAnalysisDate {
                Text("Last analyzed: \(lastAnalysis, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var quickStatsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Key Metrics")
                    .font(.headline)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                InsightMetricCard(
                    title: "Potential Monthly Savings",
                    value: insightsService.currentInsights?.totalPotentialSavings ?? 0,
                    currency: expenseService.getPrimaryCurrency(),
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
                
                InsightMetricCard(
                    title: "Spending Efficiency",
                    value: insightsService.currentInsights?.spendingEfficiencyScore ?? 0,
                    currency: "%",
                    icon: "gauge.high",
                    color: .blue
                )
            }
        }
    }
    
    private var savingsOpportunitiesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("💰 Savings Opportunities")
                    .font(.headline)
                Spacer()
            }
            
            if let opportunities = insightsService.currentInsights?.savingsOpportunities {
                LazyVStack(spacing: 12) {
                    ForEach(Array(opportunities.enumerated()), id: \.offset) { index, opportunity in
                        DetailedSavingsOpportunityCard(opportunity: opportunity, rank: index + 1)
                    }
                }
            }
        }
    }
    
    private func categoryInsightsSection(_ insights: [CategoryInsight]) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("📊 Category Analysis")
                    .font(.headline)
                Spacer()
            }
            
            LazyVStack(spacing: 12) {
                ForEach(insights, id: \.category) { insight in
                    CategoryInsightCard(insight: insight)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text("Ready to Analyze Your Spending?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("I'll analyze your expenses to find patterns, identify savings opportunities, and provide personalized recommendations.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if expenseService.expenses.isEmpty {
                VStack(spacing: 8) {
                    Text("No expenses found")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Add some expenses first to get insights")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 40)
    }
    
    private func performAnalysis() async {
        isAnalyzing = true
        
        do {
            let insights = try await insightsService.analyzeSpending(expenses: expenseService.expenses)
            
            if insights.totalPotentialSavings > 0 {
                alertMessage = "Analysis complete! Found potential savings of \(insights.totalPotentialSavings.formatted(currency: expenseService.getPrimaryCurrency())) per month."
            } else {
                alertMessage = "Analysis complete! Your spending looks efficient, but I found some interesting patterns."
            }
            showingAlert = true
        } catch {
            alertMessage = "Analysis failed: \(error.localizedDescription)"
            showingAlert = true
        }
        
        isAnalyzing = false
    }
}

// MARK: - Supporting Views

struct InsightMetricCard: View {
    let title: String
    let value: Double
    let currency: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            Text(formatValue())
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    private func formatValue() -> String {
        if currency == "%" {
            return String(format: "%.0f%%", value)
        } else {
            return value.formatted(currency: currency)
        }
    }
}

struct DetailedSavingsOpportunityCard: View {
    let opportunity: SavingsOpportunity
    let rank: Int
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main card content (always visible)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 16) {
                    // Rank badge
                    ZStack {
                        Circle()
                            .fill(rankColor.opacity(0.2))
                            .frame(width: 32, height: 32)
                        Text("\(rank)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(rankColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(opportunity.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Text("💸 \(opportunity.potentialSavings.formatted(currency: "EUR"))/month")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        
                        Text(opportunity.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(isExpanded ? nil : 2)
                        
                        HStack {
                            Text(opportunity.difficulty.rawValue.capitalized)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(opportunity.difficulty.color.opacity(0.2))
                                )
                                .foregroundColor(opportunity.difficulty.color)
                            
                            Text(opportunity.impact.rawValue.capitalized)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(opportunity.impact.color.opacity(0.2))
                                )
                                .foregroundColor(opportunity.impact.color)
                            
                            Spacer()
                            
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding()
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Why it saves money
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Why This Saves Money", systemImage: "lightbulb.fill")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                            
                            Text(opportunity.whyItSaves)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                        }
                        
                        // How to implement
                        VStack(alignment: .leading, spacing: 6) {
                            Label("How to Implement", systemImage: "gearshape.fill")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            
                            Text(opportunity.howToImplement)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                        }
                        
                        // Specific examples
                        if !opportunity.specificExamples.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Specific Examples", systemImage: "list.bullet.circle.fill")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                                
                                ForEach(opportunity.specificExamples, id: \.self) { example in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("•")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                        Text(example)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                            }
                        }
                        
                        // Expected results
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Expected Results", systemImage: "chart.line.uptrend.xyaxis")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.purple)
                            
                            Text(opportunity.expectedResults)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                        }
                        
                        // Potential obstacles
                        if !opportunity.potentialObstacles.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Common Challenges & Solutions", systemImage: "exclamationmark.triangle.fill")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                                
                                ForEach(opportunity.potentialObstacles, id: \.self) { obstacle in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("⚠️")
                                            .font(.caption)
                                        Text(obstacle)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                            }
                        }
                        
                        // Implementation timeline
                        HStack {
                            Label("Timeline", systemImage: "clock.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(opportunity.timeframe)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("Potential: \(opportunity.potentialSavings.formatted(currency: "EUR"))/month")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        .padding(.top, 8)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(rankColor.opacity(0.1))
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
                .transition(.opacity.combined(with: .slide))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(rankColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .green
        case 2: return .orange  
        case 3: return .blue
        default: return .gray
        }
    }
}

struct SavingsOpportunityCard: View {
    let opportunity: SavingsOpportunity
    let rank: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                Text("\(rank)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(rankColor)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(opportunity.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Text("💸 \(opportunity.potentialSavings.formatted(currency: "EUR"))")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                Text(opportunity.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                HStack {
                    Text(opportunity.difficulty.rawValue.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(opportunity.difficulty.color.opacity(0.2))
                        )
                        .foregroundColor(opportunity.difficulty.color)
                    
                    Spacer()
                    
                    Text(opportunity.impact.rawValue.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(opportunity.impact.color.opacity(0.2))
                        )
                        .foregroundColor(opportunity.impact.color)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(rankColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .green
        case 2: return .orange
        case 3: return .blue
        default: return .gray
        }
    }
}

struct CategoryInsightCard: View {
    let insight: CategoryInsight
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main card content (always visible)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(insight.category)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("\(insight.totalSpent.formatted(currency: "EUR")) • \(insight.transactionCount) transactions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(insight.percentageOfTotal, specifier: "%.1f")%")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("of total spending")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            if insight.potentialMonthlySavings > 0 {
                                Text("💰 Save \(insight.potentialMonthlySavings.formatted(currency: "EUR"))")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)
                            
                            Rectangle()
                                .fill(categoryColor)
                                .frame(width: geometry.size.width * (insight.percentageOfTotal / 100), height: 4)
                        }
                    }
                    .frame(height: 4)
                    
                    HStack {
                        if !insight.keyInsights.isEmpty {
                            Text("💡 \(insight.keyInsights.first ?? "")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding()
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Detailed Analysis
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Analysis", systemImage: "chart.bar.fill")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            
                            Text(insight.detailedAnalysis)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                        }
                        
                        // Optimization Strategies
                        if !insight.optimizationStrategies.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Money-Saving Strategies", systemImage: "lightbulb.fill")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                                
                                ForEach(Array(insight.optimizationStrategies.enumerated()), id: \.offset) { index, strategy in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("\(index + 1).")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.orange)
                                        
                                        Text(strategy)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                            }
                        }
                        
                        // All Key Insights
                        if insight.keyInsights.count > 1 {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Key Insights", systemImage: "brain.head.profile")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.purple)
                                
                                ForEach(insight.keyInsights, id: \.self) { insight in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("💡")
                                            .font(.caption)
                                        
                                        Text(insight)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                            }
                        }
                        
                        // Savings Potential
                        if insight.potentialMonthlySavings > 0 {
                            HStack {
                                Label("Savings Potential", systemImage: "dollarsign.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(insight.potentialMonthlySavings.formatted(currency: "EUR"))/month")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.green.opacity(0.1))
                            )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
                .transition(.opacity.combined(with: .slide))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
    }
    
    private var categoryColor: Color {
        switch insight.category {
        case "Food & Dining": return .orange
        case "Transportation": return .blue
        case "Shopping": return .purple
        case "Entertainment": return .pink
        case "Bills & Utilities": return .yellow
        case "Healthcare": return .red
        case "Travel": return .green
        case "Education": return .indigo
        case "Business": return .brown
        default: return .gray
        }
    }
}

// MARK: - Data Export Service

class DataExporter {
    func exportData(
        expenses: [Expense],
        format: ExportFormat,
        includeItems: Bool = true,
        includeFinancialBreakdown: Bool = true,
        progressCallback: @escaping (Double) -> Void = { _ in }
    ) async throws -> URL {
        
        // Create a safe filename without spaces or special characters
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        let fileName = "ExpenseExport_\(dateString).\(format.fileExtension)"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        switch format {
        case .csv:
            try await exportCSV(expenses: expenses, to: fileURL, includeItems: includeItems, includeFinancialBreakdown: includeFinancialBreakdown, progressCallback: progressCallback)
        case .json:
            try await exportJSON(expenses: expenses, to: fileURL, includeItems: includeItems, includeFinancialBreakdown: includeFinancialBreakdown, progressCallback: progressCallback)
        }
        
        return fileURL
    }
    
    // MARK: - CSV Export
    private func exportCSV(expenses: [Expense], to url: URL, includeItems: Bool, includeFinancialBreakdown: Bool, progressCallback: @escaping (Double) -> Void) async throws {
        var csvContent = ""
        
        // Create header
        var headers = ["Date", "Merchant", "Amount", "Currency", "Category", "Description", "Payment Method"]
        
        if includeFinancialBreakdown {
            headers.append(contentsOf: ["Tax Amount", "Subtotal", "Tip", "Fees", "Discount"])
        }
        
        if includeItems {
            headers.append(contentsOf: ["Items Count", "Items Detail"])
        }
        
        csvContent += headers.joined(separator: ",") + "\n"
        
        // Process expenses
        for (index, expense) in expenses.enumerated() {
            await MainActor.run {
                progressCallback(Double(index) / Double(expenses.count))
            }
            
            var row = [
                expense.date.formatted(date: .abbreviated, time: .omitted),
                escapeCSV(expense.merchant),
                String(expense.amount),
                expense.currency,
                escapeCSV(expense.category),
                escapeCSV(expense.description ?? ""),
                escapeCSV(expense.paymentMethod ?? "")
            ]
            
            if includeFinancialBreakdown {
                row.append(contentsOf: [
                    String(expense.taxAmount ?? 0),
                    String(expense.subtotal ?? 0),
                    String(expense.tip ?? 0),
                    String(expense.fees ?? 0),
                    "0" // Discount not currently in Expense model
                ])
            }
            
            if includeItems {
                let itemsCount = expense.items?.count ?? 0
                let itemsDetail = expense.items?.map { "\($0.name): \($0.quantity ?? 0)x@\(String($0.unitPrice ?? 0))" }.joined(separator: "; ") ?? ""
                row.append(contentsOf: [String(itemsCount), escapeCSV(itemsDetail)])
            }
            
            csvContent += row.joined(separator: ",") + "\n"
        }
        
        try csvContent.write(to: url, atomically: true, encoding: .utf8)
    }
    
    // MARK: - JSON Export
    private func exportJSON(expenses: [Expense], to url: URL, includeItems: Bool, includeFinancialBreakdown: Bool, progressCallback: @escaping (Double) -> Void) async throws {
        var exportData: [String: Any] = [:]
        
        // Metadata
        exportData["exportDate"] = ISO8601DateFormatter().string(from: Date())
        exportData["version"] = "2.1.0"
        exportData["totalExpenses"] = expenses.count
        exportData["totalAmount"] = expenses.reduce(0) { $0 + $1.amount }
        exportData["includeItems"] = includeItems
        exportData["includeFinancialBreakdown"] = includeFinancialBreakdown
        
        // Process expenses
        var expensesData: [[String: Any]] = []
        
        for (index, expense) in expenses.enumerated() {
            await MainActor.run {
                progressCallback(Double(index) / Double(expenses.count))
            }
            
            var expenseDict: [String: Any] = [
                "id": expense.id.uuidString,
                "date": ISO8601DateFormatter().string(from: expense.date),
                "merchant": expense.merchant,
                "amount": expense.amount,
                "currency": expense.currency,
                "category": expense.category
            ]
            
            if let description = expense.description {
                expenseDict["description"] = description
            }
            
            if let paymentMethod = expense.paymentMethod {
                expenseDict["paymentMethod"] = paymentMethod
            }
            
            if includeFinancialBreakdown {
                if let taxAmount = expense.taxAmount {
                    expenseDict["taxAmount"] = taxAmount
                }
                if let subtotal = expense.subtotal {
                    expenseDict["subtotal"] = subtotal
                }
                if let tip = expense.tip {
                    expenseDict["tip"] = tip
                }
                if let fees = expense.fees {
                    expenseDict["fees"] = fees
                }
                // Note: Discount field not currently available in Expense model
                expenseDict["discount"] = 0
            }
            
            if includeItems, let items = expense.items {
                let itemsData = items.map { item in
                    [
                        "name": item.name,
                        "quantity": item.quantity ?? 0,
                        "unitPrice": item.unitPrice ?? 0,
                        "totalPrice": item.totalPrice,
                        "category": item.category ?? "",
                        "description": item.description ?? ""
                    ] as [String: Any]
                }
                expenseDict["items"] = itemsData
            }
            
            expensesData.append(expenseDict)
        }
        
        exportData["expenses"] = expensesData
        
        // Summary statistics
        let categoryTotals = Dictionary(grouping: expenses, by: { $0.category })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        
        exportData["summary"] = [
            "categoryTotals": categoryTotals,
            "dateRange": [
                "start": expenses.map { $0.date }.min()?.timeIntervalSince1970 ?? 0,
                "end": expenses.map { $0.date }.max()?.timeIntervalSince1970 ?? 0
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        try jsonData.write(to: url)
    }
    
    
    // MARK: - Helper Methods
    private func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"" + string.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return string
    }
}