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

struct SupabaseAmountOnly: Codable {
    let amount: Double
}

struct SupabaseExpense: Codable {
    let id: UUID?
    let date: String
    let merchant: String
    let amount: Double
    let currency: String
    let category: String
    let description: String?
    let payment_method: String?
    let tax_amount: Double?
    let receipt_image_url: String?
    let created_at: String?
    let updated_at: String?
    
    init(from expense: Expense) {
        self.id = expense.id
        self.date = ISO8601DateFormatter().string(from: expense.date)
        self.merchant = expense.merchant
        self.amount = expense.amount
        self.currency = expense.currency
        self.category = expense.category
        self.description = expense.description
        self.payment_method = expense.paymentMethod
        self.tax_amount = expense.taxAmount
        self.receipt_image_url = expense.receiptImageUrl
        self.created_at = ISO8601DateFormatter().string(from: expense.createdAt)
        self.updated_at = ISO8601DateFormatter().string(from: expense.updatedAt)
    }
    
    func toExpense() -> Expense {
        let dateFormatter = ISO8601DateFormatter()
        return Expense(
            id: id ?? UUID(),
            date: dateFormatter.date(from: date) ?? Date(),
            merchant: merchant,
            amount: amount,
            currency: currency,
            category: category,
            description: description,
            paymentMethod: payment_method,
            taxAmount: tax_amount,
            receiptImageUrl: receipt_image_url,
            createdAt: created_at.flatMap { dateFormatter.date(from: $0) } ?? Date(),
            updatedAt: updated_at.flatMap { dateFormatter.date(from: $0) } ?? Date()
        )
    }
}

// MARK: - Services

class KeychainService {
    static let shared = KeychainService()
    private init() {}
    
    private let service = "com.yourcompany.ExpenseManager"
    
    enum KeychainKey: String {
        case supabaseUrl = "supabase_url"
        case supabaseKey = "supabase_key"
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
        let hasSupabaseUrl = keychain.retrieve(for: .supabaseUrl) != nil
        let hasSupabaseKey = keychain.retrieve(for: .supabaseKey) != nil
        let hasOpenAIKey = keychain.retrieve(for: .openaiKey) != nil
        isConfigured = hasSupabaseUrl && hasSupabaseKey && hasOpenAIKey
    }
    
    func saveConfiguration(supabaseUrl: String, supabaseKey: String, openaiKey: String) async -> Bool {
        let trimmedUrl = supabaseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSupabaseKey = supabaseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOpenAIKey = openaiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedUrl.isEmpty, !trimmedSupabaseKey.isEmpty, !trimmedOpenAIKey.isEmpty else {
            return false
        }
        
        let urlSaved = keychain.save(trimmedUrl, for: .supabaseUrl)
        let supabaseKeySaved = keychain.save(trimmedSupabaseKey, for: .supabaseKey)
        let openaiKeySaved = keychain.save(trimmedOpenAIKey, for: .openaiKey)
        
        if urlSaved && supabaseKeySaved && openaiKeySaved {
            checkConfiguration()
            return true
        }
        return false
    }
    
    func testConnections() async {
        connectionStatus = .testing
        isTestingConnection = true
        
        let supabaseResult = await testSupabaseConnection()
        let openaiResult = await testOpenAIConnection()
        
        isTestingConnection = false
        
        if supabaseResult.success && openaiResult.success {
            connectionStatus = .success
        } else {
            let errors = [supabaseResult.error, openaiResult.error].compactMap { $0 }.joined(separator: "; ")
            connectionStatus = .failure(errors)
        }
    }
    
