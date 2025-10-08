import Foundation
import SwiftUI
import Combine
import UIKit
import PhotosUI
import CoreData
import PDFKit
import UniformTypeIdentifiers

class ExpenseService: ObservableObject {
    // Deprecated: Use CoreDataExpenseService.shared instead
    static let shared = ExpenseService()

    // Migration helper - use CoreDataExpenseService for new implementations
    static var coreDataService: CoreDataExpenseService {
        return CoreDataExpenseService.shared
    }

    private let openAIService = OpenAIService.shared
    private let userDefaults = UserDefaults.standard
    private let expensesKey = "SavedExpenses"
    private let lastBackupKey = "LastBackupDate"
    private let firstLaunchKey = "HasLaunchedBefore"

    @Published var expenses: [Expense] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private init() {
        // Load data from CoreDataExpenseService and keep in sync
        syncWithCoreDataService()
    }
    
    private func syncWithCoreDataService() {
        // Copy data from CoreDataExpenseService to maintain @Published functionality
        let coreDataService = CoreDataExpenseService.shared
        self.expenses = coreDataService.expenses
        self.isLoading = coreDataService.isLoading
        self.errorMessage = coreDataService.errorMessage
    }
    
    func processReceiptPhotos(_ photoItems: [PhotosPickerItem]) async -> Int {
        var processedCount = 0

        for photoItem in photoItems {
            do {
                // Debug PhotosPickerItem properties
                let assetIdentifier = photoItem.itemIdentifier
                print("Captured asset identifier during processing: \(assetIdentifier ?? "nil")")
                print("PhotosPickerItem supportedContentTypes: \(photoItem.supportedContentTypes)")

                // Check if this is a PDF or image
                let isPDF = photoItem.supportedContentTypes.contains(UTType.pdf)

                if isPDF {
                    // Process PDF
                    if let pdfData = try await loadData(from: photoItem),
                       let images = convertPDFToImages(from: pdfData) {

                        for image in images {
                            let extractedData = try await openAIService.extractExpenseFromReceipt(image)
                            let expense = try createExpenseFromExtraction(extractedData)

                            // Save expense locally
                            _ = try addExpense(expense)

                            processedCount += 1
                        }
                    }
                } else {
                    // Process image
                    if let imageData = try await loadData(from: photoItem),
                       let image = UIImage(data: imageData) {

                        let extractedData = try await openAIService.extractExpenseFromReceipt(image)
                        let expense = try createExpenseFromExtraction(extractedData)

                        // Save expense locally
                        _ = try addExpense(expense)

                        processedCount += 1
                    }
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

    func processDocuments(_ documentURLs: [URL]) async -> Int {
        // Bridge to CoreDataExpenseService
        return await CoreDataExpenseService.shared.processDocuments(documentURLs)
    }
    
    private func loadData(from photoItem: PhotosPickerItem) async throws -> Data? {
        return try await withCheckedThrowingContinuation { continuation in
            photoItem.loadTransferable(type: Data.self) { result in
                switch result {
                case .success(let data): continuation.resume(returning: data)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // PDF to Images conversion utility
    private func convertPDFToImages(from pdfData: Data) -> [UIImage]? {
        guard let pdfDocument = PDFDocument(data: pdfData) else {
            print("Failed to create PDF document from data")
            return nil
        }
        
        var images: [UIImage] = []
        let pageCount = pdfDocument.pageCount
        
        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else {
                print("Failed to get page \(pageIndex) from PDF")
                continue
            }
            
            let pageRect = page.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            
            let image = renderer.image { context in
                UIColor.white.set()
                context.fill(pageRect)
                
                context.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)
                
                page.draw(with: .mediaBox, to: context.cgContext)
            }
            
            images.append(image)
        }
        
        print("Converted PDF to \(images.count) images")
        return images.isEmpty ? nil : images
    }

    
    private func createExpenseFromExtraction(_ extraction: OpenAIExpenseExtraction) throws -> Expense {
        var expenseDate = parseDateFromExtraction(extraction.date)

        // Validate and fix date if it's incorrectly parsed as 2023 instead of current year
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let extractedYear = calendar.component(.year, from: expenseDate)

        // If the extracted date is from past years but we're in a later year, likely a parsing error
        if extractedYear < currentYear - 1 {
            print("Warning: Date parsed as \(extractedYear), correcting to \(currentYear). Original: \(extraction.date)")
            let components = calendar.dateComponents([.month, .day], from: expenseDate)
            var correctedComponents = DateComponents()
            correctedComponents.year = currentYear
            correctedComponents.month = components.month
            correctedComponents.day = components.day
            expenseDate = calendar.date(from: correctedComponents) ?? expenseDate
            print("Corrected date: \(expenseDate)")
        }

        // Validate currency is supported
        let validatedCurrency = CurrencyHelper.isSupported(extraction.currency) ? extraction.currency : "USD"
        if validatedCurrency != extraction.currency {
            print("Warning: Unsupported currency '\(extraction.currency)', defaulting to USD")
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
            currency: validatedCurrency,
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

    private func parseDateFromExtraction(_ dateString: String) -> Date {
        let dateFormatters = [
            // ISO 8601 formats
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd",

            // Indian formats
            "dd/MM/yyyy",
            "dd-MM-yyyy",
            "dd.MM.yyyy",
            "dd/MM/yy",
            "dd-MM-yy",
            "dd.MM.yy",

            // US formats
            "MM/dd/yyyy",
            "MM-dd-yyyy",
            "MM.dd.yyyy",
            "MM/dd/yy",
            "MM-dd-yy",
            "MM.dd.yy",

            // European formats
            "dd.MM.yyyy",
            "dd/MM/yyyy",
            "dd-MM-yyyy",
            "dd.MM.yy",
            "dd/MM/yy",
            "dd-MM-yy",

            // Alternative formats
            "yyyy/MM/dd",
            "yyyy.MM.dd",
            "dd MMM yyyy",
            "MMM dd, yyyy",
            "dd MMMM yyyy",
            "MMMM dd, yyyy"
        ]

        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())

        for format in dateFormatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")

            if let date = formatter.date(from: dateString) {
                // Handle 2-digit year interpretation
                let year = calendar.component(.year, from: date)
                if year < 100 {
                    // Convert 2-digit year to 4-digit year
                    let adjustedYear = year + 2000
                    if adjustedYear > currentYear + 10 {
                        // If the year is too far in the future, assume it's from the previous century
                        let components = calendar.dateComponents([.month, .day], from: date)
                        var newComponents = DateComponents()
                        newComponents.year = adjustedYear - 100
                        newComponents.month = components.month
                        newComponents.day = components.day
                        return calendar.date(from: newComponents) ?? date
                    } else {
                        let components = calendar.dateComponents([.month, .day], from: date)
                        var newComponents = DateComponents()
                        newComponents.year = adjustedYear
                        newComponents.month = components.month
                        newComponents.day = components.day
                        return calendar.date(from: newComponents) ?? date
                    }
                }
                return date
            }
        }

        print("Warning: Could not parse date '\(dateString)', using current date")
        return Date()
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
        try? saveExpensesToUserDefaults()
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
        
        try? saveExpensesToUserDefaults()
        print("Added \(sampleExpenses.count) sample expenses with item details for first launch")
    }
    
}
