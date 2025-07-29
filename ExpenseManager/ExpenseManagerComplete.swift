import Foundation
import SwiftUI
import Combine
import PhotosUI
import UIKit
import Security
import Photos

// MARK: - Models and Data Structures

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
        updatedAt: Date = Date()
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
}

struct OpenAIResponse: Codable {
    let choices: [Choice]
    struct Choice: Codable {
        let message: Message
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
            "model": "gpt-4o",
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "text", "text": prompt],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]]
                ]
            ]],
            "max_tokens": 500,
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
        You are an expert at extracting expense information from receipt images. Analyze the provided receipt image and extract the following information with high precision:

        REQUIRED FIELDS:
        1. **Date**: The transaction date (format: YYYY-MM-DD). If no date is visible, use today's date.
        2. **Merchant**: The business/store name exactly as shown on the receipt
        3. **Amount**: The total amount paid (extract only the numerical value, no currency symbol)
        4. **Currency**: The currency code (e.g., USD, EUR, GBP). Default to USD if not specified.
        5. **Category**: Choose the most appropriate category from this exact list:
           - Food & Dining, Transportation, Shopping, Entertainment, Bills & Utilities, Healthcare, Travel, Education, Business, Other

        OPTIONAL FIELDS:
        6. **Description**: Brief description of items purchased (max 100 characters)
        7. **Payment Method**: Choose from: Cash, Credit Card, Debit Card, Digital Payment, Bank Transfer, Check, Other
        8. **Tax Amount**: Tax amount if clearly visible (numerical value only)
        9. **Confidence**: Your confidence level in the extraction (0.0 to 1.0)

        EXTRACTION RULES:
        - Look for the TOTAL or FINAL amount, not subtotals
        - Ignore tips unless they're part of the total
        - For restaurants: use "Food & Dining" category
        - For gas stations: use "Transportation" category
        - For grocery stores: use "Food & Dining" or "Shopping" based on context
        - If multiple items, categorize based on the primary expense type
        - Be conservative with confidence scores - use 0.9+ only when very certain

        RESPONSE FORMAT:
        Return ONLY a valid JSON object with this exact structure (no additional text, markdown, or formatting):

        {
            "date": "YYYY-MM-DD",
            "merchant": "Business Name",
            "amount": 99.99,
            "currency": "USD",
            "category": "Food & Dining",
            "description": "Brief description of purchase",
            "paymentMethod": "Credit Card",
            "taxAmount": 8.25,
            "confidence": 0.85
        }

        If you cannot extract certain information, use null for optional fields. For required fields, make reasonable assumptions and lower the confidence score accordingly.
        """
    }
    
    private func parseExpenseExtraction(from content: String) throws -> OpenAIExpenseExtraction {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code blocks if present
        let cleanedContent = trimmedContent
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("Cleaned content for parsing: \(cleanedContent)")
        
        guard let jsonData = cleanedContent.data(using: .utf8) else {
            print("Failed to convert to data")
            throw OpenAIError.responseParsingFailed
        }
        
        do {
            return try JSONDecoder().decode(OpenAIExpenseExtraction.self, from: jsonData)
        } catch {
            print("JSON Decoding Error: \(error)")
            throw OpenAIError.responseParsingFailed
        }
    }
}

enum OpenAIError: LocalizedError {
    case missingAPIKey, invalidURL, requestEncodingFailed, invalidResponse
    case invalidAPIKey, apiError(Int), noResponseContent, responseParsingFailed, imageProcessingFailed
    
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
        }
    }
}


@MainActor
class ExpenseService: ObservableObject {
    static let shared = ExpenseService()
    
    @Published var expenses: [Expense] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var processedPhotos: [ProcessedPhoto] = []
    @Published var showProcessingCompletionDialog = false
    @Published var processedPhotoCount = 0
    
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
    
    struct ProcessedPhoto: Identifiable {
        let id = UUID()
        let photoItem: PhotosPickerItem
        let assetIdentifier: String?
        let expense: Expense
        let processingDate: Date
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
                    let createdExpense = addExpense(expense)
                    
                    // Track the processed photo with captured identifier
                    let processedPhoto = ProcessedPhoto(
                        photoItem: photoItem,
                        assetIdentifier: assetIdentifier,
                        expense: createdExpense,
                        processingDate: Date()
                    )
                    processedPhotos.append(processedPhoto)
                    
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
                        errorMessage = "Failed to parse receipt data. Try a clearer image."
                    default:
                        errorMessage = "OpenAI processing failed: \(openAIError.localizedDescription)"
                    }
                } else {
                    errorMessage = "Processing failed: \(error.localizedDescription)"
                }
            }
        }
        
        // Show completion dialog if any photos were processed successfully
        if processedCount > 0 {
            processedPhotoCount = processedCount
            showProcessingCompletionDialog = true
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
        
        return Expense(
            date: expenseDate,
            merchant: extraction.merchant,
            amount: extraction.amount,
            currency: extraction.currency,
            category: extraction.category,
            description: extraction.description,
            paymentMethod: extraction.paymentMethod,
            taxAmount: extraction.taxAmount
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
    
    func deletePhotoFromLibrary(_ processedPhoto: ProcessedPhoto) async -> Bool {
        // First check if we have photo library permissions
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        if status != .authorized {
            // Request permission
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            if newStatus != .authorized {
                errorMessage = "Photo library access denied. Please enable in Settings."
                return false
            }
        }
        
        // Use the captured asset identifier
        print("PhotosPickerItem itemIdentifier: \(processedPhoto.photoItem.itemIdentifier ?? "nil")")
        print("Captured assetIdentifier: \(processedPhoto.assetIdentifier ?? "nil")")
        
        guard let assetIdentifier = processedPhoto.assetIdentifier else {
            errorMessage = "Could not identify photo to delete."
            return false
        }
        print("Using asset identifier: \(assetIdentifier)")
        
        // Fetch the PHAsset
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            errorMessage = "Photo not found in library."
            return false
        }
        
        // Delete the asset
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets([asset] as NSArray)
            }
            
            // Remove from our tracked list
            if let index = processedPhotos.firstIndex(where: { $0.id == processedPhoto.id }) {
                processedPhotos.remove(at: index)
            }
            
            return true
        } catch {
            errorMessage = "Failed to delete photo: \(error.localizedDescription)"
            return false
        }
    }
    
    func clearProcessedPhotos() {
        processedPhotos.removeAll()
    }
    
    // MARK: - Local Storage Methods
    
    private func loadExpensesFromUserDefaults() {
        if let data = userDefaults.data(forKey: expensesKey),
           let decodedExpenses = try? JSONDecoder().decode([Expense].self, from: data) {
            self.expenses = decodedExpenses
        }
    }
    
    private func saveExpensesToUserDefaults() {
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
        // Also remove from processed photos if it exists
        processedPhotos.removeAll { $0.expense.id == expense.id }
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
                taxAmount: 0.38
            ),
            Expense(
                date: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
                merchant: "Shell Gas Station",
                amount: 45.20,
                currency: "USD",
                category: "Transportation",
                description: "Fuel",
                paymentMethod: "Debit Card",
                taxAmount: 3.62
            ),
            Expense(
                date: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
                merchant: "Target",
                amount: 23.99,
                currency: "USD",
                category: "Shopping",
                description: "Household items",
                paymentMethod: "Credit Card",
                taxAmount: 1.92
            ),
            Expense(
                date: calendar.date(byAdding: .day, value: -5, to: now) ?? now,
                merchant: "Chipotle Mexican Grill",
                amount: 12.85,
                currency: "USD",
                category: "Food & Dining",
                description: "Burrito bowl and drink",
                paymentMethod: "Digital Payment",
                taxAmount: 1.03
            ),
            Expense(
                date: calendar.date(byAdding: .day, value: -7, to: now) ?? now,
                merchant: "Amazon.com",
                amount: 89.99,
                currency: "USD",
                category: "Shopping",
                description: "Office supplies",
                paymentMethod: "Credit Card",
                taxAmount: 7.20
            )
        ]
        
        for expense in sampleExpenses {
            expenses.append(expense)
        }
        
        saveExpensesToUserDefaults()
        print("Added \(sampleExpenses.count) sample expenses for first launch")
    }
    
}