    private func testSupabaseConnection() async -> (success: Bool, error: String?) {
        guard let url = keychain.retrieve(for: .supabaseUrl),
              let key = keychain.retrieve(for: .supabaseKey),
              let supabaseURL = URL(string: "\(url)/rest/v1/") else {
            return (false, "Invalid Supabase credentials")
        }
        
        var request = URLRequest(url: supabaseURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 404 {
                    return (true, nil)
                } else if httpResponse.statusCode == 401 {
                    return (false, "Invalid Supabase API key")
                } else {
                    return (false, "Supabase connection failed (Status: \(httpResponse.statusCode))")
                }
            }
            return (false, "Invalid response from Supabase")
        } catch {
            return (false, "Supabase connection error: \(error.localizedDescription)")
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
    
    func getSupabaseUrl() -> String? { keychain.retrieve(for: .supabaseUrl) }
    func getSupabaseKey() -> String? { keychain.retrieve(for: .supabaseKey) }
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

class SupabaseService {
    static let shared = SupabaseService()
    private init() {}
    
    private var baseURL: String? {
        guard let url = KeychainService.shared.retrieve(for: .supabaseUrl) else { return nil }
        return "\(url)/rest/v1"
    }
    
    private var headers: [String: String] {
        guard let apiKey = KeychainService.shared.retrieve(for: .supabaseKey) else { return [:] }
        return [
            "Authorization": "Bearer \(apiKey)",
            "apikey": apiKey,
            "Content-Type": "application/json",
            "Prefer": "return=representation"
        ]
    }
    
    func createExpense(_ expense: Expense) async throws -> Expense {
        guard let baseURL = baseURL, let url = URL(string: "\(baseURL)/expenses") else {
            throw SupabaseError.missingCredentials
        }
        
        let supabaseExpense = SupabaseExpense(from: expense)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        do {
            request.httpBody = try JSONEncoder().encode(supabaseExpense)
        } catch {
            throw SupabaseError.encodingFailed
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try handleHTTPResponse(response)
        
        do {
            let createdExpenses = try JSONDecoder().decode([SupabaseExpense].self, from: data)
            guard let createdExpense = createdExpenses.first else {
                throw SupabaseError.noDataReturned
            }
            return createdExpense.toExpense()
        } catch {
            throw SupabaseError.decodingFailed
        }
    }
    
    func fetchExpenses(limit: Int? = nil, offset: Int? = nil) async throws -> [Expense] {
        guard let baseURL = baseURL else { throw SupabaseError.missingCredentials }
        
        var urlComponents = URLComponents(string: "\(baseURL)/expenses")!
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "order", value: "created_at.desc")]
        
        if let limit = limit { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let offset = offset { queryItems.append(URLQueryItem(name: "offset", value: String(offset))) }
        
        urlComponents.queryItems = queryItems
        guard let url = urlComponents.url else { throw SupabaseError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try handleHTTPResponse(response)
        
        do {
            let supabaseExpenses = try JSONDecoder().decode([SupabaseExpense].self, from: data)
            return supabaseExpenses.map { $0.toExpense() }
        } catch {
            print("Supabase decoding error: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw Supabase response: \(responseString)")
            }
            throw SupabaseError.decodingFailed
        }
    }
    
    func getTotalExpenses() async throws -> Double {
        guard let baseURL = baseURL, let url = URL(string: "\(baseURL)/expenses?select=amount") else {
            throw SupabaseError.missingCredentials
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try handleHTTPResponse(response)
        
        do {
            let expenses = try JSONDecoder().decode([SupabaseAmountOnly].self, from: data)
            return expenses.reduce(0) { $0 + $1.amount }
        } catch {
            print("Supabase getTotalExpenses decoding error: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw response: \(responseString)")
            }
            throw SupabaseError.decodingFailed
        }
    }
    
    func getMonthlyTotal() async throws -> Double {
        guard let baseURL = baseURL else { throw SupabaseError.missingCredentials }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
        
        let dateFormatter = ISO8601DateFormatter()
        let startDateString = dateFormatter.string(from: startOfMonth)
        let endDateString = dateFormatter.string(from: endOfMonth)
        
        guard let url = URL(string: "\(baseURL)/expenses?select=amount&date=gte.\(startDateString)&date=lt.\(endDateString)") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try handleHTTPResponse(response)
        
        do {
            let expenses = try JSONDecoder().decode([SupabaseAmountOnly].self, from: data)
            return expenses.reduce(0) { $0 + $1.amount }
        } catch {
            print("Supabase getMonthlyTotal decoding error: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw response: \(responseString)")
            }
            throw SupabaseError.decodingFailed
        }
    }
    
    private func handleHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299: return
        case 401: throw SupabaseError.unauthorized
        case 404: throw SupabaseError.notFound
        case 400...499: throw SupabaseError.clientError(httpResponse.statusCode)
        case 500...599: throw SupabaseError.serverError(httpResponse.statusCode)
        default: throw SupabaseError.unknownError(httpResponse.statusCode)
        }
    }
}

enum SupabaseError: LocalizedError {
    case missingCredentials, invalidURL, encodingFailed, decodingFailed, invalidResponse
    case unauthorized, notFound, clientError(Int), serverError(Int), unknownError(Int), noDataReturned
    
    var errorDescription: String? {
        switch self {
        case .missingCredentials: return "Supabase credentials not found"
        case .invalidURL: return "Invalid Supabase URL"
        case .encodingFailed: return "Failed to encode request data"
        case .decodingFailed: return "Failed to decode response data"
        case .invalidResponse: return "Invalid response from Supabase"
        case .unauthorized: return "Unauthorized access to Supabase"
        case .notFound: return "Resource not found"
        case .clientError(let code): return "Client error (Status: \(code))"
        case .serverError(let code): return "Server error (Status: \(code))"
        case .unknownError(let code): return "Unknown error (Status: \(code))"
        case .noDataReturned: return "No data returned from Supabase"
        }
    }
}

@MainActor
class ExpenseService: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var processedPhotos: [ProcessedPhoto] = []
    @Published var showProcessingCompletionDialog = false
    @Published var processedPhotoCount = 0
    
    private let supabaseService = SupabaseService.shared
    private let openAIService = OpenAIService.shared
    
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
                    
                    let createdExpense = try await supabaseService.createExpense(expense)
                    
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
                } else if let supabaseError = error as? SupabaseError {
                    switch supabaseError {
                    case .unauthorized:
                        errorMessage = "Supabase access denied. Check your API key."
                    case .missingCredentials:
                        errorMessage = "Supabase credentials missing. Please configure in settings."
                    default:
                        errorMessage = "Database error: \(supabaseError.localizedDescription)"
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
        
        do {
            let fetchedExpenses = try await supabaseService.fetchExpenses(limit: limit)
            expenses = fetchedExpenses
            isLoading = false
            return fetchedExpenses
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func getTotalExpenses() async throws -> Double {
        do {
            return try await supabaseService.getTotalExpenses()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func getMonthlyTotal() async throws -> Double {
        do {
            return try await supabaseService.getMonthlyTotal()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
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
}